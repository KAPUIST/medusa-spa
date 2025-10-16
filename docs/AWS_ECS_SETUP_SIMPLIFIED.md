# AWS ECS Fargate 간소화 배포 가이드

기존 RDS와 Upstash Redis를 사용하는 간소화된 배포 가이드입니다.

## 사전 준비 확인

### ✅ 준비된 리소스

- [ ] RDS PostgreSQL (엔드포인트 및 접속 정보)
- [ ] Upstash Redis (Redis URL)

### 📝 필요한 정보 수집

다음 정보를 미리 준비하세요:

```bash
# RDS 정보
RDS_ENDPOINT="your-rds.xxxxxx.ap-northeast-2.rds.amazonaws.com"
RDS_USERNAME="your_username"
RDS_PASSWORD="your_password"
RDS_DATABASE="medusa"

# Upstash Redis URL (형식: redis://default:password@endpoint:port)
UPSTASH_REDIS_URL="redis://default:xxxxx@your-endpoint.upstash.io:6379"

# AWS 정보
AWS_ACCOUNT_ID="123456789012"
AWS_REGION="ap-northeast-2"
```

---

## 1단계: ECR 리포지토리 생성

```bash
# ECR 리포지토리 생성
aws ecr create-repository \
  --repository-name medusa-server \
  --region ap-northeast-2 \
  --image-scanning-configuration scanOnPush=true

# ECR URI 확인 (나중에 사용)
aws ecr describe-repositories \
  --repository-names medusa-server \
  --query 'repositories[0].repositoryUri' \
  --output text

# 출력 예: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server
export ECR_URI="위에서 나온 URI"
```

---

## 2단계: VPC 및 Subnet 확인

기존 RDS가 있는 VPC를 사용합니다.

```bash
# RDS가 속한 VPC 확인
aws rds describe-db-instances \
  --db-instance-identifier your-db-instance-name \
  --query 'DBInstances[0].DBSubnetGroup.VpcId' \
  --output text

export VPC_ID="vpc-xxxxxxxxx"

# 해당 VPC의 Public Subnet 확인 (ALB용)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[?MapPublicIpOnLaunch==`true`].[SubnetId,AvailabilityZone]' \
  --output table

# 최소 2개의 다른 AZ에 있는 Public Subnet 필요
export PUBLIC_SUBNET_1="subnet-xxxxxxxx"
export PUBLIC_SUBNET_2="subnet-yyyyyyyy"

# Private Subnet 확인 (ECS Task용)
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[?MapPublicIpOnLaunch==`false`].[SubnetId,AvailabilityZone]' \
  --output table

export PRIVATE_SUBNET_1="subnet-aaaaaaaa"
export PRIVATE_SUBNET_2="subnet-bbbbbbbb"
```

**Public Subnet이 없는 경우**: ECS Task에 Public IP를 할당하여 Private Subnet에서도 실행 가능합니다.

---

## 3단계: Security Groups 생성

### 3-1. ALB Security Group (외부 트래픽 허용)

```bash
aws ec2 create-security-group \
  --group-name medusa-alb-sg \
  --description "Security group for Medusa ALB" \
  --vpc-id $VPC_ID

export ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=medusa-alb-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# HTTP 허용
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# HTTPS 허용 (SSL 인증서 설정 시)
aws ec2 authorize-security-group-ingress \
  --group-id $ALB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

### 3-2. ECS Task Security Group

```bash
aws ec2 create-security-group \
  --group-name medusa-ecs-sg \
  --description "Security group for Medusa ECS tasks" \
  --vpc-id $VPC_ID

export ECS_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=medusa-ecs-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# ALB에서 오는 트래픽만 허용 (Port 9000)
aws ec2 authorize-security-group-ingress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 9000 \
  --source-group $ALB_SG_ID

# 외부 인터넷 접근 허용 (Upstash Redis 연결용)
aws ec2 authorize-security-group-egress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-egress \
  --group-id $ECS_SG_ID \
  --protocol tcp \
  --port 6379 \
  --cidr 0.0.0.0/0
```

### 3-3. RDS Security Group 업데이트 (ECS에서 접근 허용)

```bash
# 기존 RDS Security Group ID 확인
export RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier your-db-instance-name \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# ECS Task에서 RDS 접근 허용
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 5432 \
  --source-group $ECS_SG_ID
```

---

## 4단계: IAM Roles 생성

### 4-1. ECS Task Execution Role

```bash
# Trust Policy 파일 생성
cat > /tmp/ecs-task-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Role 생성
aws iam create-role \
  --role-name medusa-ecs-task-execution-role \
  --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json

# Managed Policy 연결
aws iam attach-role-policy \
  --role-name medusa-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name medusa-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# Role ARN 확인
aws iam get-role \
  --role-name medusa-ecs-task-execution-role \
  --query 'Role.Arn' \
  --output text

export EXECUTION_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/medusa-ecs-task-execution-role"
```

### 4-2. ECS Task Role (선택사항 - S3 등 사용 시)

```bash
aws iam create-role \
  --role-name medusa-ecs-task-role \
  --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json

# S3 접근 권한 (미디어 파일 저장용)
aws iam attach-role-policy \
  --role-name medusa-ecs-task-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

export TASK_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/medusa-ecs-task-role"
```

---

## 5단계: Application Load Balancer 생성

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name medusa-alb \
  --subnets $PUBLIC_SUBNET_1 $PUBLIC_SUBNET_2 \
  --security-groups $ALB_SG_ID \
  --scheme internet-facing

export ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names medusa-alb \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# ALB DNS Name 확인
aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text

# Target Group 생성
aws elbv2 create-target-group \
  --name medusa-tg \
  --protocol HTTP \
  --port 9000 \
  --vpc-id $VPC_ID \
  --target-type ip \
  --health-check-enabled \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

export TG_ARN=$(aws elbv2 describe-target-groups \
  --names medusa-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Listener 생성
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

---

## 6단계: ECS Cluster 생성

```bash
aws ecs create-cluster \
  --cluster-name medusa-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1
```

---

## 7단계: CloudWatch Logs 생성

```bash
aws logs create-log-group --log-group-name /ecs/medusa
```

---

## 8단계: ECS Task Definition 생성

**환경변수를 포함한 Task Definition JSON 생성**:

```bash
cat > /tmp/medusa-task-definition.json <<EOF
{
  "family": "medusa-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "taskRoleArn": "${TASK_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "medusa-server",
      "image": "${ECR_URI}:latest",
      "portMappings": [
        {
          "containerPort": 9000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "production"},
        {"name": "DATABASE_URL", "value": "postgres://${RDS_USERNAME}:${RDS_PASSWORD}@${RDS_ENDPOINT}:5432/${RDS_DATABASE}"},
        {"name": "POSTGRES_URL", "value": "postgres://${RDS_USERNAME}:${RDS_PASSWORD}@${RDS_ENDPOINT}:5432/${RDS_DATABASE}"},
        {"name": "REDIS_URL", "value": "${UPSTASH_REDIS_URL}"},
        {"name": "MEDUSA_ADMIN_ONBOARDING_TYPE", "value": "default"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/medusa",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "node -e \"require('http').get('http://localhost:9000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})\""],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

# Task Definition 등록
aws ecs register-task-definition --cli-input-json file:///tmp/medusa-task-definition.json
```

**⚠️ 보안 강화**: 민감한 환경변수는 AWS Secrets Manager나 SSM Parameter Store 사용을 권장합니다.

---

## 9단계: 초기 Docker 이미지 ECR에 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# 프로젝트 루트에서 이미지 빌드
cd /Users/taegwonson/Desktop/spa-medusa-monorepo
docker build -t medusa-server -f apps/server/Dockerfile .

# 이미지 태그
docker tag medusa-server:latest ${ECR_URI}:latest

# ECR에 푸시
docker push ${ECR_URI}:latest
```

---

## 10단계: ECS Service 생성

```bash
aws ecs create-service \
  --cluster medusa-cluster \
  --service-name medusa-service \
  --task-definition medusa-task \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1,$PRIVATE_SUBNET_2],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=$TG_ARN,containerName=medusa-server,containerPort=9000" \
  --health-check-grace-period-seconds 60
```

**참고**: `assignPublicIp=ENABLED`는 NAT Gateway 없이 외부(Upstash) 접근을 위해 필요합니다.

---

## 11단계: GitHub Secrets 설정

GitHub 리포지토리에 다음 Secrets 추가:

```
Settings > Secrets and variables > Actions > New repository secret
```

**필수 Secrets**:

```
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION: ap-northeast-2
```

**환경변수 Secrets (선택 - Task Definition에 포함하지 않은 경우)**:

```
RDS_ENDPOINT
RDS_USERNAME
RDS_PASSWORD
UPSTASH_REDIS_URL
```

---

## 12단계: 배포 확인

### ECS Service 상태 확인

```bash
aws ecs describe-services \
  --cluster medusa-cluster \
  --services medusa-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table
```

### Task 로그 확인

```bash
aws logs tail /ecs/medusa --follow
```

### ALB 헬스체크

```bash
# ALB DNS Name 가져오기
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names medusa-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# 헬스체크
curl http://${ALB_DNS}/health
```

---

## 13단계: GitHub Actions로 자동 배포 테스트

```bash
# 브랜치 생성 및 푸시
git checkout -b test/ecs-deployment
git add .
git commit -m "feat(deploy): add ECS deployment configuration"
git push origin test/ecs-deployment

# main에 머지
git checkout main
git merge test/ecs-deployment
git push origin main
```

GitHub Actions 워크플로우가 자동으로 실행되면서:

1. Docker 이미지 빌드
2. ECR에 푸시
3. ECS Task Definition 업데이트
4. ECS Service 재배포

---

## 트러블슈팅

### 1. Task가 시작되지 않는 경우

```bash
# Task 상태 확인
aws ecs list-tasks --cluster medusa-cluster --service-name medusa-service

# Task 세부 정보
aws ecs describe-tasks \
  --cluster medusa-cluster \
  --tasks <TASK_ARN> \
  --query 'tasks[0].{Status:lastStatus,Reason:stoppedReason,Containers:containers[0].{Name:name,Status:lastStatus,Reason:reason}}'
```

### 2. RDS 연결 실패

```bash
# Security Group 확인
aws ec2 describe-security-groups --group-ids $RDS_SG_ID

# ECS Task에서 직접 확인 (ECS Exec 활성화 필요)
aws ecs execute-command \
  --cluster medusa-cluster \
  --task <TASK_ID> \
  --container medusa-server \
  --interactive \
  --command "/bin/sh"
```

### 3. Upstash Redis 연결 실패

- Upstash Dashboard에서 Redis URL 확인
- URL 형식: `redis://default:password@endpoint:port`
- TLS 사용 시: `rediss://` 프로토콜 사용

---

## 예상 비용 (월간)

| 리소스                    | 사양      | 예상 비용   |
| ------------------------- | --------- | ----------- |
| Fargate (0.5 vCPU, 1GB)   | 24/7 운영 | ~$15        |
| Application Load Balancer | 표준      | ~$20        |
| Data Transfer             | 10GB/월   | ~$1         |
| CloudWatch Logs           | 5GB/월    | ~$3         |
| **총계**                  |           | **~$39/월** |

- RDS, Upstash는 기존 비용에 포함되지 않음
- 프리티어 적용 시 비용 절감 가능

---

## 다음 단계

- [ ] Route53으로 커스텀 도메인 연결
- [ ] ACM으로 SSL 인증서 발급 및 HTTPS 설정
- [ ] Auto Scaling 정책 추가
- [ ] CloudWatch Alarms 설정 (CPU, Memory, 에러율)
- [ ] AWS Secrets Manager로 민감 정보 관리
- [ ] CI/CD 파이프라인 최적화 (캐싱, 병렬 빌드)

---

## 빠른 시작 스크립트

전체 설정을 한 번에 실행하려면 다음 스크립트를 사용하세요:

```bash
# 파일 생성: scripts/setup-ecs.sh
chmod +x scripts/setup-ecs.sh
./scripts/setup-ecs.sh
```

스크립트 내용은 별도 파일로 제공됩니다.
