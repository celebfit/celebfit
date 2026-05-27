#!/usr/bin/env bash
# celebfit 앱 UI 미리보기 (브라우저) + RunPod API 연동
# Usage:
#   ./scripts/open_app_preview.sh
#   ./scripts/open_app_preview.sh https://YOUR_POD_ID-8000.proxy.runpod.net
#   PREVIEW_BIND=0.0.0.0 ./scripts/open_app_preview.sh   # 같은 Wi-Fi 공유
#   ./scripts/share_app_preview.sh --public                # 인터넷 공개 URL
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$ROOT/celebfit_app"
PREVIEW_PAGE="preview/index.html"
API_URL="${1:-}"
PORT="${PREVIEW_PORT:-8765}"
BIND="${PREVIEW_BIND:-127.0.0.1}"
PID_FILE="/tmp/celebfit-preview-${PORT}.pid"
LOG_FILE="/tmp/celebfit-preview.log"

if [[ ! -f "$APP_ROOT/$PREVIEW_PAGE" ]]; then
  echo "Preview not found: $APP_ROOT/$PREVIEW_PAGE" >&2
  exit 1
fi

stop_preview() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 0.5
    fi
    rm -f "$PID_FILE"
  fi
  local stale
  stale="$(lsof -ti tcp:"$PORT" 2>/dev/null || true)"
  if [[ -n "$stale" ]]; then
    kill $stale 2>/dev/null || true
    sleep 0.5
  fi
}

health_check() {
  curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/${PREVIEW_PAGE}" >/dev/null 2>&1
}

start_preview() {
  if health_check; then
    return 0
  fi
  stop_preview
  echo "Starting preview server on http://${BIND}:${PORT}"
  (
    cd "$APP_ROOT"
    exec python3 -m http.server "$PORT" --bind "$BIND"
  ) >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  for _ in $(seq 1 20); do
    if health_check; then
      return 0
    fi
    sleep 0.25
  done
  echo "Preview server failed to start. Log:" >&2
  tail -20 "$LOG_FILE" >&2 || true
  exit 1
}

start_preview

QUERY=""
if [[ -n "$API_URL" ]]; then
  API_URL="${API_URL%/}"
  QUERY="?api=${API_URL}"
fi

OPEN_URL="http://127.0.0.1:${PORT}/${PREVIEW_PAGE}${QUERY}"
echo "Open: $OPEN_URL"
open "$OPEN_URL" 2>/dev/null || xdg-open "$OPEN_URL" 2>/dev/null || true

cat <<EOF

=== celebfit 앱 미리보기 ===
URL: $OPEN_URL

1. 상단 배너 → "연결됨" 확인 (아니면 MY 탭에서 RunPod URL 저장)
2. 홈 → 사진 업로드
3. 스타일 → 고윤정 / 신세경 / 홍수주 → 적용
4. 결과 → Before/After

팀·핸드폰 공유: ./scripts/share_app_preview.sh
GitHub Pages: https://celebfit.github.io/celebfit/preview/index.html
EOF
