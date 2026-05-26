# 팀 GitHub 저장소 만들기 & main / app 브랜치 이전

개인 계정(`jiucai233`) 대신 **팀이 함께 쓰는 GitHub Organization + 저장소**로 옮기는 방법입니다.

---

## 1. GitHub Organization 만들기 (웹, 5분)

1. [github.com](https://github.com) 로그인 (팀 대표 계정)
2. 우측 상단 프로필 → **Your organizations** → **Create organization**
3. **Free** 선택
4. Organization name 예: `celebfit-team` (원하는 이름)
5. **Create organization**

### 팀원 초대

1. Organization → **People** → **Invite member**
2. 팀원 GitHub 아이디 또는 이메일 초대
3. Role: **Member** (코드 push) 또는 **Owner** (설정 관리)

---

## 2. 새 저장소 만들기

1. Organization 페이지 → **New repository**
2. 설정:

| 항목 | 값 |
|------|-----|
| Repository name | `celebfit` (또는 `ConditionalImageGeneration`) |
| Visibility | Private (팀만) 또는 Public |
| README / .gitignore | **체크 해제** (빈 저장소) |

3. **Create repository**

생성 후 URL 예:

- HTTPS: `https://github.com/celebfit-team/celebfit.git`
- SSH: `git@github.com:celebfit-team/celebfit.git`

---

## 3. 브랜치 구조 (이전 후)

| 브랜치 | 내용 |
|--------|------|
| **main** | ML 파이프라인 (`pipeline/`, `lora_checkpoint/`, BiSeNet …) |
| **app** | main + FastAPI(`api/`) + Flutter(`celebfit_app/`) + Docker(RunPod) |

---

## 4. 로컬에서 push (한 번만)

Mac 터미널에서 **Organization 소유자/권한 있는 계정**으로 SSH 또는 HTTPS 로그인 후:

```bash
cd ~/Downloads/ConditionalImageGeneration

# SSH 키가 팀 org에 등록되어 있어야 함
chmod +x scripts/migrate_to_team_github.sh
./scripts/migrate_to_team_github.sh git@github.com:celebfit-team/celebfit.git
```

HTTPS 사용 시:

```bash
./scripts/migrate_to_team_github.sh https://github.com/celebfit-team/celebfit.git
```

성공하면 GitHub에서 **main**, **app** 두 브랜치가 보입니다.

---

## 5. GitHub Actions (Docker 이미지 빌드)

Organization repo → **Settings** → **Secrets and variables** → **Actions**

| Secret | 값 |
|--------|-----|
| `DOCKERHUB_USERNAME` | Docker Hub 아이디 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token |

`app` 브랜치 push 시 `celebfit-api:latest` 이미지 자동 빌드.

---

## 6. 팀 repo 이전 후 설정 변경

`.env` 또는 RunPod 환경 변수 (선택):

```
GITHUB_REPO_SLUG=celebfit-team/celebfit
```

LoRA는 repo 안 `lora_checkpoint/`에 포함되어 있어 보통 다운로드 불필요.

---

## 7. RunPod / 앱 URL 업데이트

- RunPod: Docker 이미지 `YOUR_DOCKERHUB/celebfit-api:latest` (변경 없음)
- GitHub clone URL만 팀 repo로 변경:

```bash
git clone -b app https://github.com/celebfit-team/celebfit.git
```

---

## 8. SSH 로그인 문제 (403 / Permission denied)

개인 계정(`easy048484`)으로 `jiucai233` repo에 push하다 실패한 경우와 동일합니다.

```bash
# SSH 키 확인
ssh -T git@github.com

# 다른 계정이면 ~/.ssh/config 에 Host github.com-team 설정
```

Organization repo push 권한이 있는 계정으로 인증해야 합니다.

---

## 체크리스트

- [ ] Organization 생성
- [ ] 팀원 초대
- [ ] 빈 repo `celebfit` 생성
- [ ] `migrate_to_team_github.sh` 실행
- [ ] GitHub에서 `main`, `app` 브랜치 확인
- [ ] Actions Secrets (Docker Hub) 등록
- [ ] RunPod Pod 재배포 (이미지 rebuild)
