#!/usr/bin/env bash
# RunPod: onnxruntime-gpu(CUDA13) 제거 후 CPU onnxruntime 설치
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/scripts/runpod_fix_onnx.sh"
