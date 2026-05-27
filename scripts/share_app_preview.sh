#!/usr/bin/env bash
# celebfit 미리보기를 팀·핸드폰과 공유
#
# Usage:
#   ./scripts/share_app_preview.sh                          # 같은 Wi-Fi (LAN)
#   ./scripts/share_app_preview.sh https://POD-8000.proxy.runpod.net
#   ./scripts/share_app_preview.sh --public                 # Cloudflare 임시 HTTPS URL
#   ./scripts/share_app_preview.sh --public https://POD...  # 공개 URL + RunPod API
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PREVIEW_PORT:-8765}"
PUBLIC=0
API_URL=""

for arg in "$@"; do
  case "$arg" in
    --public) PUBLIC=1 ;;
    http*) API_URL="$arg" ;;
  esac
done

PREVIEW_BIND=0.0.0.0 "$ROOT/scripts/open_app_preview.sh" ${API_URL:+"$API_URL"}

LAN_IP=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
else
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi

PAGE="preview/index.html"
QUERY=""
if [[ -n "$API_URL" ]]; then
  QUERY="?api=${API_URL%/}"
fi

echo ""
echo "=== 공유 URL ==="
if [[ -n "$LAN_IP" ]]; then
  echo "같은 Wi-Fi (핸드폰): http://${LAN_IP}:${PORT}/${PAGE}${QUERY}"
else
  echo "같은 Wi-Fi: http://<내_Mac_IP>:${PORT}/${PAGE}${QUERY}"
  echo "  Mac IP 확인: ipconfig getifaddr en0"
fi
echo "GitHub Pages (push 후): https://celebfit.github.io/celebfit/${PAGE}${QUERY}"

if [[ "$PUBLIC" -eq 1 ]]; then
  if command -v cloudflared >/dev/null 2>&1; then
    echo ""
    echo "공개 HTTPS 터널 시작 중 (Ctrl+C 종료)..."
    cloudflared tunnel --url "http://127.0.0.1:${PORT}"
  else
    echo ""
    echo "cloudflared 미설치 → brew install cloudflared 후 --public 다시 실행"
    echo "또는 GitHub Pages 사용 (app push → Actions → Pages)"
  fi
fi
