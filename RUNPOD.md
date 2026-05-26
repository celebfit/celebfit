# RunPod GPU 배포 — celebfit API

팀 repo: [github.com/celebfit/celebfit](https://github.com/celebfit/celebfit) · branch **`app`**

---

## 빠른 시작 (Docker Hub 없이, 추천)

### 1. RunPod Pod 생성

1. [runpod.io](https://www.runpod.io) → **Pods** → **+ Deploy**
2. GPU: **RTX 3090 / 4090** (24GB VRAM)
3. Template: **RunPod PyTorch 2.2** (또는 CUDA 12.1 PyTorch)
4. **Edit Template** / 설정:

| 항목 | 값 |
|------|-----|
| Container Disk | **40 GB** |
| Volume Disk | **50 GB** (선택, 캐시용) |
| Volume Mount | `/data` |
| **Expose HTTP Ports** | `8000` |
| **Start Command** | 아래 한 줄 전체 붙여넣기 |

**Start Command:**

```bash
bash -c 'curl -fsSL https://raw.githubusercontent.com/celebfit/celebfit/app/deploy/runpod_bootstrap.sh | bash'
```

5. **Environment Variables:**

```
ENABLE_SD=true
USE_GITHUB_PIPELINE=true
ALLOW_FALLBACK=false
WARMUP_ON_START=true
HF_HOME=/data/huggingface
TORCH_HOME=/data/torch
```

6. **Deploy** → 상태 **Running** + Telemetry GPU 사용 확인

### 2. URL 확인

Pod → **Connect** → Port **8000**:

```
https://YOUR_POD_ID-8000.proxy.runpod.net
```

### 3. 동작 확인 (Mac 터미널)

```bash
cd ~/Downloads/celebfit   # 또는 ConditionalImageGeneration
chmod +x scripts/verify_runpod_api.sh
./scripts/verify_runpod_api.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

사진으로 실제 변환 테스트:

```bash
./scripts/verify_runpod_api.sh https://YOUR_POD_ID-8000.proxy.runpod.net ./test_face.jpg
```

성공 기준:
- `/health` → `"status": "ok"` 또는 warm-up 중 `"ready (models load on first apply)"`
- `/api/v1/warmup` → `"engine": "github_sd_inpaint"` (또는 `"sd_inpaint"`)
- `/api/v1/apply` → `"engine": "github_sd_inpaint"`, `after_image_bytes` > 10000

Swagger: `https://YOUR_POD_ID-8000.proxy.runpod.net/docs`

### 4. iPhone / Flutter 앱

**마이** 탭 → API URL:

```
https://YOUR_POD_ID-8000.proxy.runpod.net
```

---

## Docker 이미지 방식 (선택)

`app` 브랜치 `Dockerfile`로 빌드 후 RunPod **Container Image**에 등록.

```bash
docker build -t YOUR_DOCKERHUB/celebfit-api:latest .
docker push YOUR_DOCKERHUB/celebfit-api:latest
```

RunPod Container Image: `YOUR_DOCKERHUB/celebfit-api:latest`  
Port: `8000` · Env: 위와 동일

---

## 비용 · 주의

| 항목 | 내용 |
|------|------|
| 첫 warm-up | epiCRealism ~4GB 다운로드 → **10~20분** |
| 1회 `/apply` | GPU 기준 **8~15초** (warm-up 후) |
| HTTP proxy | **100초** 타임아웃 — warm-up은 Pod 로그에서 확인 |
| 비용 | ~$0.2–0.4/시간 · **테스트 후 Pod Stop** |

---

## 문제 해결

| 증상 | 해결 |
|------|------|
| Pod Exited | Logs 탭 — OOM이면 4090, disk 40GB+ |
| `fallback` | `ENABLE_SD=true` 확인 |
| warm-up 524 | proxy 100초 제한 — Pod **Logs**에서 "Warmup OK" 확인 후 `/apply` |
| clone 실패 | repo Public 또는 RunPod에 GitHub access |
