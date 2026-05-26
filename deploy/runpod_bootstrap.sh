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

if [[ -d "$REPO_DIR/.git" ]]; then
  echo "Updating existing repo at $REPO_DIR..."
  git -C "$REPO_DIR" fetch --depth 1 origin "$BRANCH"
  git -C "$REPO_DIR" checkout "$BRANCH"
  git -C "$REPO_DIR" reset --hard "origin/$BRANCH"
elif [[ -e "$REPO_DIR" ]]; then
  echo "Removing incomplete repo at $REPO_DIR..."
  rm -rf "$REPO_DIR"
  echo "Cloning $REPO_URL (branch $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
else
  echo "Cloning $REPO_URL (branch $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
mkdir -p "$REPO_DIR/weights"

if [[ ! -f masking_bisenet/face-parsing/weights/resnet18.onnx ]]; then
  echo "Downloading BiSeNet ONNX..."
  mkdir -p masking_bisenet/face-parsing/weights
  curl -fsSL -o masking_bisenet/face-parsing/weights/resnet18.onnx \
    https://github.com/yakhyo/face-parsing/releases/download/weights/resnet18.onnx
fi

echo "Installing Python dependencies..."
pip install -q --no-cache-dir -r api/requirements-docker.txt

exec bash deploy/entrypoint.sh
