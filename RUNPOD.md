# RunPod GPU 시연 가이드 — celebfit

팀원이 **본인 RunPod 계정**에서 [celebfit/celebfit](https://github.com/celebfit/celebfit) `app` 브랜치를 GPU에 올려 시연하는 방법입니다.

---

## 전체 구조

```
GitHub (app)  →  RunPod GPU Pod  →  FastAPI :8000  →  GitHub Pages 미리보기
```

| 구성요소 | 역할 |
|----------|------|
| GitHub `app` | 코드 + LoRA + API |
| RunPod Pod | GPU에서 AI 추론 |
| GitHub Pages | 브라우저 UI (별도 설치 불필요) |

**시연 URL 예:**

```
https://celebfit.github.io/celebfit/preview/index.html?api=https://YOUR_POD_ID-8000.proxy.runpod.net
```

---

## 사전 준비

| 항목 | 내용 |
|------|------|
| RunPod 계정 | [runpod.io](https://www.runpod.io) 가입 |
| 크레딧 | **$5~10 이상** (4090 기준 ~$0.69/시간) |
| GitHub | Public repo — `git clone`만 하면 됨 |

---

## 1단계 — Pod 만들기

[Deploy](https://console.runpod.io/deploy) → GPU 선택:

| 항목 | 값 |
|------|-----|
| GPU | **RTX 4090** (24GB) |
| Template | UI에서 **RunPod PyTorch** 선택, 또는 아래 Image Tag |
| Container Disk | **40 GB** |
| Storage | **Volume disk** 50GB → mount **`/data`** |
| HTTP Port | **`8000`** |

**Container Image Tag (직접 입력 시 전체 태그):**

```
runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
```

> `2.4.0-py3.11-cuda12.4.1` 만 입력하면 **not found** 오류가 납니다. `-devel-ubuntu22.04`까지 포함하세요.

**Environment Variables:**

```
ENABLE_SD=true
USE_GITHUB_PIPELINE=true
ALLOW_FALLBACK=false
WARMUP_ON_START=true
HF_HOME=/data/huggingface
TORCH_HOME=/data/torch
```

**Start Command** (crash loop 방지 — **이 한 줄만**):

```bash
bash -c 'tail -f /dev/null'
```

→ **Deploy On-Demand** → **Running** 확인

---

## 2단계 — API 설치 (Web Terminal)

Pod → **Connect** → **Start Web Terminal**

### 방법 A — 설치 스크립트 (권장)

`app` 브랜치 push 후 아래 한 줄:

```bash
bash -c 'curl -fsSL https://raw.githubusercontent.com/celebfit/celebfit/app/deploy/runpod_start.sh | bash'
```

> Start Command는 `tail -f /dev/null` 유지. Web Terminal에서 위 명령 실행.

### 방법 B — 수동 설치 (스크립트 없을 때)

Web Terminal에 **전체** 붙여넣기:

```bash
REPO=/data/celebfit
export APP_ROOT=$REPO MODEL_REPO_ROOT=$REPO PYTHONPATH=$REPO
export HF_HOME=/data/huggingface TORCH_HOME=/data/torch
export ENABLE_SD=true USE_GITHUB_PIPELINE=true ALLOW_FALLBACK=false API_PORT=8000 WARMUP_ON_START=true
mkdir -p $HF_HOME $TORCH_HOME

git clone --depth 1 --branch app https://github.com/celebfit/celebfit.git $REPO
cd $REPO

apt-get update -qq && apt-get install -y -qq libglib2.0-0 libgomp1 libsm6 libxext6 libxrender1 libgl1 git
mkdir -p masking_bisenet/face-parsing/weights
curl -fsSL -o masking_bisenet/face-parsing/weights/resnet18.onnx \
  https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx

pip uninstall -y onnxruntime-gpu onnxruntime 2>/dev/null || true
grep -v onnxruntime api/requirements-docker.txt | pip install -q -r /dev/stdin
pip install -q mediapipe==0.10.14 onnxruntime==1.19.2

python3 -c "open('api/diffusers_onnx_patch.py','w').write('from __future__ import annotations\nimport sys,types\ndef apply_diffusers_onnx_patch():\n if getattr(apply_diffusers_onnx_patch,\"_done\",False): return\n try:\n  import diffusers.utils.import_utils as iu\n  iu._onnx_available=False\n  iu.is_onnx_available=lambda:False\n except ImportError: pass\n n=\"diffusers.pipelines.onnx_utils\"\n if n not in sys.modules:\n  s=types.ModuleType(n)\n  class OnnxRuntimeModel: pass\n  s.OnnxRuntimeModel=OnnxRuntimeModel\n  sys.modules[n]=s\n apply_diffusers_onnx_patch._done=True\n')"

python3 << 'PY'
from pathlib import Path
p=Path("api/services/pipeline.py"); t=p.read_text()
if "apply_diffusers_onnx_patch" not in t:
 p.write_text(t.replace("from __future__ import annotations\n\nimport logging",
 "from __future__ import annotations\n\nfrom api.diffusers_onnx_patch import apply_diffusers_onnx_patch\napply_diffusers_onnx_patch()\n\nimport logging"))
e=Path("deploy/entrypoint.sh"); t=e.read_text().replace("/app","/data/celebfit")
if "apply_diffusers_onnx_patch" not in t:
 t=t.replace("from api.config import get_settings",
 "from api.diffusers_onnx_patch import apply_diffusers_onnx_patch\napply_diffusers_onnx_patch()\nfrom api.config import get_settings")
e.write_text(t)
print("patched OK")
PY

nohup bash deploy/entrypoint.sh > /data/celebfit-api.log 2>&1 &
tail -f /data/celebfit-api.log
```

### 성공 기준 (10~20분)

```
patched OK
Warmup OK: sd_inpaint ready (cuda)
Uvicorn running on http://0.0.0.0:8000
```

로그 확인 (터미널 끊긴 후):

```bash
tail -30 /data/celebfit-api.log
```

---

## 3단계 — Pod URL 확인

Pod → **Connect** → Port **8000**:

```
https://YOUR_POD_ID-8000.proxy.runpod.net
```

```bash
curl -s https://YOUR_POD_ID-8000.proxy.runpod.net/health
```

Mac에서 전체 검증:

```bash
./scripts/verify_runpod_api.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

---

## 4단계 — 브라우저 시연

### GitHub Pages (발표·핸드폰, 권장)

```
https://celebfit.github.io/celebfit/preview/index.html?api=https://YOUR_POD_ID-8000.proxy.runpod.net
```

### 로컬 미리보기

```bash
git clone -b app https://github.com/celebfit/celebfit.git
cd celebfit
./scripts/open_app_preview.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

### 사용 순서

1. 상단 **연결됨** 확인
2. **홈** → 사진 업로드
3. **스타일** → 연예인 선택 → **적용하기**
4. **결과** → Before/After (1회 8~15초)

---

## 5단계 — 시연 후

| 할 일 | 이유 |
|--------|------|
| Pod **Terminate(삭제)** | GPU + Volume Storage 과금 중지 |
| Stop만 하지 않기 | Volume disk 과금 계속 (~$0.6/일) |

---

## Pod 재시작 (같은 Pod, `/data` 유지)

Web Terminal:

```bash
cd /data/celebfit
export APP_ROOT=/data/celebfit MODEL_REPO_ROOT=/data/celebfit PYTHONPATH=/data/celebfit
export HF_HOME=/data/huggingface TORCH_HOME=/data/torch
export ENABLE_SD=true USE_GITHUB_PIPELINE=true ALLOW_FALLBACK=false API_PORT=8000
nohup bash deploy/entrypoint.sh > /data/celebfit-api.log 2>&1 &
```

모델 캐시가 `/data`에 남아 있으면 warm-up이 더 빠릅니다.

---

## 문제 해결

| 즹상 | 해결 |
|------|------|
| Image **not found** | Tag 전체: `2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04` |
| `stop/remove/create` 반복 | Start Command = `tail -f /dev/null` 만 |
| `libcudart.so.13` | `onnxruntime==1.19.2` + diffusers 패치 (2단계) |
| `/data/celebfit` 없음 | 2단계 `git clone` 실행 |
| 상단 **미연결** | `?api=https://...-8000.proxy.runpod.net` (끝 `/` 없이) |
| Web Terminal Ctrl+C 안 됨 | `"` + Enter 또는 터미널 닫고 재접속 |
| 크레딧 빠르게 소진 | Pod **Terminate**, Network volume 만들지 않기 |

---

## 비용 참고

| 항목 | 내용 |
|------|------|
| RTX 4090 | ~$0.69/시간 |
| 첫 warm-up | epiCRealism 다운로드 10~20분 |
| 1회 `/apply` | GPU 8~15초 |

---

## 한 줄 요약

> RunPod 4090 Pod + Start Command `tail -f /dev/null` + Web Terminal에서 `deploy/runpod_start.sh` 실행 →  
> `https://celebfit.github.io/celebfit/preview/index.html?api=본인PodURL` 로 시연.
