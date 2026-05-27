# celebfit

```
main  ──push──▶  GitHub Action  ──merge──▶  app  ──▶  RunPod / 브라우저 미리보기
 │                                              │
 ML 파이프라인                                   + Flutter + API + deploy
```

| 브랜치 | 담당 | 주요 폴더 |
|--------|------|-----------|
| **main** | ML / 파이프라인 | `pipeline/`, `masking_bisenet/`, `lora_checkpoint/` |
| **app** | 앱 / API / 배포 | `celebfit_app/`, `api/`, `deploy/`, `scripts/` |

**규칙:** ML 코드는 **`main`에 push** → GitHub Action이 **`app`에 자동 반영**.  
`app`에서 직접 ML 코드를 고치지 않습니다. (충돌·중복 방지)

자동 sync: [SYNC_BRANCHES.md](./SYNC_BRANCHES.md)

---

## app 브랜치

`app` = **main ML 코드** + **서비스 코드**. RunPod·브라우저 미리보기는 이 브랜치를 사용합니다.

| 폴더 | 역할 |
|------|------|
| `celebfit_app/` | Flutter 앱 + HTML 미리보기 (`preview/index.html`) |
| `api/` | FastAPI 백엔드 (`POST /api/v1/apply`) |
| `deploy/` | RunPod / Docker 배포 |
| `scripts/` | 미리보기 실행 등 |

---

## 실행 방법

### 브라우저 미리보기 (권장)

```bash
git clone git@github.com:celebfit/celebfit.git
cd celebfit
git checkout app
./scripts/open_app_preview.sh
```

→ `http://127.0.0.1:8765/preview/index.html`

**앱 사용:** 홈(사진) → 스타일(고윤정/신세경/홍수주 · 적용하기) → 결과(Before/After)

### 팀·핸드폰에서 공유

| 방법 | URL | 언제 쓰나 |
|------|-----|-----------|
| **GitHub Pages** (권장) | https://celebfit.github.io/celebfit/preview/index.html | `app` push 후 항상 접속 (HTTPS, 핸드폰 OK) |
| **같은 Wi-Fi** | `./scripts/share_app_preview.sh` 출력 URL | 회의실·실습실 같은 네트워크 |
| **임시 공개 URL** | `./scripts/share_app_preview.sh --public` | cloudflared 터널 (Mac 켜져 있어야 함) |

GitHub Pages **최초 1회:** repo **Settings → Pages → Build and deployment → GitHub Actions** 선택.

RunPod API 연동 URL 예:

```
https://celebfit.github.io/celebfit/preview/index.html?api=https://YOUR_POD_ID-8000.proxy.runpod.net
```

MY 탭에서 RunPod URL 저장해도 됩니다.

### API 연결 (실제 AI 변환)

상단 배너 **연결됨**이어야 AI가 동작합니다. **미연결**이면 UI 데모만 됩니다.

**RunPod (팀 공용):**

```bash
./scripts/open_app_preview.sh https://YOUR_POD_ID-8000.proxy.runpod.net
```

Pod URL은 미리보기 **MY 탭**에서 저장 가능. 배포: [RUNPOD.md](./RUNPOD.md)

**로컬 API (선택):**

```bash
# 터미널 1
pip install -r api/requirements.txt
export PYTHONPATH=$PWD
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000

# 터미널 2
./scripts/open_app_preview.sh
```

### RunPod 반영

`main` push → Action이 `app` merge → Pod **Stop → Start** (또는 Pod에서 `git fetch origin app && git reset --hard origin/app`)

---

## 참고

| 문서 | 내용 |
|------|------|
| [INTEGRATION.md](./INTEGRATION.md) | API ↔ 앱 연동 |
| [RUNPOD.md](./RUNPOD.md) | GPU Pod 배포 |
| [celebfit_app/README.md](./celebfit_app/README.md) | Flutter 앱 |

