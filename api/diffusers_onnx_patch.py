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

        class OnnxRuntimeModel:  # noqa: D101 - diffusers stub
            pass

        stub.OnnxRuntimeModel = OnnxRuntimeModel
        sys.modules[name] = stub

    apply_diffusers_onnx_patch._done = True  # type: ignore[attr-defined]
