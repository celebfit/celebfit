#!/usr/bin/env bash
# RunPod Start Command:
#   bash -c 'curl -fsSL https://raw.githubusercontent.com/celebfit/celebfit/app/deploy/runpod_start.sh | bash'
#
# 컨테이너가 바로 죽지 않도록 실패 시에도 sleep 유지 (Web Terminal 디버그용)
set -uo pipefail

REPO="${REPO_DIR:-/data/celebfit}"
export APP_ROOT="$REPO"
export MODEL_REPO_ROOT="$REPO"
export PYTHONPATH="$REPO"
export HF_HOME="${HF_HOME:-/data/huggingface}"
export TORCH_HOME="${TORCH_HOME:-/data/torch}"
export ENABLE_SD="${ENABLE_SD:-true}"
export USE_GITHUB_PIPELINE="${USE_GITHUB_PIPELINE:-true}"
export ALLOW_FALLBACK="${ALLOW_FALLBACK:-false}"
export WARMUP_ON_START="${WARMUP_ON_START:-true}"
export API_PORT="${API_PORT:-8000}"
# 베이스 이미지가 HF_HUB_ENABLE_HF_TRANSFER=1을 기본으로 켜두는데 hf_transfer 패키지는 없어서 다운로드가 죽음
export HF_HUB_ENABLE_HF_TRANSFER=0

keep_alive() {
  echo "=== celebfit boot failed — container kept alive for debugging ==="
  echo "Web Terminal: cd $REPO && bash deploy/entrypoint.sh"
  tail -f /dev/null
}

trap keep_alive ERR

mkdir -p "$HF_HOME" "$TORCH_HOME"

if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    libglib2.0-0 libgomp1 libsm6 libxext6 libxrender1 libgl1 git curl >/dev/null
fi

rm -rf "$REPO"
git clone --depth 1 --branch app https://github.com/celebfit/celebfit.git "$REPO"
cd "$REPO"

mkdir -p masking_bisenet/face-parsing/weights
if [[ ! -s masking_bisenet/face-parsing/weights/resnet18.onnx ]]; then
  curl -fsSL -o masking_bisenet/face-parsing/weights/resnet18.onnx \
    https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx
fi

export PIP_BREAK_SYSTEM_PACKAGES=1
pip uninstall -y --break-system-packages onnxruntime-gpu onnxruntime onnxruntime-training 2>/dev/null || true
grep -v '^onnxruntime' api/requirements-docker.txt | pip install -q --no-cache-dir --break-system-packages --ignore-installed -r /dev/stdin
pip install -q --no-cache-dir --break-system-packages --ignore-installed "mediapipe==0.10.14" "onnxruntime==1.19.2"

cat > api/diffusers_onnx_patch.py << 'PYEOF'
from __future__ import annotations
import sys
import types

def apply_diffusers_onnx_patch() -> None:
    if getattr(apply_diffusers_onnx_patch, "_done", False):
        return
    try:
        import diffusers.utils.import_utils as iu
        iu._onnx_available = False
        iu.is_onnx_available = lambda: False
    except ImportError:
        pass
    name = "diffusers.pipelines.onnx_utils"
    if name not in sys.modules:
        stub = types.ModuleType(name)
        class OnnxRuntimeModel:
            pass
        stub.OnnxRuntimeModel = OnnxRuntimeModel
        sys.modules[name] = stub
    apply_diffusers_onnx_patch._done = True
PYEOF

python3 << 'PY'
from pathlib import Path

p = Path("api/services/pipeline.py")
t = p.read_text()
if "apply_diffusers_onnx_patch" not in t:
    p.write_text(t.replace(
        "from __future__ import annotations\n\nimport logging",
        "from __future__ import annotations\n\nfrom api.diffusers_onnx_patch import apply_diffusers_onnx_patch\n\napply_diffusers_onnx_patch()\n\nimport logging",
    ))

e = Path("deploy/entrypoint.sh")
t = e.read_text()
t = t.replace("/app", "/data/celebfit")
if "apply_diffusers_onnx_patch" not in t:
    t = t.replace(
        "from api.config import get_settings",
        "from api.diffusers_onnx_patch import apply_diffusers_onnx_patch\napply_diffusers_onnx_patch()\nfrom api.config import get_settings",
    )
e.write_text(t)
PY

python3 -c "
from api.diffusers_onnx_patch import apply_diffusers_onnx_patch
apply_diffusers_onnx_patch()
import onnxruntime as ort
from diffusers import StableDiffusionInpaintPipeline
print('onnxruntime', ort.__version__, ort.get_available_providers())
print('diffusers OK')
"

trap - ERR
exec bash deploy/entrypoint.sh
