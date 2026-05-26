#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
fi
source .venv/bin/activate

pip install -q -r api/requirements.txt || {
  echo "⚠️  일부 패키지 설치 실패 — numpy/diffusers 버전 충돌 시 아래 실행:"
  echo "   pip install 'numpy>=1.26,<2' 'diffusers>=0.31,<0.35' 'transformers>=4.46,<5'"
}

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — ENABLE_SD=true 로 설정되어 있는지 확인하세요."
fi

set -a
source .env
set +a

export PYTHONPATH="$ROOT"
export ENABLE_SD="${ENABLE_SD:-true}"
export USE_GITHUB_PIPELINE="${USE_GITHUB_PIPELINE:-true}"
export SSL_CERT_FILE="$(python -c 'import certifi; print(certifi.where())')"
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"

if [[ ! -d "${MODEL_REPO_ROOT:-$ROOT/../ConditionalImageGeneration}" ]]; then
  echo "⚠️  ConditionalImageGeneration 저장소가 없습니다."
  echo "   git clone https://github.com/jiucai233/ConditionalImageGeneration.git ../ConditionalImageGeneration"
fi

LOCAL_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "YOUR_MAC_IP")"

echo ""
echo "=========================================="
echo " celebfit API (SD + GitHub pipeline)"
echo " Mac IP (iPhone 설정용): http://${LOCAL_IP}:${API_PORT:-8000}"
echo " Swagger 테스트: http://127.0.0.1:${API_PORT:-8000}/docs"
echo "=========================================="
echo ""

exec python -m uvicorn api.main:app --host 0.0.0.0 --port "${API_PORT:-8000}"
