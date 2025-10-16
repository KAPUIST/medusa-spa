# 개발 환경 가이드

## 프로젝트 구조

```
spa-medusa-monorepo/
├── apps/
│   └── server/              # Medusa 백엔드 서버
├── packages/                # 공유 패키지
├── docker-compose.yml       # 로컬 개발용 인프라 (PostgreSQL, Redis)
├── Dockerfile.server        # 프로덕션 배포용
└── turbo.json              # Turborepo 설정
```

## 개발 환경 vs 프로덕션 환경

### 로컬 개발 환경
**목적**: 빠른 개발과 디버깅

```bash
# 1. 인프라 실행 (PostgreSQL, Redis)
docker compose up -d

# 2. 앱 실행 (호스트에서 직접)
cd apps/server
yarn dev
```

**특징**:
- ✅ Hot reload - 코드 변경 즉시 반영
- ✅ 빠른 재시작
- ✅ IDE 디버거 직접 연결 가능
- ✅ 로그 확인 편함

**환경변수**: `.env` 또는 `.env.local`

---

### 프로덕션 환경 (CI/CD)
**목적**: 실제 배포 환경과 동일한 방식으로 테스트

```bash
# Docker 이미지 빌드
docker build -f Dockerfile.server -t medusa-server .

# 컨테이너 실행
docker run -p 9000:9000 --env-file apps/server/.env.production medusa-server
```

**특징**:
- ✅ 프로덕션 빌드 (최적화됨)
- ✅ 일관된 환경
- ✅ 배포 전 문제 발견
- ✅ CI/CD 파이프라인과 동일

**환경변수**: `.env.production` (실제 배포 시 외부 주입)

---

## 워크플로우

### 1. 로컬 개발

```bash
# 의존성 설치
yarn install

# 인프라 실행
docker compose up -d

# DB 마이그레이션
cd apps/server
npx medusa db:migrate

# 개발 서버 실행
yarn dev
```

**접속**:
- API: http://localhost:9000
- Admin: http://localhost:9000/app

---

### 2. CI/CD 파이프라인

```
개발자 작업 (로컬)
  ├─ yarn dev로 개발
  ├─ 코드 작성 & 테스트
  └─ git push
       ↓
GitHub Actions (자동)
  ├─ 코드 체크아웃
  ├─ Docker 이미지 빌드 (Dockerfile.server)
  ├─ 이미지 레지스트리에 푸시 (ECR/Docker Hub)
  └─ 배포 트리거
       ↓
프로덕션 배포 (AWS ECS/K8s)
  ├─ 컨테이너 실행
  ├─ 환경변수 주입 (AWS Secrets Manager 등)
  └─ 헬스체크 & 로드밸런서 연결
```

---

## 왜 이렇게 하나?

### ❓ 로컬에서 Docker를 쓰지 않는 이유
1. **개발 속도**: yarn dev가 Docker보다 훨씬 빠름
2. **디버깅**: IDE에서 바로 디버깅 가능
3. **Hot Reload**: 코드 변경 즉시 반영

### ❓ CI/CD에서 Docker를 쓰는 이유
1. **환경 일관성**: 어디서든 동일하게 실행
2. **프로덕션 재현**: 실제 배포 환경과 동일
3. **격리**: 의존성 충돌 방지

---

## 환경별 설정

### 로컬 개발 (.env.local)
```env
DATABASE_URL=postgres://postgres:postgres@localhost:5432/spa-medusa
REDIS_URL=redis://localhost:6379
STORE_CORS=http://localhost:8000
ADMIN_CORS=http://localhost:9000
JWT_SECRET=supersecret
COOKIE_SECRET=supersecret
NODE_ENV=development
```

### 프로덕션 (.env.production)
```env
# 실제 배포 시 AWS Secrets Manager 등에서 주입
DATABASE_URL=${DATABASE_URL}
REDIS_URL=${REDIS_URL}
JWT_SECRET=${JWT_SECRET}
COOKIE_SECRET=${COOKIE_SECRET}
NODE_ENV=production
```

---

## 일반적인 명령어

### 로컬 개발
```bash
# 인프라 시작
docker compose up -d

# 인프라 중지
docker compose down

# 개발 서버 실행
yarn dev

# 빌드
yarn build

# 마이그레이션
npx medusa db:migrate

# 시딩
yarn seed
```

### Docker (프로덕션 테스트)
```bash
# 이미지 빌드
docker build -f Dockerfile.server -t medusa-server .

# 컨테이너 실행
docker run -d \
  -p 9000:9000 \
  --env-file apps/server/.env.production \
  --name medusa-server \
  medusa-server

# 로그 확인
docker logs -f medusa-server

# 중지 & 삭제
docker stop medusa-server
docker rm medusa-server
```

---

## 문제 해결

### PostgreSQL 연결 오류
```bash
# 컨테이너 상태 확인
docker compose ps

# PostgreSQL 재시작
docker compose restart postgres
```

### Redis 연결 오류
```bash
# Redis 컨테이너 확인
docker compose logs redis

# Redis 재시작
docker compose restart redis
```

### 빌드 오류
```bash
# 캐시 삭제 후 재설치
rm -rf node_modules
yarn install
yarn build
```

---

## 다음 단계

1. ✅ 로컬 개발 환경 설정 완료
2. 🚧 Dockerfile 최적화
3. ⏭️ GitHub Actions CI/CD 설정
4. ⏭️ AWS ECS/EC2 배포 설정

---

## 참고 링크

- [Turborepo 공식 문서](https://turbo.build/repo/docs)
- [Medusa 공식 문서](https://docs.medusajs.com)
- [Docker 공식 문서](https://docs.docker.com)
