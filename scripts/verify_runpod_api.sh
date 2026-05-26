#!/usr/bin/env bash
# RunPod API 동작 확인
# Usage: ./scripts/verify_runpod_api.sh https://POD_ID-8000.proxy.runpod.net [test_image.jpg]
set -euo pipefail

BASE_URL="${1:?Usage: $0 <runpod-base-url> [image.jpg]}"
BASE_URL="${BASE_URL%/}"
IMAGE="${2:-}"

echo "==> Health"
curl -fsS "$BASE_URL/health" | python3 -m json.tool

echo ""
echo "==> Warmup (may take several minutes on first run)"
curl -fsS -X POST "$BASE_URL/api/v1/warmup" | python3 -m json.tool

echo ""
echo "==> Styles"
curl -fsS "$BASE_URL/api/v1/styles" | python3 -m json.tool | head -20

if [[ -n "$IMAGE" && -f "$IMAGE" ]]; then
  echo ""
  echo "==> Apply (go_yoonjung) — may take 15-60s"
  curl -fsS -X POST "$BASE_URL/api/v1/apply" \
    -F "style_id=go_yoonjung" \
    -F "image=@${IMAGE};type=image/jpeg" \
    | python3 -c "
import json, sys, base64
d = json.load(sys.stdin)
print('engine:', d.get('engine'))
print('device:', d.get('device'))
print('style:', d.get('style_name'))
after = d.get('after_image_base64', '')
print('after_image_bytes:', len(base64.b64decode(after)))
"
fi

echo ""
echo "Swagger: $BASE_URL/docs"
