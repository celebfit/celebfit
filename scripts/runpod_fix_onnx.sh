#!/usr/bin/env bash
# RunPod Pod에서 libcudart.so.13 / onnxruntime 충돌 수정
set -euo pipefail

echo "==> Removing all onnxruntime variants..."
pip uninstall -y \
  onnxruntime-gpu onnxruntime onnxruntime-training \
  onnxruntime-directml onnxruntime-openvino onnxruntime-rocm \
  2>/dev/null || true

echo "==> Installing CPU-only onnxruntime 1.19.2..."
pip install --no-cache-dir --force-reinstall "onnxruntime==1.19.2"

echo "==> Verify onnxruntime..."
python3 - <<'PY'
import onnxruntime as ort
providers = ort.get_available_providers()
print("onnxruntime:", ort.__version__)
print("providers:", providers)
if "CUDAExecutionProvider" in providers:
    raise SystemExit("ERROR: CUDA provider still present — onnxruntime-gpu not fully removed")
from diffusers.pipelines import onnx_utils  # noqa: F401
print("diffusers onnx_utils: OK")
PY

echo "==> Done. Restart API:"
echo "    cd /workspace/celebfit && pkill -f uvicorn || true && bash deploy/entrypoint.sh"
