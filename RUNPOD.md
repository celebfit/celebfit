# RunPod GPU 배포용 celebfit API

## 1. RunPod 가입

1. [runpod.io](https://www.runpod.io) 가입 + 결제 수단 등록
2. **Pods** → **Deploy**

## 2. Pod 설정

| 항목 | 권장 값 |
|------|---------|
| GPU | RTX 3090 / 4090 (VRAM **16GB+**) |
| Container Disk | **40 GB** |
| Volume Disk | **50 GB** (Network Volume, 모델 캐시용) |
| Volume Mount Path | `/data` |
| Expose HTTP Ports | `8000` |
| Container Image | 아래 방법 A 또는 B |

### 환경 변수

```
ENABLE_SD=true
USE_GITHUB_PIPELINE=true
ALLOW_FALLBACK=false
WARMUP_ON_START=true
HF_HOME=/data/huggingface
TORCH_HOME=/data/torch
```

## 3. 이미지 배포 방법

### 방법 A — GitHub에서 Docker 빌드 (권장)

1. `app` 브랜치에 `Dockerfile`, `api/`, `deploy/` push
2. RunPod → **Custom Container** → GitHub repo URL + branch `app`
3. Dockerfile path: `Dockerfile`
4. Build & Deploy

### 방법 B — Docker Hub

Mac/CI에서 빌드 후 push (로컬 디스크 부족 시 GitHub Actions 사용):

```bash
docker build -t YOUR_USER/celebfit-api:latest .
docker push YOUR_USER/celebfit-api:latest
```

RunPod Container Image: `YOUR_USER/celebfit-api:latest`

## 4. Pod URL 확인

RunPod 대시보드 → Pod → **Connect** → HTTP Service **Port 8000**

예:
```
https://xxxxxxxx-8000.proxy.runpod.net
```

### 동작 확인

```bash
curl https://xxxxxxxx-8000.proxy.runpod.net/health
curl -X POST https://xxxxxxxx-8000.proxy.runpod.net/api/v1/warmup
```

`message`에 `github sd_inpaint` 또는 `GitHub pipeline ready` 포함되면 성공.

Swagger: `https://xxxxxxxx-8000.proxy.runpod.net/docs`

## 5. iPhone / Flutter 앱 연결

1. 앱 **마이** 탭 → API 서버 설정
2. RunPod URL 입력 (끝 `/` 없이):
   ```
   https://xxxxxxxx-8000.proxy.runpod.net
   ```
3. **저장 · 연결 확인**
4. 홈 → 사진 → 스타일(고윤정/신세경/홍수주) → 적용

또는 빌드 시 고정:

```bash
cd celebfit_app
flutter run --dart-define=API_BASE_URL=https://xxxxxxxx-8000.proxy.runpod.net
```

## 6. 비용 관리

| 팁 | 설명 |
|----|------|
| **Pod Stop** | 데모 끝나면 반드시 중지 |
| **Network Volume** | `/data`에 HF 캐시 → 재시작 시 재다운로드 생략 |
| **WARMUP_ON_START=false** | 빠른 기동, 첫 `/apply`만 느림 |

예상: RTX 3090 ~$0.2–0.4/시간

## 7. 문제 해결

| 증상 | 해결 |
|------|------|
| Warmup 10분+ | epiCRealism(~4GB) 첫 다운로드 — 정상 |
| OOM | 더 큰 VRAM GPU 또는 동시 요청 1건 (기본 적용됨) |
| 앱 연결 실패 | `https://` 사용, RunPod Pod Running 상태 확인 |
| `fallback` 엔진 | `ENABLE_SD=true`, GPU Pod인지 확인 |

## 8. GitHub Actions로 이미지 빌드 (Mac 디스크 없을 때)

`.github/workflows/docker.yml` — push 시 Docker Hub 자동 빌드 (선택).

Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
