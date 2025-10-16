# GitHub Secrets 설정 가이드

이 가이드는 `.env.production` 파일의 환경변수를 GitHub Secrets로 설정하는 방법을 안내합니다.

## 왜 GitHub Secrets를 사용하나요?

- ✅ **보안**: 민감한 정보(비밀번호, API 키)를 Git에 커밋하지 않음
- ✅ **자동화**: GitHub Actions에서 자동으로 ECS에 환경변수 주입
- ✅ **관리 편의성**: 웹 UI에서 쉽게 업데이트 가능

---

## 1단계: 환경변수 값 준비

### 필수 환경변수

#### 1. Security Secrets 생성

강력한 랜덤 문자열을 생성하세요:

```bash
# JWT Secret 생성
openssl rand -base64 32
# 출력 예: Kv3jH9xP2mN8qR4tY7wZ1aB5cD6eF0gH1iJ2kL3mN4o=

# Cookie Secret 생성
openssl rand -base64 32
# 출력 예: Xp9qW2eR5tY8uI1oP3aS6dF7gH0jK4lZ9xC2vB5nM8Q=
```

#### 2. RDS 정보 확인

```bash
# AWS Console > RDS > Databases > 선택
# 또는 CLI로 확인:
aws rds describe-db-instances \
  --db-instance-identifier your-db-name \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# 출력 예: medusa-db.c1a2b3c4d5e6.ap-northeast-2.rds.amazonaws.com
```

**DATABASE_URL 형식**:

```
postgres://USERNAME:PASSWORD@ENDPOINT:5432/DATABASE_NAME
```

**예시**:

```
postgres://medusaadmin:MyStr0ngP@ssw0rd@medusa-db.c1a2b3c4d5e6.ap-northeast-2.rds.amazonaws.com:5432/medusa
```

#### 3. Upstash Redis URL 확인

1. [Upstash Dashboard](https://console.upstash.com/) 접속
2. Redis 데이터베이스 선택
3. **Connect** 탭 클릭
4. **Redis URL** 복사

**형식**:

```
rediss://default:YOUR_PASSWORD@YOUR_ENDPOINT.upstash.io:6379
```

**예시**:

```
rediss://default:AaBbCc123XxYyZz456@gusc1-fun-12345.upstash.io:6379
```

#### 4. CORS 도메인 설정

프론트엔드 도메인을 설정하세요:

```bash
# 스토어 (고객용 웹사이트)
STORE_CORS=https://yourdomain.com,https://www.yourdomain.com

# 관리자 패널
ADMIN_CORS=https://admin.yourdomain.com

# 인증
AUTH_CORS=https://admin.yourdomain.com
```

**개발/테스트 환경**:

```bash
STORE_CORS=http://localhost:3000,http://localhost:8000
ADMIN_CORS=http://localhost:3000,http://localhost:7001
AUTH_CORS=http://localhost:7001
```

---

## 2단계: GitHub Secrets 설정

### GitHub 리포지토리에서 설정

1. **GitHub 리포지토리 접속**
2. **Settings** 클릭
3. 좌측 메뉴에서 **Secrets and variables** > **Actions** 클릭
4. **New repository secret** 클릭

### 추가할 Secrets 목록

#### AWS 관련 (필수)

| Secret Name             | 설명                      | 예시 값                             |
| ----------------------- | ------------------------- | ----------------------------------- |
| `AWS_ACCESS_KEY_ID`     | AWS IAM 사용자 Access Key | `AKIAIOSFODNN7EXAMPLE`              |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM 사용자 Secret Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCY...` |
| `AWS_REGION`            | AWS 리전                  | `ap-northeast-2`                    |

#### 애플리케이션 환경변수 (필수)

| Secret Name     | 설명                    | 예시 값                                 |
| --------------- | ----------------------- | --------------------------------------- |
| `DATABASE_URL`  | RDS PostgreSQL 연결 URL | `postgres://user:pass@endpoint:5432/db` |
| `POSTGRES_URL`  | DATABASE_URL과 동일     | `postgres://user:pass@endpoint:5432/db` |
| `REDIS_URL`     | Upstash Redis URL       | `rediss://default:pass@endpoint:6379`   |
| `JWT_SECRET`    | JWT 토큰 암호화 키      | `Kv3jH9xP2mN8qR4tY7wZ1aB5cD6eF0gH...`   |
| `COOKIE_SECRET` | 쿠키 암호화 키          | `Xp9qW2eR5tY8uI1oP3aS6dF7gH0jK4lZ...`   |
| `STORE_CORS`    | 스토어 도메인           | `https://yourdomain.com`                |
| `ADMIN_CORS`    | 관리자 패널 도메인      | `https://admin.yourdomain.com`          |
| `AUTH_CORS`     | 인증 도메인             | `https://admin.yourdomain.com`          |

#### 선택적 Secrets (S3, 이메일 등)

| Secret Name        | 설명            | 필요 시                    |
| ------------------ | --------------- | -------------------------- |
| `S3_BUCKET`        | S3 버킷 이름    | 미디어 파일 업로드 사용 시 |
| `SENDGRID_API_KEY` | SendGrid API 키 | 이메일 발송 사용 시        |
| `STRIPE_API_KEY`   | Stripe API 키   | 결제 기능 사용 시          |

---

## 3단계: Secrets 추가 방법 (단계별)

### 예시: DATABASE_URL 추가

1. **New repository secret** 클릭
2. **Name** 입력: `DATABASE_URL`
3. **Secret** 입력:
   ```
   postgres://medusaadmin:MyStr0ngP@ssw0rd@medusa-db.c1a2b3c4d5e6.ap-northeast-2.rds.amazonaws.com:5432/medusa
   ```
4. **Add secret** 클릭

### 빠른 설정 체크리스트

각 Secret을 추가하면서 체크하세요:

```
AWS 설정:
□ AWS_ACCESS_KEY_ID
□ AWS_SECRET_ACCESS_KEY
□ AWS_REGION

데이터베이스:
□ DATABASE_URL
□ POSTGRES_URL

캐시:
□ REDIS_URL

보안:
□ JWT_SECRET
□ COOKIE_SECRET

CORS:
□ STORE_CORS
□ ADMIN_CORS
□ AUTH_CORS
```

---

## 4단계: 설정 확인

### GitHub Actions 워크플로우 실행

Secrets 설정 후 테스트 배포를 실행하세요:

```bash
# 브랜치 생성
git checkout -b test/github-secrets

# 더미 변경 (워크플로우 트리거용)
echo "# Test secrets" >> README.md

# 커밋 및 푸시
git add README.md
git commit -m "test(deploy): verify GitHub Secrets configuration"
git push origin test/github-secrets

# main에 머지
git checkout main
git merge test/github-secrets
git push origin main
```

### GitHub Actions 로그 확인

1. GitHub 리포지토리 > **Actions** 탭
2. 최근 워크플로우 실행 클릭
3. **Deploy to ECS** 작업 확인
4. 각 단계별 로그 확인

**환경변수가 제대로 주입되었는지 확인**:

- "Update task definition with environment variables" 단계가 성공해야 함
- Secrets는 `***`로 마스킹되어 표시됨

### ECS Task 로그 확인

배포 완료 후 ECS Task 로그에서 환경변수 확인:

```bash
# CloudWatch Logs 확인
aws logs tail /ecs/medusa --follow

# 또는 AWS Console에서:
# CloudWatch > Log groups > /ecs/medusa
```

**확인할 내용**:

- ✅ 데이터베이스 연결 성공
- ✅ Redis 연결 성공
- ✅ 서버 시작 성공
- ❌ 환경변수 관련 에러 없음

---

## 5단계: 보안 베스트 프랙티스

### ✅ DO

- ✅ 강력한 비밀번호 사용 (최소 16자, 대소문자/숫자/특수문자 혼합)
- ✅ JWT/Cookie Secret은 `openssl rand -base64 32`로 생성
- ✅ Secrets 값 변경 시 즉시 GitHub에서 업데이트
- ✅ 정기적으로 비밀번호 변경 (3-6개월마다)
- ✅ AWS IAM 사용자는 최소 권한만 부여 (Principle of Least Privilege)

### ❌ DON'T

- ❌ `.env.production` 파일에 실제 값 커밋하지 않기
- ❌ 로그에 Secrets 출력하지 않기
- ❌ Secrets를 코드에 하드코딩하지 않기
- ❌ 개발/테스트용 Secrets와 프로덕션 Secrets 혼용하지 않기

### .gitignore 확인

`.env.production` 파일이 Git에 커밋되지 않도록 확인:

```bash
# .gitignore에 추가되어 있는지 확인
cat .gitignore | grep ".env"

# 출력 예:
# .env
# .env.local
# .env.production
# .env.*.local
```

---

## 트러블슈팅

### Secret 값이 반영되지 않는 경우

1. **GitHub Actions 워크플로우 재실행**:
   - Actions 탭 > 워크플로우 선택 > "Re-run jobs"

2. **Secret 이름 확인**:
   - 워크플로우 파일의 `${{ secrets.NAME }}`과 GitHub Secrets의 이름이 정확히 일치해야 함
   - 대소문자 구분됨!

3. **ECS Task Definition 확인**:
   ```bash
   aws ecs describe-task-definition \
     --task-definition medusa-task \
     --query 'taskDefinition.containerDefinitions[0].environment'
   ```

### 환경변수 형식 오류

#### DATABASE_URL 형식 오류

```bash
# 잘못된 예:
postgres://user:pass@endpoint/database  # ❌ 포트 누락

# 올바른 예:
postgres://user:pass@endpoint:5432/database  # ✅
```

#### REDIS_URL TLS 오류

```bash
# Upstash는 TLS 필수
redis://endpoint:6379   # ❌ TLS 미사용
rediss://endpoint:6379  # ✅ TLS 사용 (s 추가)
```

### Secret 업데이트 후 적용 안 됨

ECS Service를 강제로 재배포하세요:

```bash
aws ecs update-service \
  --cluster medusa-cluster \
  --service medusa-service \
  --force-new-deployment
```

---

## 대안: AWS Secrets Manager 사용

더 높은 보안이 필요한 경우 AWS Secrets Manager를 사용할 수 있습니다.

### 장점

- ✅ 자동 암호화
- ✅ 비밀번호 자동 로테이션
- ✅ 세밀한 접근 제어
- ✅ 감사 로그 (CloudTrail)

### 단점

- ❌ 추가 비용 ($0.40/시크릿/월 + API 호출 비용)
- ❌ 설정 복잡도 증가

**설정 방법은 `docs/ENVIRONMENT_VARIABLES.md`를 참고하세요.**

---

## 요약 체크리스트

배포 전 최종 확인:

```
준비 단계:
□ 모든 환경변수 값 준비 완료
□ JWT_SECRET, COOKIE_SECRET 생성 완료
□ RDS 엔드포인트 확인
□ Upstash Redis URL 확인

GitHub Secrets 설정:
□ AWS 관련 Secrets 추가 (3개)
□ 애플리케이션 Secrets 추가 (8개)
□ Secrets 이름 정확히 입력

테스트:
□ GitHub Actions 워크플로우 실행 성공
□ ECS Task 정상 실행 확인
□ CloudWatch Logs에서 에러 없음 확인
□ ALB 헬스체크 통과 확인

보안:
□ .env.production에 실제 값 없음 확인
□ .gitignore 설정 확인
□ AWS IAM 최소 권한 설정
```

---

## 다음 단계

- [ ] 도메인 연결 (Route53)
- [ ] SSL 인증서 발급 (ACM)
- [ ] 프로덕션 배포 테스트
- [ ] 모니터링 설정 (CloudWatch Alarms)
- [ ] 백업 전략 수립

---

## 참고 자료

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Upstash Redis Documentation](https://docs.upstash.com/redis)
- [Medusa Environment Variables](https://docs.medusajs.com/development/backend/configurations)
