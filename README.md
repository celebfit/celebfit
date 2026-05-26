# celebfit — AI 눈썹 스타일 변환

셀카 사진의 눈썹을 **연예인 스타일(고윤정·신세경·홍수주)** 로 바꿔 주는 프로젝트입니다.  
ML 파이프라인 + FastAPI 서버 + 브라우저/Flutter 앱으로 구성되어 있습니다.

> BrushNet은 사용하지 않습니다. 별도 체크포인트 다운로드 불필요.

---

## 팀원 빠른 안내

| 역할 | 브랜치 | 하는 일 |
|------|--------|---------|
| **ML / 파이프라인** | `main` | `pipeline/`, LoRA, 마스킹 코드 수정 |
| **앱 / API / 배포** | `app` | Flutter UI, FastAPI, RunPod 설정 |

**규칙 한 줄:** ML 코드는 **`main`에 push** → GitHub Action이 **`app`에 자동 반영**.  
`app`에서 직접 ML 코드를 고치지 않습니다. (충돌·중복 방지)

---

## 브랜치 구조

```
main  ──push──▶  GitHub Action  ──merge──▶  app  ──▶  RunPod / 브라우저 미리보기
 │                                              │
 ML 파이프라인                                   + Flutter + API + deploy
```

| 브랜치 | 포함 내용 | 주요 폴더 |
|--------|-----------|-----------|
| **main** | ML만 | `pipeline/`, `masking_bisenet/`, `lora_checkpoint/` |
| **app** | main + 서비스 | `celebfit_app/`, `api/`, `deploy/`, `scripts/` |

자동 sync 상세: [SYNC_BRANCHES.md](./SYNC_BRANCHES.md)

---

## ML 팀 — 로컬에서 파이프라인 실행 (main)

```bash
git checkout main
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# BiSeNet 가중치 (최초 1회)
cd masking_bisenet/face-parsing && ./download.sh && cd ../..

python pipeline/main.py   # 결과 → pipeline/outputs/
```

**처리 순서:** 얼굴 마스크(BiSeNet) → 눈썹 영역 확대 → MediaPipe + LaMa로 기존 눈썹 지우기 → SD Inpaint + LoRA로 새 눈썹 생성 → 원본에 합성

| 항목 | 경로 / 값 |
|------|-----------|
| LoRA | `lora_checkpoint/celeb_eyebrows_all_pro_v4/` |
| Base model | `emilianJR/epiCRealism` (첫 실행 시 자동 다운로드) |

코드 push 후 **Actions 탭**에서 `Sync main into app` 완료를 확인하세요.

---

## 앱 팀 — 브라우저에서 UI 확인 (app)

Flutter 설치 없이 **HTML 미리보기**로 가장 빠르게 확인할 수 있습니다.

### 1단계: 미리보기 실행

```bash
git checkout app
./scripts/open_app_preview.sh
```

브라우저: `http://127.0.0.1:8765/preview/index.html`

### 2단계: 앱 사용 순서

1. **홈** — 사진 업로드  
2. **분석** — UI만 (mock, API 없음)  
3. **스타일** — 고윤정 / 신세경 / 홍수주 선택 → **적용하기**  
4. **결과** — Before/After 슬라이더  

### 3단계: API 연결 (실제 AI 변환)

상단 배너가 **연결됨**이어야 AI 변환이 됩니다. **미연결**이면 UI 데모만 동작합니다.

**RunPod GPU (팀 공용, 권장):**

```bash
./scripts/open_app_preview.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

Pod URL은 **MY 탭**에서 저장해도 됩니다.

**로컬 API (Mac GPU/MPS 테스트):**

```bash
# 터미널 1 — API 서버
pip install -r api/requirements.txt
export PYTHONPATH=$PWD
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000

# 터미널 2 — 미리보기
./scripts/open_app_preview.sh
```

연결 확인: `curl http://127.0.0.1:8000/health`

---

## 자주 묻는 질문

| 질문 | 답 |
|------|-----|
| main만 push하면 RunPod에 바로 반영되나? | Action이 app에 merge한 뒤, Pod **Stop → Start** (또는 `git pull origin app`) 필요 |
| 브라우저에서 AI가 안 돼요 | 상단 배너 **미연결** → RunPod URL 또는 로컬 API 실행 |
| app 브랜치를 직접 수정해도 되나? | Flutter/API/deploy 수정은 **app에 push**. ML 코드는 **main**에서 |
| Flutter 앱은? | [celebfit_app/README.md](./celebfit_app/README.md) |
| RunPod 배포는? | [RUNPOD.md](./RUNPOD.md) |
| API 상세 연동은? | [INTEGRATION.md](./INTEGRATION.md) |

---

## 저장소

GitHub: [github.com/celebfit/celebfit](https://github.com/celebfit/celebfit)
