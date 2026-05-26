#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
source .venv/bin/activate

MODE="${1:-core}"

if [[ "$MODE" == "core" ]]; then
  pip install -q -r api/requirements-core.txt
elif [[ "$MODE" == "gpu" ]]; then
  pip install -q -r api/requirements-core.txt
  pip install -q -r api/requirements-gpu.txt
else
  pip install -q -r api/requirements.txt
fi

export PYTHONPATH="$ROOT"
export ENABLE_SD="${ENABLE_SD:-false}"

echo "Starting celebfit API (ENABLE_SD=$ENABLE_SD)..."
exec python -m uvicorn api.main:app --host 0.0.0.0 --port "${API_PORT:-8000}"
