# 환경변수 파일 가이드

프로젝트에서 사용하는 환경변수 파일들의 역할과 사용법을 설명합니다.

## 파일 목록

```
apps/server/
├── .env.template      # Git 커밋 ✅ - 템플릿/문서용
├── .env.local         # Git 무시 ❌ - 로컬 개발용
├── .env.production    # Git 무시 ❌ - 프로덕션 템플릿
├── .env.test         # Git 무시 ❌ - 테스트용
└── .env              # Git 무시 ❌ - 자동 생성됨
```

---

## 1. `.env.template` (기본 템플릿)

### 용도

- 새로운 개발자를 위한 **참고 문서**
- 필수 환경변수 목록 제공
- Git에 커밋되어 팀원들과 공유

### 내용

```bash
STORE_CORS=http://localhost:8000,https://docs.medusajs.com
ADMIN_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
AUTH_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
REDIS_URL=redis://localhost:6379
JWT_SECRET=supersecret
COOKIE_SECRET=supersecret
DATABASE_URL=
DB_NAME=medusa-v2
```

### 사용 방법

```bash
# 처음 프로젝트 시작 시
cp apps/server/.env.template apps/server/.env.local

# 그 다음 실제 값으로 수정
nano apps/server/.env.local
```

---

## 2. `.env.local` (로컬 개발 환경)

### 용도

- **개발자 개인의 로컬 머신**에서 사용
- `yarn dev` 실행 시 자동으로 로드
- Git에 커밋하지 않음 (개인 설정)

### 내용 (현재 프로젝트)

```bash
# Local Development Environment
STORE_CORS=http://localhost:8000,https://docs.medusajs.com
ADMIN_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
AUTH_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
JWT_SECRET=supersecret
COOKIE_SECRET=supersecret
DB_NAME=spa-medusa

# These will be overridden by docker-compose if running in container
DATABASE_URL=postgres://postgres:postgres@localhost:5432/spa-medusa
REDIS_URL=redis://localhost:6379
NODE_ENV=development
```

### 특징

- **약한 Secret 사용 가능**: `supersecret` (개발용이라 괜찮음)
- **localhost 주소**: 로컬 PostgreSQL, Redis
- **NODE_ENV**: `development`

### 로컬 PostgreSQL/Redis 실행

```bash
# Docker Compose로 실행
docker-compose up -d postgres redis

# 또는 직접 설치
brew install postgresql redis
brew services start postgresql
brew services start redis
```

---

## 3. `.env.production` (프로덕션 환경)

### 용도

- **AWS ECS 등 프로덕션 서버**에서 사용
- GitHub Secrets로 관리
- 실제 서비스 배포 시 사용

### 내용 (템플릿)

```bash
# Application Environment
NODE_ENV=production

# CORS Settings (Frontend domains)
STORE_CORS=http://localhost:8000,https://docs.medusajs.com
ADMIN_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com
AUTH_CORS=http://localhost:5173,http://localhost:9000,https://docs.medusajs.com

# Security Secrets (Generate strong random strings)
JWT_SECRET=zUc4bT+eTPJW8rGTePZzpHt71NGYURCh5Y8WnU0tS8U=
COOKIE_SECRET=EUzFCTbrsCZdOksVgvaSzOIv5Gl6XXDSGJ1mQctRkBg=

# Database (RDS PostgreSQL)
DATABASE_URL=postgres://username:password@your-rds.ap-northeast-2.rds.amazonaws.com:5432/medusa
POSTGRES_URL=postgres://username:password@your-rds.ap-northeast-2.rds.amazonaws.com:5432/medusa

# Redis (Upstash)
REDIS_URL=rediss://default:your-password@your-endpoint.upstash.io:6379

# Medusa Configuration
MEDUSA_ADMIN_ONBOARDING_TYPE=default
```

### 특징

- **강력한 Secret**: `openssl rand -base64 32`로 생성
- **실제 서비스 주소**: RDS, Upstash Redis
- **TLS 사용**: `rediss://` (s 추가)
- **실제 도메인**: `https://yourdomain.com`

### 프로덕션 배포 방법

이 파일의 값들을 **GitHub Secrets**에 설정하고, GitHub Actions가 자동으로 ECS에 주입합니다.

자세한 내용은 `docs/GITHUB_SECRETS_SETUP.md` 참고

---

## 파일별 비교표

| 항목              | .env.template    | .env.local       | .env.production     |
| ----------------- | ---------------- | ---------------- | ------------------- |
| **Git 커밋**      | ✅ 예            | ❌ 아니오        | ❌ 아니오           |
| **용도**          | 문서/참고        | 로컬 개발        | 프로덕션 배포       |
| **실제 값**       | ❌               | ✅               | ✅ (GitHub Secrets) |
| **DATABASE_URL**  | 빈 값            | `localhost:5432` | RDS 엔드포인트      |
| **REDIS_URL**     | `localhost:6379` | `localhost:6379` | Upstash (TLS)       |
| **NODE_ENV**      | -                | `development`    | `production`        |
| **JWT_SECRET**    | `supersecret`    | `supersecret`    | 강력한 랜덤 문자열  |
| **COOKIE_SECRET** | `supersecret`    | `supersecret`    | 강력한 랜덤 문자열  |
| **CORS**          | `localhost`      | `localhost`      | 실제 도메인         |

---

## 환경변수 로딩 우선순위

Node.js (dotenv) 로딩 순서:

```
1. 실제 환경변수 (process.env) - 최우선
   ↓
2. .env.production.local
   ↓
3. .env.production  (NODE_ENV=production일 때)
   ↓
4. .env.local
   ↓
5. .env
   ↓
6. .env.template (로드 안 됨 - 문서용)
```

---

## 사용 시나리오

### 시나리오 1: 새로운 개발자 온보딩

```bash
# 1. 리포지토리 클론
git clone <repo-url>
cd spa-medusa-monorepo

# 2. 템플릿 복사
cp apps/server/.env.template apps/server/.env.local

# 3. 로컬 환경에 맞게 수정
nano apps/server/.env.local

# 4. 의존성 설치 및 실행
yarn install
yarn dev
```

### 시나리오 2: 로컬 개발

```bash
# .env.local 사용
yarn dev

# 환경변수 확인
echo $DATABASE_URL
# 출력: postgres://postgres:postgres@localhost:5432/spa-medusa
```

### 시나리오 3: 프로덕션 배포

```bash
# 1. .env.production 값들을 GitHub Secrets에 설정
# (웹 UI에서 수동 설정)

# 2. 코드 푸시
git push origin main

# 3. GitHub Actions가 자동으로:
# - Docker 이미지 빌드
# - GitHub Secrets를 환경변수로 주입
# - ECS에 배포
```

---

## .gitignore 확인

다음 파일들이 `.gitignore`에 포함되어야 합니다:

```gitignore
# Environment variables
.env
.env.local
.env.production
.env.*.local
.env.test

# 예외: 템플릿은 커밋
!.env.template
!.env.example
```

**확인 방법**:

```bash
git check-ignore apps/server/.env.local
# 출력 있으면 무시됨 (정상)
```

---

## 보안 체크리스트

### ✅ DO

- ✅ `.env.template`만 Git에 커밋
- ✅ `.env.local`에 로컬 개발용 값 저장
- ✅ `.env.production` 실제 값은 GitHub Secrets에 저장
- ✅ 강력한 시크릿 생성 (`openssl rand -base64 32`)
- ✅ 정기적으로 프로덕션 시크릿 변경 (3-6개월)

### ❌ DON'T

- ❌ `.env.local` 또는 `.env.production`을 Git에 커밋하지 않기
- ❌ 프로덕션 시크릿을 Slack/이메일로 공유하지 않기
- ❌ 로컬 개발용 약한 시크릿을 프로덕션에 사용하지 않기
- ❌ 코드에 환경변수 하드코딩하지 않기

---

## 문제 해결

### 환경변수가 로드되지 않는 경우

```bash
# 1. 파일 존재 확인
ls -la apps/server/.env*

# 2. 파일 내용 확인
cat apps/server/.env.local

# 3. Node.js에서 로드 확인
node -e "require('dotenv').config({path: 'apps/server/.env.local'}); console.log(process.env.DATABASE_URL)"
```

### 프로덕션에서 환경변수 누락

```bash
# ECS Task Definition 확인
aws ecs describe-task-definition \
  --task-definition medusa-task \
  --query 'taskDefinition.containerDefinitions[0].environment'

# CloudWatch Logs에서 에러 확인
aws logs tail /ecs/medusa --follow
```

---

## 다음 단계

- [ ] `.env.local` 파일 생성 및 로컬 값 설정
- [ ] 로컬에서 `yarn dev` 테스트
- [ ] GitHub Secrets에 프로덕션 값 설정
- [ ] 프로덕션 배포 테스트

자세한 가이드:

- 로컬 설정: `README.md`
- GitHub Secrets 설정: `docs/GITHUB_SECRETS_SETUP.md`
- 프로덕션 배포: `docs/AWS_ECS_SETUP_SIMPLIFIED.md`

---

## 참고 자료

- [dotenv 공식 문서](https://github.com/motdotla/dotenv)
- [Medusa Environment Variables](https://docs.medusajs.com/development/backend/configurations)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
