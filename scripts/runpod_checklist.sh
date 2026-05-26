#!/usr/bin/env bash
# RunPod 배포 체크리스트 (실행만 하면 다음 단계 출력)
set -euo pipefail

cat <<'EOF'
========================================
 celebfit → RunPod GPU 배포 체크리스트
========================================

1) GitHub app 브랜치 push
   cd ConditionalImageGeneration
   git add Dockerfile api/ deploy/ RUNPOD.md celebfit_app/
   git commit -m "Add RunPod GPU deployment for celebfit API"
   git push -u origin app

2) runpod.io → Pods → Deploy
   - GPU: RTX 3090 or 4090
   - Container Disk: 40 GB
   - Volume: 50 GB → mount /data
   - Port: 8000 HTTP
   - Env: ENABLE_SD=true, HF_HOME=/data/huggingface, WARMUP_ON_START=true

3) Container
   - GitHub repo: jiucai233/ConditionalImageGeneration branch app
   - Dockerfile: Dockerfile
   (또는 Docker Hub: YOUR_USER/celebfit-api:latest)

4) Pod 시작 후 URL 확인
   https://XXXX-8000.proxy.runpod.net/health
   POST .../api/v1/warmup  (첫 warm-up 10~20분)

5) iPhone 앱
   마이 탭 → RunPod URL 입력 → 저장 · 연결 확인
   홈 → 사진 → 스타일 → 적용

자세히: RUNPOD.md
EOF
