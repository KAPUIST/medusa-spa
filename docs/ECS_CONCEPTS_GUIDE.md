# ECS 핵심 개념 가이드 (쉽게 이해하기)

Docker와 ECS를 처음 접하는 분들을 위한 가이드입니다.

## 목차

1. [Docker 기본 개념](#docker-기본-개념)
2. [ECS 핵심 용어](#ecs-핵심-용어)
3. [ECS 배포 흐름](#ecs-배포-흐름)
4. [실전 비유로 이해하기](#실전-비유로-이해하기)
5. [자주 사용하는 명령어](#자주-사용하는-명령어)

---

## Docker 기본 개념

### 1. Docker Image (이미지)

**비유**: 앱 설치 파일 (예: .exe, .dmg)

```
📦 Docker Image
├── Node.js 런타임
├── Medusa 앱 코드
├── 의존성 패키지
└── 실행 방법 (CMD)
```

**특징**:

- 읽기 전용
- 한 번 만들면 변경 불가
- ECR에 저장됨
- 버전 관리 가능 (태그: latest, v1.0.0)

**생성 방법**:

```bash
docker build -t medusa-server -f apps/server/Dockerfile .
```

### 2. Docker Container (컨테이너)

**비유**: 실행 중인 앱 프로세스

```
🏃 Running Container
= Image를 실행한 것
= 실제로 메모리에 올라가서 동작 중
```

**특징**:

- Image에서 생성됨
- 실행 중 상태 변경 가능
- 여러 개 동시 실행 가능 (같은 Image로)
- 중지하면 데이터 사라짐 (볼륨 사용하지 않으면)

---

## ECS 핵심 용어

### 1. ECR (Elastic Container Registry)

**비유**: Docker Image 저장소 (GitHub for Docker Images)

```
📚 ECR Repository
├── medusa-server:latest
├── medusa-server:v1.0.0
└── medusa-server:a1b2c3d (git commit hash)
```

**역할**:

- Docker Image를 저장
- ECS가 여기서 Image를 가져와서 실행
- GitHub Actions가 빌드한 Image를 여기에 푸시

**URL 형식**:

```
637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server:latest
    ↑              ↑           ↑                         ↑         ↑
계정 ID        서비스    리전                    Repository 이름  태그
```

---

### 2. ECS Task Definition (작업 정의)

**비유**: 앱 실행 레시피 (설정 템플릿)

```json
{
  "family": "medusa-task",
  "cpu": "512", // 0.5 vCPU
  "memory": "1024", // 1GB RAM
  "containerDefinitions": [
    {
      "name": "medusa-server",
      "image": "ECR_URI:latest",
      "portMappings": [
        {
          "containerPort": 9000 // 앱이 사용하는 포트
        }
      ],
      "environment": [
        // 환경변수
        { "name": "NODE_ENV", "value": "production" },
        { "name": "DATABASE_URL", "value": "postgres://..." }
      ]
    }
  ]
}
```

**포함 내용**:

- ✅ 어떤 Image를 사용할지
- ✅ CPU/메모리 할당량
- ✅ 환경변수 설정
- ✅ 포트 매핑
- ✅ 로그 설정
- ✅ 헬스체크 방법

**버전 관리**:

- 수정할 때마다 새 버전 생성 (medusa-task:1, medusa-task:2)
- 이전 버전으로 롤백 가능

---

### 3. ECS Cluster (클러스터)

**비유**: 서버들을 묶는 그룹 (논리적 컨테이너)

```
🏢 ECS Cluster "medusa-cluster"
├── Service 1 (medusa-service)
│   ├── Task 1 (실행 중)
│   └── Task 2 (실행 중)
├── Service 2 (worker-service)
│   └── Task 1 (실행 중)
└── 단독 Task (일회성 작업)
```

**역할**:

- 리소스를 논리적으로 그룹화
- 여러 Service를 관리
- Fargate/EC2 capacity provider 설정

---

### 4. ECS Task (작업)

**비유**: 실행 중인 컨테이너 인스턴스

```
🏃 Task = Task Definition을 실제로 실행한 것
      = Running Container(s)
```

**예시**:

```
Task ID: abc123def456
├── Container: medusa-server (실행 중)
├── IP: 172.30.1.50
├── Status: RUNNING
└── Health: HEALTHY
```

**Task 종류**:

1. **Service Task**: Service가 관리 (자동 재시작)
2. **Standalone Task**: 일회성 작업 (배치 작업 등)

**Task 생명주기**:

```
PROVISIONING → PENDING → RUNNING → STOPPING → STOPPED
     ↓            ↓          ↓
  리소스 할당  Image Pull  앱 실행
```

---

### 5. ECS Service (서비스)

**비유**: Task를 관리하는 관리자

```
👔 ECS Service "medusa-service"
역할:
├── Task 개수 유지 (desired count: 2)
│   ├── Task 1 죽으면 → 새 Task 자동 시작
│   └── 항상 2개 유지
├── Load Balancer 연결
│   └── ALB → Service → Tasks
├── 무중단 배포 (Rolling Update)
│   ├── 새 Task Definition 배포 시
│   ├── 새 Task 시작 → 헬스체크 통과
│   └── 기존 Task 중지
└── Auto Scaling (선택)
    └── CPU 사용률에 따라 Task 수 조정
```

**설정 항목**:

- **Desired Count**: 유지할 Task 개수
- **Launch Type**: FARGATE (서버리스) or EC2
- **Network**: VPC, Subnet, Security Group
- **Load Balancer**: ALB 연결 설정
- **Deployment**: Rolling update 설정

---

### 6. ALB (Application Load Balancer)

**비유**: 트래픽 분산기 + 라우터

```
🌐 Internet
    ↓
📡 ALB (Port 80/443)
    ↓
🎯 Target Group (medusa-tg)
    ├── Task 1 (172.30.1.10:9000) ✅ Healthy
    └── Task 2 (172.30.2.15:9000) ✅ Healthy
```

**역할**:

1. **트래픽 분산**: 요청을 여러 Task에 골고루 분배
2. **헬스체크**: 죽은 Task로는 트래픽 안 보냄
3. **SSL 종료**: HTTPS 인증서 처리
4. **고정 DNS**: ALB DNS는 변경 안 됨 (Task IP는 계속 바뀜)

---

## ECS 배포 흐름

### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                       │
│  git push → Build Docker → Push to ECR → Update ECS    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                         ECR                             │
│  📦 medusa-server:abc123 (Docker Image)                │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   Task Definition                       │
│  📋 medusa-task:5 (레시피)                              │
│    - Image: ECR URI                                     │
│    - CPU/Memory: 512/1024                              │
│    - Environment Variables                              │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                    ECS Cluster                          │
│  🏢 medusa-cluster                                      │
│     └── 👔 Service: medusa-service                     │
│          ├── 🏃 Task 1 (RUNNING)                       │
│          └── 🏃 Task 2 (RUNNING)                       │
└─────────────────────────────────────────────────────────┘
                            ↑
┌─────────────────────────────────────────────────────────┐
│                        ALB                              │
│  📡 medusa-alb-xxx.elb.amazonaws.com                   │
│     └── Target Group → Tasks                           │
└─────────────────────────────────────────────────────────┘
                            ↑
                      🌐 Internet
```

---

### 배포 시나리오: 코드 변경부터 배포까지

#### 1단계: 코드 변경 및 푸시

```bash
# 로컬에서 코드 수정
vim apps/server/src/api/routes.ts

# 커밋 & 푸시
git add .
git commit -m "feat: add new API endpoint"
git push origin main
```

#### 2단계: GitHub Actions 자동 실행

```yaml
# .github/workflows/deploy-ecs.yml
1. Checkout code
2. Build Docker Image
└── docker build -t medusa-server .
3. Tag Image
└── docker tag medusa-server ECR_URI:abc123
4. Push to ECR
└── docker push ECR_URI:abc123
5. Update Task Definition
└── 환경변수 주입 (GitHub Secrets)
6. Deploy to ECS
└── aws ecs update-service --force-new-deployment
```

#### 3단계: ECS Rolling Update

```
현재 상태:
├── Task 1 (기존 버전)
└── Task 2 (기존 버전)

배포 시작:
├── Task 3 (새 버전) 시작
│   └── Image Pull → 컨테이너 시작 → 헬스체크
└── Task 1, 2는 계속 실행 (무중단)

Task 3 헬스체크 통과:
├── Task 3 (새 버전) ✅ HEALTHY → ALB에 등록
├── Task 1 (기존 버전) 중지
└── Task 2 (기존 버전) 계속 실행

Task 4 시작:
├── Task 3 (새 버전) ✅
├── Task 4 (새 버전) 시작 → 헬스체크
└── Task 2 (기존 버전) 계속 실행

Task 4 헬스체크 통과:
├── Task 3 (새 버전) ✅
├── Task 4 (새 버전) ✅
└── Task 2 (기존 버전) 중지

배포 완료:
├── Task 3 (새 버전) ✅
└── Task 4 (새 버전) ✅
```

---

## 실전 비유로 이해하기

### 레스토랑 비유

```
📚 ECR = 레시피 저장소
   └── 요리법이 적힌 책들

📋 Task Definition = 레시피 카드
   └── "파스타 만드는 법: 재료, 순서, 불 세기"

🏢 ECS Cluster = 레스토랑 건물
   └── 주방들이 모여있는 공간

👔 ECS Service = 주방장
   └── "항상 파스타 요리사 2명 유지"
   └── 한 명 퇴사하면 새 요리사 고용

🏃 Task = 실제 요리사
   └── 레시피 보고 파스타 만드는 중

📡 ALB = 홀 매니저
   └── 손님 → 여유있는 요리사에게 주문 전달
```

---

## 자주 사용하는 명령어

### ECR 관련

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 637423422501.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 푸시
docker push 637423422501.dkr.ecr.ap-northeast-2.amazonaws.com/medusa-server:latest

# ECR 이미지 목록 확인
aws ecr list-images --repository-name medusa-server
```

### Task Definition 관련

```bash
# Task Definition 목록
aws ecs list-task-definitions --family-prefix medusa-task

# 특정 버전 확인
aws ecs describe-task-definition --task-definition medusa-task:5

# 새 버전 등록
aws ecs register-task-definition --cli-input-json file://task-def.json
```

### Service 관련

```bash
# Service 상태 확인
aws ecs describe-services \
  --cluster medusa-cluster \
  --services medusa-service

# Service 업데이트 (강제 재배포)
aws ecs update-service \
  --cluster medusa-cluster \
  --service medusa-service \
  --force-new-deployment

# Service Task 개수 변경
aws ecs update-service \
  --cluster medusa-cluster \
  --service medusa-service \
  --desired-count 3
```

### Task 관련

```bash
# 실행 중인 Task 목록
aws ecs list-tasks --cluster medusa-cluster --service-name medusa-service

# Task 상세 정보
aws ecs describe-tasks \
  --cluster medusa-cluster \
  --tasks arn:aws:ecs:...

# Task 로그 확인
aws logs tail /ecs/medusa --follow

# Task 강제 중지
aws ecs stop-task --cluster medusa-cluster --task arn:aws:ecs:...
```

---

## 문제 해결 (Troubleshooting)

### 503 Service Unavailable

**원인**:

1. Task가 아직 시작 중 (PENDING)
2. 헬스체크 실패 (컨테이너는 실행 중이지만 `/health` 응답 안 함)
3. Task가 계속 재시작됨

**해결**:

```bash
# 1. Service 이벤트 확인
aws ecs describe-services \
  --cluster medusa-cluster \
  --services medusa-service \
  --query 'services[0].events[0:5]'

# 2. Task 상태 확인
aws ecs list-tasks --cluster medusa-cluster --service-name medusa-service

# 3. Task 로그 확인 (가장 중요!)
aws logs tail /ecs/medusa --follow
```

**자주 발생하는 원인**:

- ❌ 환경변수 누락 (DATABASE_URL 등)
- ❌ RDS 접근 불가 (Security Group)
- ❌ 포트 번호 불일치 (9000이 아닌 다른 포트 사용)
- ❌ 메모리 부족 (OOM Killed)

### Task가 계속 재시작됨

```bash
# 로그에서 에러 확인
aws logs tail /ecs/medusa --follow

# Task 중지 이유 확인
aws ecs describe-tasks \
  --cluster medusa-cluster \
  --tasks TASK_ARN \
  --query 'tasks[0].{StoppedReason:stoppedReason,Containers:containers[0].reason}'
```

---

## 핵심 정리

### 최소한 알아야 할 것

1. **Image**: 앱 설치 파일
2. **Task Definition**: 실행 레시피
3. **Task**: 실행 중인 앱
4. **Service**: Task 관리자 (개수 유지, 자동 재시작)
5. **ALB**: 트래픽 분산기

### 배포 흐름 (간단 버전)

```
코드 수정 → GitHub Push
    ↓
GitHub Actions
    ├── Docker 빌드
    ├── ECR 푸시
    └── ECS 업데이트
    ↓
ECS Service
    ├── 새 Task 시작
    ├── 헬스체크 통과
    └── 기존 Task 중지
    ↓
배포 완료!
```

### 디버깅 3단계

```bash
# 1단계: Service 상태
aws ecs describe-services --cluster medusa-cluster --services medusa-service

# 2단계: Task 목록
aws ecs list-tasks --cluster medusa-cluster --service-name medusa-service

# 3단계: 로그 확인 (가장 중요!)
aws logs tail /ecs/medusa --follow
```

---

## 다음 학습 자료

- [AWS ECS 공식 문서](https://docs.aws.amazon.com/ecs/)
- [Docker 공식 튜토리얼](https://docs.docker.com/get-started/)
- [Fargate vs EC2 비교](https://aws.amazon.com/fargate/pricing/)

---

**질문이 있으면 이 문서를 참고하세요!**
