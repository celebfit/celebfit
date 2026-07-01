#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/workspace/celebfit}"
APP_ROOT="${APP_ROOT:-${MODEL_REPO_ROOT:-$REPO_DIR}}"

if [[ ! -d "$APP_ROOT" ]]; then
  echo "ERROR: celebfit repo not found at $APP_ROOT" >&2
  echo "Run bootstrap first or set APP_ROOT=/workspace/celebfit" >&2
  exit 1
fi

cd "$APP_ROOT"

export PYTHONPATH="$APP_ROOT"
export MODEL_REPO_ROOT="${MODEL_REPO_ROOT:-$APP_ROOT}"
export HF_HOME="${HF_HOME:-/data/huggingface}"
export TORCH_HOME="${TORCH_HOME:-/data/torch}"
export ENABLE_SD="${ENABLE_SD:-true}"
export USE_GITHUB_PIPELINE="${USE_GITHUB_PIPELINE:-true}"
export ALLOW_FALLBACK="${ALLOW_FALLBACK:-false}"

mkdir -p "$HF_HOME" "$TORCH_HOME" "$APP_ROOT/weights"

if [[ "${WARMUP_ON_START:-true}" == "true" ]]; then
  echo "Warming up SD pipeline (first boot may take 10-20 min)..."
  python - <<'PY' || echo "Warmup skipped or failed — models load on first /apply"
try:
    from api.diffusers_onnx_patch import apply_diffusers_onnx_patch
    apply_diffusers_onnx_patch()
except ImportError:
    pass
from api.config import get_settings
from api.services.pipeline import get_pipeline

settings = get_settings()
pipeline = get_pipeline(settings)
pipeline.initialize()
print("Warmup OK:", pipeline.status_message)
PY
fi

echo "Starting celebfit API on 0.0.0.0:${API_PORT:-8000}"
exec python -m uvicorn api.main:app --host 0.0.0.0 --port "${API_PORT:-8000}"
