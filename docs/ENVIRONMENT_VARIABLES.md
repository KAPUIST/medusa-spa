# 환경변수 설정 가이드

## 필수 환경변수

Medusa 서버 실행에 필요한 환경변수 목록입니다.

### 데이터베이스 (RDS PostgreSQL)

```bash
DATABASE_URL="postgres://username:password@endpoint:5432/database"
POSTGRES_URL="postgres://username:password@endpoint:5432/database"
```

**예시**:

```bash
DATABASE_URL="postgres://medusaadmin:mypassword@medusa-db.c123abc.ap-northeast-2.rds.amazonaws.com:5432/medusa"
POSTGRES_URL="postgres://medusaadmin:mypassword@medusa-db.c123abc.ap-northeast-2.rds.amazonaws.com:5432/medusa"
```

### Redis (Upstash)

```bash
REDIS_URL="redis://default:password@endpoint:port"
```

**Upstash Redis URL 확인 방법**:

1. Upstash Dashboard 접속
2. Redis 데이터베이스 선택
3. "Connect" 탭에서 URL 복사
4. TLS 사용 시 `rediss://` 프로토콜 사용

**예시**:

```bash
# TLS 사용 (권장)
REDIS_URL="rediss://default:AbC123XyZ@gusc1-fun-12345.upstash.io:6379"

# TLS 미사용
REDIS_URL="redis://default:AbC123XyZ@gusc1-fun-12345.upstash.io:6379"
```

### Medusa 기본 설정

```bash
NODE_ENV="production"
MEDUSA_ADMIN_ONBOARDING_TYPE="default"
```

### CORS 설정

```bash
# 프론트엔드 도메인 (쉼표로 구분)
STORE_CORS="https://yourdomain.com,https://www.yourdomain.com"

# 관리자 패널 도메인
ADMIN_CORS="https://admin.yourdomain.com"
```

**개발 환경 예시**:

```bash
STORE_CORS="http://localhost:3000,http://localhost:8000"
ADMIN_CORS="http://localhost:3000,http://localhost:7001"
```

---

## 선택적 환경변수

### S3 스토리지 (이미지/파일 업로드)

```bash
AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
AWS_REGION="ap-northeast-2"
S3_BUCKET="medusa-uploads"
S3_URL="https://medusa-uploads.s3.ap-northeast-2.amazonaws.com"
```

### 이메일 (SES, SendGrid 등)

```bash
# AWS SES
SES_FROM="noreply@yourdomain.com"
SES_REGION="ap-northeast-2"

# SendGrid
SENDGRID_API_KEY="SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
SENDGRID_FROM="noreply@yourdomain.com"
```

### 결제 게이트웨이 (Stripe)

```bash
STRIPE_API_KEY="sk_test_xxxxxxxxxxxxxxxxxxxx"
STRIPE_WEBHOOK_SECRET="whsec_xxxxxxxxxxxxxxxxxxxx"
```

---

## 환경변수 관리 방법

### 1. 로컬 개발 (.env 파일)

```bash
# apps/server/.env
NODE_ENV=development
DATABASE_URL=postgres://postgres:postgres@localhost:5432/medusa
REDIS_URL=redis://localhost:6379
STORE_CORS=http://localhost:3000
ADMIN_CORS=http://localhost:7001
```

### 2. Docker Compose

`docker-compose.yml`의 `environment` 섹션에 추가:

```yaml
services:
  medusa:
    environment:
      NODE_ENV: production
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
```

`.env` 파일 생성:

```bash
DATABASE_URL=postgres://...
REDIS_URL=redis://...
```

### 3. ECS Task Definition (프로덕션)

#### 옵션 A: Task Definition JSON에 직접 포함

```json
{
  "containerDefinitions": [
    {
      "environment": [
        { "name": "NODE_ENV", "value": "production" },
        { "name": "DATABASE_URL", "value": "postgres://..." },
        { "name": "REDIS_URL", "value": "redis://..." }
      ]
    }
  ]
}
```

**⚠️ 주의**: 민감 정보가 노출될 수 있음

#### 옵션 B: AWS Secrets Manager 사용 (권장)

1. **Secrets Manager에 시크릿 생성**:

```bash
aws secretsmanager create-secret \
  --name medusa/production/database \
  --secret-string '{"username":"medusaadmin","password":"mypassword","host":"medusa-db.xxx.rds.amazonaws.com","port":"5432","database":"medusa"}'

aws secretsmanager create-secret \
  --name medusa/production/redis \
  --secret-string '{"url":"redis://default:xxx@xxx.upstash.io:6379"}'
```

2. **Task Definition에서 참조**:

```json
{
  "containerDefinitions": [
    {
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:medusa/production/database:url::"
        },
        {
          "name": "REDIS_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:medusa/production/redis:url::"
        }
      ]
    }
  ]
}
```

3. **IAM Role에 권한 추가**:

```bash
cat > /tmp/secrets-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-northeast-2:*:secret:medusa/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name medusa-ecs-task-execution-role \
  --policy-name SecretsManagerAccess \
  --policy-document file:///tmp/secrets-policy.json
```

#### 옵션 C: SSM Parameter Store 사용

1. **Parameter Store에 저장**:

```bash
aws ssm put-parameter \
  --name /medusa/production/database-url \
  --value "postgres://..." \
  --type SecureString

aws ssm put-parameter \
  --name /medusa/production/redis-url \
  --value "redis://..." \
  --type SecureString
```

2. **Task Definition에서 참조**:

```json
{
  "containerDefinitions": [
    {
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:ssm:ap-northeast-2:account:parameter/medusa/production/database-url"
        },
        {
          "name": "REDIS_URL",
          "valueFrom": "arn:aws:ssm:ap-northeast-2:account:parameter/medusa/production/redis-url"
        }
      ]
    }
  ]
}
```

### 4. GitHub Actions Secrets

GitHub Actions에서 사용할 Secrets:

```
Settings > Secrets and variables > Actions

필수:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION

선택 (Secrets Manager 미사용 시):
- DATABASE_URL
- REDIS_URL
```

---

## 환경변수 검증

### 로컬에서 확인

```bash
cd apps/server

# .env 파일 로드 테스트
node -e "require('dotenv').config(); console.log('DATABASE_URL:', process.env.DATABASE_URL ? '✓ Set' : '✗ Not set')"
```

### Docker 컨테이너에서 확인

```bash
docker-compose up -d medusa
docker-compose exec medusa env | grep -E "(DATABASE|REDIS|NODE_ENV)"
```

### ECS Task에서 확인

```bash
# Task ID 확인
aws ecs list-tasks --cluster medusa-cluster --service-name medusa-service

# Task 로그 확인
aws logs tail /ecs/medusa --follow --filter-pattern "DATABASE_URL"
```

---

## 보안 체크리스트

- [ ] `.env` 파일을 `.gitignore`에 추가
- [ ] GitHub Secrets에 민감 정보 저장
- [ ] 프로덕션에서는 Secrets Manager 또는 Parameter Store 사용
- [ ] RDS 비밀번호 정기적으로 변경
- [ ] Upstash Redis에 강력한 비밀번호 설정
- [ ] IAM Role 최소 권한 원칙 적용
- [ ] CORS 설정에 프로덕션 도메인만 포함

---

## 예시: 완전한 환경변수 템플릿

### 로컬 개발용 (.env.example)

```bash
# Node Environment
NODE_ENV=development

# Database
DATABASE_URL=postgres://postgres:postgres@localhost:5432/medusa
POSTGRES_URL=postgres://postgres:postgres@localhost:5432/medusa

# Redis
REDIS_URL=redis://localhost:6379

# CORS
STORE_CORS=http://localhost:3000,http://localhost:8000
ADMIN_CORS=http://localhost:3000,http://localhost:7001

# Medusa
MEDUSA_ADMIN_ONBOARDING_TYPE=default

# Optional: S3
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_REGION=ap-northeast-2
# S3_BUCKET=

# Optional: Email
# SENDGRID_API_KEY=
# SENDGRID_FROM=

# Optional: Stripe
# STRIPE_API_KEY=
# STRIPE_WEBHOOK_SECRET=
```

### 프로덕션용 (ECS Task Definition)

```json
{
  "environment": [
    { "name": "NODE_ENV", "value": "production" },
    { "name": "MEDUSA_ADMIN_ONBOARDING_TYPE", "value": "default" },
    { "name": "STORE_CORS", "value": "https://yourdomain.com" },
    { "name": "ADMIN_CORS", "value": "https://admin.yourdomain.com" }
  ],
  "secrets": [
    {
      "name": "DATABASE_URL",
      "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:medusa/production/database-url"
    },
    {
      "name": "REDIS_URL",
      "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:medusa/production/redis-url"
    }
  ]
}
```

---

## 참고 자료

- [Medusa Configuration](https://docs.medusajs.com/development/backend/configurations)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Upstash Redis](https://docs.upstash.com/redis)
- [ECS Task Definition Environment Variables](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/taskdef-envfiles.html)
