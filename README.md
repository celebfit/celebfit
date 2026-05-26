# celebfit — AI 눈썹 스타일 변환

BiSeNet + MediaPipe 마스킹, LaMa 지우기, **SD Inpaint + LoRA**로 연예인 스타일(고윤정·신세경·홍수주) 눈썹을 생성합니다.

> BrushNet은 사용하지 않습니다. 별도 체크포인트 다운로드 불필요.

## 브랜치

| 브랜치 | 역할 |
|--------|------|
| **main** | ML 파이프라인 (`pipeline/`, `lora_checkpoint/`) |
| **app** | main + Flutter + FastAPI + RunPod (`celebfit_app/`, `api/`, `deploy/`) |

`main`에 push하면 GitHub Action이 **app에 자동 merge**합니다. ([SYNC_BRANCHES.md](./SYNC_BRANCHES.md))

| 문서 | 내용 |
|------|------|
| [INTEGRATION.md](./INTEGRATION.md) | API ↔ 앱 연동 |
| [RUNPOD.md](./RUNPOD.md) | GPU Pod 배포 |
| [celebfit_app/README.md](./celebfit_app/README.md) | Flutter 앱 |

---

## ML 파이프라인 (main)

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# BiSeNet 가중치 (최초 1회)
cd masking_bisenet/face-parsing && ./download.sh && cd ../..

python pipeline/main.py   # 결과 → pipeline/outputs/
```

**흐름:** BiSeNet 마스크 → Zoom Crop → MediaPipe + LaMa(3-pass) → SD Inpaint + LoRA → 색상 보정·블렌딩

LoRA: `lora_checkpoint/celeb_eyebrows_all_pro_v4/` · Base model: `emilianJR/epiCRealism` (자동 다운로드)

---

## 앱 브라우저 실행 (app)

```bash
git checkout app
./scripts/open_app_preview.sh
# → http://127.0.0.1:8765/preview/index.html
```

**RunPod API 연동 (실제 AI 변환):**

```bash
./scripts/open_app_preview.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

**로컬 API (선택):**

```bash
# 터미널 1
pip install -r api/requirements.txt
export PYTHONPATH=$PWD
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000

# 터미널 2
./scripts/open_app_preview.sh
```

**사용 흐름:** 홈(사진) → 스타일(고윤정/신세경/홍수주 · 적용하기) → 결과(Before/After)

API 미연결 시 UI만 데모 모드. Flutter Web은 `celebfit_app/README.md` 참고.
