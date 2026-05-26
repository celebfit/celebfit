# main ↔ app 브랜치 동기화

## 브랜치 역할

| 브랜치 | 담당 | 예시 경로 |
|--------|------|-----------|
| **main** | ML / 눈썹 변환 파이프라인 | `pipeline/`, `masking_bisenet/`, `lora_checkpoint/` |
| **app** | main + 앱·API·배포 | `api/`, `celebfit_app/`, `deploy/`, `scripts/` |

**main에 push하면 GitHub Action이 `app`에 자동 merge·push합니다** (main 브랜치는 건드리지 않음).

---

## 방법 1: GitHub Action (자동, 권장)

`main`에 push되면 [.github/workflows/sync-main-to-app.yml](.github/workflows/sync-main-to-app.yml)이  
**main → app merge 후 `app`에 push**합니다.

1. 팀원이 `main`에 push
2. Actions **Sync main into app** 완료 확인 (보통 1~2분)
3. RunPod Pod **Stop → Start** (또는 Pod에서 `git fetch && git reset --hard origin/app`)

**merge 충돌** 시에만 PR이 자동 생성됩니다 → 충돌 해결 후 merge.

수동 실행: Actions → **Sync main into app** → **Run workflow**

> `app` 브랜치 보호 규칙이 있으면 Actions bot push를 허용해야 합니다.  
> Settings → Branches → `app` → **Allow specified actors to bypass** → `github-actions[bot]`

---

## 방법 2: 로컬 스크립트

```bash
cd ~/Downloads/ConditionalImageGeneration   # 또는 clone 경로
chmod +x scripts/sync_main_to_app.sh
./scripts/sync_main_to_app.sh
git push origin app
```

---

## 방법 3: 수동 merge

```bash
git checkout app
git fetch origin
git merge origin/main
# 충돌 해결 후
git push origin app
```

---

## RunPod 반영

`deploy/runpod_bootstrap.sh`는 **`app` 브랜치만** clone합니다.

```bash
cd /workspace/celebfit && git fetch origin app && git reset --hard origin/app
pkill -f "uvicorn api.main" || true
bash deploy/entrypoint.sh
```

---

## LoRA만 main에서 받는 경우

로컬 `weights/`에 LoRA가 없을 때만  
`api/services/assets.py`가 **main** raw URL에서 다운로드합니다.  
`pipeline/main.py` 등 **코드 변경은 app merge 필수**입니다.
