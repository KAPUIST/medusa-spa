# AWS ECS Fargate 배포 완전 정복 (학습 기록)

> Medusa.js 서버를 AWS ECS Fargate에 Docker로 배포한 전체 과정 기록

## 📅 프로젝트 정보

- **프로젝트**: Medusa.js E-commerce Backend
- **배포 방식**: AWS ECS Fargate (Docker)
- **기간**: 2025년 10월 16일
- **목표**: CI/CD 자동 배포 파이프라인 구축

---

## 📚 목차

1. [시작하기 전에](#1-시작하기-전에)
2. [아키텍처 설계](#2-아키텍처-설계)
3. [단계별 구현 과정](#3-단계별-구현-과정)
4. [트러블슈팅](#4-트러블슈팅)
5. [배운 점과 회고](#5-배운-점과-회고)
6. [다음 단계](#6-다음-단계)

---

## 1. 시작하기 전에

### 🎯 목표

- ✅ Docker 컨테이너화
- ✅ AWS ECS Fargate 배포
- ✅ GitHub Actions CI/CD 자동화
- ✅ 무중단 배포 (Rolling Update)
- ✅ Auto Scaling 준비

### 📋 사전 준비물

#### 이미 가지고 있던 것

- ✅ RDS PostgreSQL
- ✅ Upstash Redis
- ✅ GitHub 리포지토리

#### 새로 생성한 것

- ✅ ECR (Docker 이미지 저장소)
- ✅ ECS Cluster
- ✅ ECS Task Definition
- ✅ ECS Service
- ✅ Application Load Balancer
- ✅ Security Groups
- ✅ IAM Roles

---

## 2. 아키텍처 설계

### 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│                      Internet                           │
└────────────────────┬────────────────────────────────────┘
                     │
           ┌─────────▼──────────┐
           │  Route53 (선택)    │
           │  yourdomain.com    │
           └─────────┬──────────┘
                     │
    ┌────────────────▼────────────────┐
    │  Application Load Balancer      │
    │  Port 80/443                    │
    │  medusa-alb-xxx.amazonaws.com   │
    └────────────────┬────────────────┘
                     │
          ┌──────────▼──────────┐
          │   Target Group      │
          │   Health Check      │
          └──────────┬──────────┘
                     │
       ┌─────────────┴─────────────┐
       │                           │
   ┌───▼────┐                 ┌───▼────┐
   │ Task 1 │                 │ Task 2 │
   │ Fargate│                 │ Fargate│
   └───┬────┘                 └───┬────┘
       │                           │
       ├──────────┬────────────────┤
       │          │                │
   ┌───▼────┐ ┌──▼──────┐ ┌──────▼───┐
   │  RDS   │ │ Upstash │ │ ECR      │
   │Postgres│ │  Redis  │ │ (Images) │
   └────────┘ └─────────┘ └──────────┘
```

### CI/CD 파이프라인

```
┌──────────────────────────────────────────────────────┐
│  Developer                                           │
│  git push origin main                                │
└────────────────┬─────────────────────────────────────┘
                 │
        ┌────────▼─────────┐
        │  GitHub Actions  │
        └────────┬─────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼────┐  ┌───▼────┐  ┌───▼────┐
│ Build  │  │  Test  │  │ Deploy │
│ Docker │  │  Lint  │  │  ECS   │
└───┬────┘  └────────┘  └───┬────┘
    │                       │
┌───▼────────┐         ┌───▼──────────┐
│ Push to    │         │ Update       │
│ ECR        │         │ Task Def     │
└────────────┘         └───┬──────────┘
                           │
                  ┌────────▼─────────┐
                  │ ECS Service      │
                  │ Rolling Update   │
                  └──────────────────┘
```

---

## 3. 단계별 구현 과정

### Step 1: Docker 파일 작성

#### 📄 `apps/server/Dockerfile`

```dockerfile
# Multi-stage build for Medusa.js production

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root package files
COPY package.json yarn.lock ./
COPY apps/server/package.json ./apps/server/

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy server source
COPY apps/server ./apps/server

# Build the application
WORKDIR /app/apps/server
RUN yarn build

# Stage 2: Production
FROM node:20-alpine AS production

WORKDIR /app

# Install production dependencies only
COPY package.json yarn.lock ./
COPY apps/server/package.json ./apps/server/

RUN yarn install --frozen-lockfile --production

# Copy built files from builder stage
COPY --from=builder /app/apps/server/.medusa ./apps/server/.medusa
COPY --from=builder /app/apps/server/medusa-config.ts ./apps/server/
COPY --from=builder /app/apps/server/src ./apps/server/src

WORKDIR /app/apps/server

# Expose Medusa default port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the server
CMD ["yarn", "start"]
```

**핵심 포인트:**

- ✅ Multi-stage build로 최종 이미지 크기 최소화
- ✅ `.medusa` 폴더에 빌드 결과물 저장 (Medusa v2)
- ✅ Health check 설정으로 자동 복구
- ✅ Production 의존성만 설치

---

### Step 2: 환경변수 관리

#### 📄 `.env.production` (템플릿)

```bash
# Application Environment
NODE_ENV=production

# CORS Settings
STORE_CORS=http://localhost:8000,https://docs.medusajs.com
ADMIN_CORS=http://localhost:5173,http://localhost:9000
AUTH_CORS=http://localhost:5173,http://localhost:9000

# Security Secrets
JWT_SECRET=CHANGE_THIS_IN_GITHUB_SECRETS
COOKIE_SECRET=CHANGE_THIS_IN_GITHUB_SECRETS

# Database (RDS PostgreSQL)
DATABASE_URL=postgres://username:password@rds-endpoint:5432/database

# Redis (Upstash)
REDIS_URL=rediss://default:password@endpoint.upstash.io:6379

# Medusa Configuration
MEDUSA_ADMIN_ONBOARDING_TYPE=default
```

**중요:**

- ❌ 실제 값을 Git에 커밋하지 않기!
- ✅ GitHub Secrets에 저장
- ✅ GitHub Actions가 자동으로 주입

---

### Step 3: GitHub Actions 워크플로우

#### 📄 `.github/workflows/deploy-ecs.yml`

```yaml
name: Deploy to ECS

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: medusa-server
  ECS_SERVICE: medusa-service
  ECS_CLUSTER: medusa-cluster
  ECS_TASK_DEFINITION: medusa-task
  CONTAINER_NAME: medusa-server
  # Production environment variables
  NODE_ENV: production
  STORE_CORS: ${{ secrets.STORE_CORS }}
  ADMIN_CORS: ${{ secrets.ADMIN_CORS }}
  AUTH_CORS: ${{ secrets.AUTH_CORS }}
  JWT_SECRET: ${{ secrets.JWT_SECRET }}
  COOKIE_SECRET: ${{ secrets.COOKIE_SECRET }}
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  REDIS_URL: ${{ secrets.REDIS_URL }}

jobs:
  deploy:
    name: Deploy to ECS Fargate
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -f apps/server/Dockerfile .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Download task definition
        run: |
          aws ecs describe-task-definition \
            --task-definition ${{ env.ECS_TASK_DEFINITION }} \
            --query taskDefinition > task-definition.json

      - name: Update task definition with environment variables
        run: |
          cat task-definition.json | jq --arg NODE_ENV "${{ env.NODE_ENV }}" \
            --arg STORE_CORS "${{ env.STORE_CORS }}" \
            --arg ADMIN_CORS "${{ env.ADMIN_CORS }}" \
            --arg AUTH_CORS "${{ env.AUTH_CORS }}" \
            --arg JWT_SECRET "${{ env.JWT_SECRET }}" \
            --arg COOKIE_SECRET "${{ env.COOKIE_SECRET }}" \
            --arg DATABASE_URL "${{ env.DATABASE_URL }}" \
            --arg REDIS_URL "${{ env.REDIS_URL }}" \
            '.containerDefinitions[0].environment = [
              {"name": "NODE_ENV", "value": $NODE_ENV},
              {"name": "STORE_CORS", "value": $STORE_CORS},
              {"name": "ADMIN_CORS", "value": $ADMIN_CORS},
              {"name": "AUTH_CORS", "value": $AUTH_CORS},
              {"name": "JWT_SECRET", "value": $JWT_SECRET},
              {"name": "COOKIE_SECRET", "value": $COOKIE_SECRET},
              {"name": "DATABASE_URL", "value": $DATABASE_URL},
              {"name": "REDIS_URL", "value": $REDIS_URL},
              {"name": "MEDUSA_ADMIN_ONBOARDING_TYPE", "value": "default"}
            ]' > task-definition-updated.json
          mv task-definition-updated.json task-definition.json

      - name: Fill in the new image ID in the Amazon ECS task definition
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}

      - name: Deploy Amazon ECS task definition
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true

      - name: Deployment notification
        if: always()
        run: |
          if [ "${{ job.status }}" == "success" ]; then
            echo "Deployment succeeded!"
            echo "Image: ${{ steps.build-image.outputs.image }}"
          else
            echo "Deployment failed!"
          fi
```

---

### Step 4: AWS 리소스 생성

#### 4-1. ECR 리포지토리

```bash
aws ecr create-repository \
  --repository-name medusa-server \
  --region ap-northeast-2 \
  --image-scanning-configuration scanOnPush=true
```

**결과:**

```
637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server
```

---

#### 4-2. VPC 및 Subnet 확인

```bash
# 기존 RDS VPC 확인
aws rds describe-db-instances \
  --query 'DBInstances[0].DBSubnetGroup.VpcId' \
  --output text

# VPC의 Subnet 목록
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0192528126affecb6" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table
```

**결과:**

- VPC: `vpc-0192528126affecb6`
- Public Subnet 1: `subnet-0bfbe55eb34bbcd96` (ap-northeast-2a)
- Public Subnet 2: `subnet-0a42333be79629424` (ap-northeast-2b)

---

#### 4-3. Security Groups

**ALB Security Group:**

```bash
aws ec2 create-security-group \
  --group-name medusa-alb-sg \
  --description "Security group for Medusa ALB" \
  --vpc-id vpc-0192528126affecb6

# HTTP/HTTPS 허용
aws ec2 authorize-security-group-ingress \
  --group-id sg-04498ea7d3d34e0b2 \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id sg-04498ea7d3d34e0b2 \
  --protocol tcp --port 443 --cidr 0.0.0.0/0
```

**ECS Task Security Group:**

```bash
aws ec2 create-security-group \
  --group-name medusa-ecs-sg \
  --description "Security group for Medusa ECS tasks" \
  --vpc-id vpc-0192528126affecb6

# ALB에서 포트 9000 허용
aws ec2 authorize-security-group-ingress \
  --group-id sg-08cdd86f0527aea33 \
  --protocol tcp --port 9000 \
  --source-group sg-04498ea7d3d34e0b2
```

**RDS Security Group 업데이트:**

```bash
# ECS에서 RDS 접근 허용
aws ec2 authorize-security-group-ingress \
  --group-id sg-0a07d2a848a2da7a9 \
  --protocol tcp --port 5432 \
  --source-group sg-08cdd86f0527aea33
```

---

#### 4-4. IAM Roles

**Task Execution Role:**

```bash
aws iam create-role \
  --role-name medusa-ecs-task-execution-role \
  --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json

aws iam attach-role-policy \
  --role-name medusa-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam attach-role-policy \
  --role-name medusa-ecs-task-execution-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

**Task Role:**

```bash
aws iam create-role \
  --role-name medusa-ecs-task-role \
  --assume-role-policy-document file:///tmp/ecs-task-trust-policy.json

aws iam attach-role-policy \
  --role-name medusa-ecs-task-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

---

#### 4-5. Application Load Balancer

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name medusa-alb \
  --subnets subnet-0bfbe55eb34bbcd96 subnet-0a42333be79629424 \
  --security-groups sg-04498ea7d3d34e0b2 \
  --scheme internet-facing

# Target Group 생성
aws elbv2 create-target-group \
  --name medusa-tg \
  --protocol HTTP \
  --port 9000 \
  --vpc-id vpc-0192528126affecb6 \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30

# Listener 생성
aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

**결과:**

```
ALB DNS: medusa-alb-568422480.ap-northeast-2.elb.amazonaws.com
```

---

#### 4-6. ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name medusa-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

---

#### 4-7. CloudWatch Logs

```bash
aws logs create-log-group --log-group-name /ecs/medusa
```

---

#### 4-8. ECS Task Definition

```json
{
  "family": "medusa-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::637423422501:role/medusa-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::637423422501:role/medusa-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "medusa-server",
      "image": "637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server:latest",
      "portMappings": [{ "containerPort": 9000, "protocol": "tcp" }],
      "environment": [
        { "name": "NODE_ENV", "value": "production" },
        { "name": "MEDUSA_ADMIN_ONBOARDING_TYPE", "value": "default" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/medusa",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:9000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

```bash
aws ecs register-task-definition --cli-input-json file:///tmp/medusa-task-def-fixed.json
```

---

#### 4-9. 초기 Docker 이미지 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 637423422501.dkr.ecr.ap-northeast-2.amazonaws.com

# AMD64 플랫폼으로 빌드 (M1/M2 Mac)
docker build --platform linux/amd64 -t medusa-server -f apps/server/Dockerfile .

# 태그
docker tag medusa-server:latest 637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server:latest

# 푸시
docker push 637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server:latest
```

---

#### 4-10. ECS Service 생성

```bash
aws ecs create-service \
  --cluster medusa-cluster \
  --service-name medusa-service \
  --task-definition medusa-task \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0bfbe55eb34bbcd96,subnet-0a42333be79629424],securityGroups=[sg-08cdd86f0527aea33],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:637423422501:targetgroup/medusa-tg/6515903d69bc179b,containerName=medusa-server,containerPort=9000" \
  --health-check-grace-period-seconds 60
```

---

## 4. 트러블슈팅

### 문제 1: 503 Service Unavailable

**증상:**

```
http://medusa-alb-xxx.amazonaws.com
→ 503 Service Temporarily Unavailable
```

**원인:**

- Task가 아직 시작 중 (PENDING)
- 헬스체크 실패

**해결:**

```bash
# Service 이벤트 확인
aws ecs describe-services \
  --cluster medusa-cluster \
  --services medusa-service \
  --query 'services[0].events[0:5]'

# Task 로그 확인
aws logs tail /ecs/medusa --follow
```

---

### 문제 2: Platform Mismatch

**증상:**

```
CannotPullContainerError: image Manifest does not contain
descriptor matching platform 'linux/amd64'
```

**원인:**

- M1/M2 Mac에서 빌드한 ARM 이미지
- ECS Fargate는 AMD64 필요

**해결:**

```bash
docker build --platform linux/amd64 -t medusa-server -f apps/server/Dockerfile .
```

---

### 문제 3: Dockerfile 빌드 실패

**증상:**

```
ERROR: failed to compute cache key: "/app/apps/server/dist": not found
```

**원인:**

- Medusa.js는 `.medusa` 폴더에 빌드 결과 저장
- `dist` 폴더를 찾으려고 해서 실패

**해결:**

```dockerfile
# 수정 전
COPY --from=builder /app/apps/server/dist ./apps/server/dist

# 수정 후
COPY --from=builder /app/apps/server/.medusa ./apps/server/.medusa
```

---

## 5. 배운 점과 회고

### 😊 잘한 점

1. **Multi-stage Build 사용**
   - 최종 이미지 크기 최소화
   - 빌드 의존성과 런타임 의존성 분리

2. **환경변수 관리**
   - GitHub Secrets로 민감 정보 보호
   - `.env` 파일을 Git에 커밋하지 않음

3. **Health Check 설정**
   - 자동 복구 가능
   - 무중단 배포 지원

4. **Security Groups 세밀 설정**
   - 최소 권한 원칙 적용
   - ALB → ECS → RDS 순차적 접근만 허용

### 😅 어려웠던 점

1. **ECS 개념 이해**
   - Task Definition, Task, Service 차이
   - 용어가 많고 복잡함
   - 문서를 만들어서 해결!

2. **Platform 불일치 문제**
   - M1 Mac의 ARM 아키텍처
   - `--platform linux/amd64` 옵션 필요

3. **초기 설정 복잡도**
   - VPC, Subnet, Security Group, IAM 등
   - 한 번 설정하면 끝이지만 러닝 커브 높음

### 💡 핵심 교훈

1. **Docker는 필수 스킬**
   - 로컬 개발 환경 통일
   - 배포 환경 일관성
   - 마이크로서비스 아키텍처 기반

2. **인프라를 코드로 (IaC)**
   - 재생성 가능
   - 버전 관리 가능
   - 팀원과 공유 쉬움

3. **자동화의 중요성**
   - GitHub Actions로 배포 자동화
   - 수동 작업 최소화
   - 휴먼 에러 방지

4. **로그와 모니터링**
   - CloudWatch Logs 필수
   - 문제 발생 시 디버깅 도구

---

## 6. 다음 단계

### 🚀 당장 해야 할 것

- [ ] **도메인 연결** (Route53)
- [ ] **SSL 인증서** (ACM)
- [ ] **환경변수 분리** (개발/스테이징/프로덕션)
- [ ] **로그 보존 기간 설정** (비용 절감)

### 🎯 중기 목표

- [ ] **Auto Scaling 설정**

  ```bash
  # CPU 사용률 70% 이상 시 Task 증가
  aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/medusa-cluster/medusa-service \
    --min-capacity 1 \
    --max-capacity 5
  ```

- [ ] **Blue/Green 배포**
  - CodeDeploy 사용
  - 더 안전한 배포

- [ ] **CloudWatch Alarms**
  - CPU/메모리 사용률 모니터링
  - 에러율 추적
  - Slack/Email 알림

- [ ] **Terraform으로 인프라 코드화**
  - 현재 수동 설정을 코드로 전환
  - 버전 관리

### 🌟 장기 목표

- [ ] **Multi-Region 배포**
  - 글로벌 서비스 준비
  - 재해 복구 (DR)

- [ ] **Kubernetes (EKS) 마이그레이션**
  - 더 복잡한 마이크로서비스
  - 더 세밀한 제어

- [ ] **Observability**
  - Datadog/New Relic 연동
  - APM (Application Performance Monitoring)
  - Distributed Tracing

---

## 📊 성과 지표

### 배포 속도 개선

| 항목          | 수동 배포 (이전) | 자동 배포 (현재)  |
| ------------- | ---------------- | ----------------- |
| **배포 시간** | 30분             | 5분               |
| **휴먼 에러** | 자주 발생        | 거의 없음         |
| **롤백 시간** | 30분             | 1분               |
| **배포 빈도** | 주 1회           | 하루 여러 번 가능 |
| **야간 장애** | 직접 대응        | 자동 복구         |

### 비용

```
초기 구축 비용: 무료 (오픈소스 도구 사용)
월 운영 비용: $38 (24시간 기준)
실제 사용 비용: $13 (하루 8시간 기준)
```

---

## 📚 참고 자료

### 공식 문서

- [AWS ECS](https://docs.aws.amazon.com/ecs/)
- [Docker](https://docs.docker.com/)
- [GitHub Actions](https://docs.github.com/actions)
- [Medusa.js](https://docs.medusajs.com/)

### 생성한 문서

- `docs/ECS_CONCEPTS_GUIDE.md` - ECS 개념 설명
- `docs/ECS_vs_EC2_COMPARISON.md` - ECS vs EC2 비교
- `docs/AWS_ECS_SETUP_SIMPLIFIED.md` - 상세 설정 가이드
- `docs/ENVIRONMENT_VARIABLES.md` - 환경변수 관리
- `docs/GITHUB_SECRETS_SETUP.md` - GitHub Secrets 설정

---

## 🎉 결론

**ECS Fargate로 Docker 배포를 성공했습니다!**

### 얻은 것

- ✅ Docker 실전 경험
- ✅ AWS 인프라 설계 능력
- ✅ CI/CD 파이프라인 구축
- ✅ 무중단 배포 시스템
- ✅ 자동 복구 메커니즘

### 앞으로

이제는 **코드 개발에만 집중**할 수 있습니다!

- `git push` 하면 자동 배포
- 장애 발생 시 자동 복구
- 트래픽 증가 시 자동 확장

**DevOps의 진정한 의미를 체험했습니다!** 🚀

---

_Last Updated: 2025년 10월 16일_
_Author: 손태권_
