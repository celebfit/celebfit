#!/usr/bin/env bash
# RunPod Pod "Start Command" — Docker 이미지 없이 GPU에서 바로 API 실행
set -euo pipefail

REPO_DIR="${REPO_DIR:-/workspace/celebfit}"
BRANCH="${BRANCH:-app}"
REPO_URL="${REPO_URL:-https://github.com/celebfit/celebfit.git}"

export APP_ROOT="$REPO_DIR"
export PYTHONPATH="$REPO_DIR"
export MODEL_REPO_ROOT="$REPO_DIR"
export HF_HOME="${HF_HOME:-/data/huggingface}"
export TORCH_HOME="${TORCH_HOME:-/data/torch}"
export ENABLE_SD="${ENABLE_SD:-true}"
export USE_GITHUB_PIPELINE="${USE_GITHUB_PIPELINE:-true}"
export ALLOW_FALLBACK="${ALLOW_FALLBACK:-false}"
export WARMUP_ON_START="${WARMUP_ON_START:-true}"
export API_PORT="${API_PORT:-8000}"

mkdir -p "$HF_HOME" "$TORCH_HOME"

if command -v apt-get >/dev/null 2>&1; then
  echo "Installing system libraries for MediaPipe / OpenCV..."
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    libglib2.0-0 libgomp1 libsm6 libxext6 libxrender1 libgl1 >/dev/null
fi

sync_repo() {
  if [[ -d "$REPO_DIR/.git" ]]; then
    echo "Updating existing repo at $REPO_DIR..."
    set +e
    git -C "$REPO_DIR" fetch --depth 1 origin "$BRANCH"
    fetch_status=$?
    git -C "$REPO_DIR" checkout "$BRANCH"
    checkout_status=$?
    git -C "$REPO_DIR" reset --hard "origin/$BRANCH"
    reset_status=$?
    set -e
    if [[ $fetch_status -eq 0 && $checkout_status -eq 0 && $reset_status -eq 0 ]]; then
      return 0
    fi
    echo "Repo update failed (stale shallow clone). Re-cloning..."
    rm -rf "$REPO_DIR"
  elif [[ -e "$REPO_DIR" ]]; then
    echo "Removing incomplete repo at $REPO_DIR..."
    rm -rf "$REPO_DIR"
  fi

  echo "Cloning $REPO_URL (branch $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
}

fix_onnx_cuda13() {
  echo "Fixing onnxruntime / diffusers CUDA13 conflict (RunPod CUDA12)..."

  pip uninstall -y \
    onnxruntime-gpu onnxruntime onnxruntime-training \
    onnxruntime-directml onnxruntime-openvino onnxruntime-rocm \
    2>/dev/null || true

  # Remove broken GPU wheel leftovers
  python3 - <<'PY'
import glob
import shutil
for pattern in (
    "/usr/local/lib/python*/dist-packages/onnxruntime*",
    "/usr/local/lib/python*/site-packages/onnxruntime*",
):
    for path in glob.glob(pattern):
        print("Removing", path)
        shutil.rmtree(path, ignore_errors=True)
PY

  echo "Installing Python dependencies (without onnxruntime-gpu)..."
  grep -v '^onnxruntime' api/requirements-docker.txt | pip install -q --no-cache-dir -r /dev/stdin
  pip install -q --no-cache-dir --force-reinstall "mediapipe==0.10.14"
  pip install -q --no-cache-dir --force-reinstall "onnxruntime==1.19.2"

  # Patch files (git reset wipes manual edits — re-apply every boot)
  cat > api/diffusers_onnx_patch.py << 'PYEOF'
"""RunPod CUDA12: block diffusers from loading onnxruntime-gpu (needs libcudart.so.13)."""
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

  python3 - <<'PY'
from pathlib import Path

def ensure_after(path: Path, needle: str, block: str, label: str) -> None:
    text = path.read_text()
    if block.strip() in text:
        return
    if needle not in text:
        raise SystemExit(f"Cannot patch {label}: needle not found")
    path.write_text(text.replace(needle, block))
    print(f"patched {label}")

ensure_after(
    Path("api/services/pipeline.py"),
    "from __future__ import annotations\n\nimport logging",
    "from __future__ import annotations\n\nfrom api.diffusers_onnx_patch import apply_diffusers_onnx_patch\n\napply_diffusers_onnx_patch()\n\nimport logging",
    "api/services/pipeline.py",
)
ensure_after(
    Path("deploy/entrypoint.sh"),
    "from api.config import get_settings",
    "from api.diffusers_onnx_patch import apply_diffusers_onnx_patch\napply_diffusers_onnx_patch()\nfrom api.config import get_settings",
    "deploy/entrypoint.sh",
)
ensure_after(
    Path("api/main.py"),
    "configure_ssl()\n",
    "configure_ssl()\n\nfrom api.diffusers_onnx_patch import apply_diffusers_onnx_patch\n\napply_diffusers_onnx_patch()\n",
    "api/main.py",
)
PY

  python3 - <<'PY'
from api.diffusers_onnx_patch import apply_diffusers_onnx_patch
apply_diffusers_onnx_patch()
import onnxruntime as ort
from diffusers import StableDiffusionInpaintPipeline
print("onnxruntime", ort.__version__, ort.get_available_providers())
print("diffusers import OK")
PY
}

sync_repo

cd "$REPO_DIR"
mkdir -p "$REPO_DIR/weights"

if [[ ! -f masking_bisenet/face-parsing/weights/resnet18.onnx ]]; then
  echo "Downloading BiSeNet ONNX..."
  mkdir -p masking_bisenet/face-parsing/weights
  curl -fsSL -o masking_bisenet/face-parsing/weights/resnet18.onnx \
    https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx
fi

fix_onnx_cuda13

exec bash deploy/entrypoint.sh
