#!/usr/bin/env bash
# RunPod Pod에서 libcudart.so.13 오류 일괄 수정 (GitHub push 없이 Pod에서 직접 실행)
set -euo pipefail
cd "${REPO_DIR:-/workspace/celebfit}"

echo "==> 1/4 onnxruntime-gpu 제거, CPU 버전 설치"
pip uninstall -y onnxruntime-gpu onnxruntime onnxruntime-training 2>/dev/null || true
pip install --no-cache-dir --force-reinstall "onnxruntime==1.19.2"

echo "==> 2/4 diffusers onnx 패치 파일 추가"
cat > api/diffusers_onnx_patch.py << 'PYEOF'
"""RunPod CUDA12: block diffusers from loading onnxruntime-gpu."""
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

echo "==> 3/4 pipeline.py / entrypoint.sh 패치"
python3 << 'PY'
from pathlib import Path

# pipeline.py
p = Path("api/services/pipeline.py")
t = p.read_text()
if "apply_diffusers_onnx_patch" not in t:
    t = t.replace(
        "from __future__ import annotations\n\nimport logging",
        "from __future__ import annotations\n\nfrom api.diffusers_onnx_patch import apply_diffusers_onnx_patch\n\napply_diffusers_onnx_patch()\n\nimport logging",
    )
    p.write_text(t)
    print("patched api/services/pipeline.py")

# entrypoint.sh
e = Path("deploy/entrypoint.sh")
t = e.read_text()
needle = 'from api.config import get_settings'
insert = 'from api.diffusers_onnx_patch import apply_diffusers_onnx_patch\napply_diffusers_onnx_patch()\nfrom api.config import get_settings'
if "apply_diffusers_onnx_patch" not in t:
    t = t.replace(needle, insert)
    e.write_text(t)
    print("patched deploy/entrypoint.sh")

# pipeline/main.py
m = Path("pipeline/main.py")
t = m.read_text()
if "_onnx_available = False" not in t:
    old = "from util.crop_face import get_zoom_crop_info, apply_crop, restore_crop\n"
    new = old + (
        "\ntry:\n"
        "    import diffusers.utils.import_utils as _du_iu\n"
        "    _du_iu._onnx_available = False\n"
        "except ImportError:\n"
        "    pass\n\n"
    )
    t = t.replace(old, new)
    m.write_text(t)
    print("patched pipeline/main.py")
PY

echo "==> 4/4 검증 후 API 재시작"
python3 -c "
from api.diffusers_onnx_patch import apply_diffusers_onnx_patch
apply_diffusers_onnx_patch()
from diffusers import StableDiffusionInpaintPipeline
print('diffusers import OK')
"

pkill -f uvicorn || true
bash deploy/entrypoint.sh
