# iPhone 실기기에서 눈썹 변환 테스트

## 사전 준비

1. **ConditionalImageGeneration** (모델 코드) — 형제 폴더에 clone
   ```bash
   cd ~/Downloads
   git clone https://github.com/jiucai233/ConditionalImageGeneration.git
   ```

2. **Flutter** — [macOS 설치 가이드](https://docs.flutter.dev/get-started/install/macos)

3. **Xcode** — App Store에서 설치, 한 번 실행해 라이선스 동의

---

## 디스크를 못 비울 때 → RunPod (권장)

Mac 디스크 부족 시 **RunPod GPU**에 API를 올리세요. 자세한 절차: **[RUNPOD.md](./RUNPOD.md)**

요약:
1. RunPod Pod (RTX 3090+, 40GB disk, Volume `/data`)
2. Docker 이미지 배포 (`Dockerfile` 포함)
3. Pod URL → 앱 **마이** 탭에 입력

---

## 0. 디스크 공간 (로컬 Mac 사용 시)

SD 모델(epiCRealism) + LaMa 다운로드에 **여유 8GB 이상** 필요합니다.

```bash
df -h ~
```

313MB 이하이면 모델 다운로드가 실패합니다.  
→ 불필요 파일 삭제 후 재시도, 또는 **RunPod GPU 서버** 사용.

---

## 1. API 서버 실행 (Mac)

```bash
cd ~/Downloads/celebfit
chmod +x scripts/start_api_gpu.sh scripts/setup_ios.sh
./scripts/start_api_gpu.sh
```

첫 실행 시 모델 다운로드로 **5~15분** 걸릴 수 있습니다.

확인:
```bash
curl http://127.0.0.1:8000/health
```
→ `"engine": "github_sd_inpaint"` 또는 `"sd_inpaint"` 이면 성공

터미널에 표시되는 **Mac IP**를 메모하세요 (예: `http://192.168.0.10:8000`).

---

## 2. iOS 앱 빌드 (최초 1회)

```bash
cd ~/Downloads/celebfit
./scripts/setup_ios.sh
```

---

## 3. iPhone 실기기 실행

1. iPhone을 Mac에 USB 연결 (또는 무선 디버깅)
2. iPhone과 Mac **같은 Wi-Fi**
3. 앱 실행:
   ```bash
   cd celebfit_app
   flutter run
   ```
4. 앱 **마이** 탭 → **API 서버 설정**에 Mac IP 입력  
   예: `http://192.168.0.10:8000`
5. **저장 · 연결 확인** → `연결됨 · github_sd_inpaint` 확인
6. **홈** → 사진 업로드 → **스타일** → 고윤정/신세경/홍수주 **적용하기**
7. **결과** 탭에서 Before/After 확인 (20~30초 소요)

---

## 문제 해결

| 증상 | 해결 |
|------|------|
| 연결 실패 | API 실행 여부, Wi-Fi, Mac IP 확인 |
| `fallback` 엔진 | `.env`에서 `ENABLE_SD=true`, ConditionalImageGeneration 경로 확인 |
| 얼굴 인식 실패 | 정면 셀카, 밝은 조명 |
| Flutter 없음 | `brew` 또는 공식 설치 후 `flutter doctor` |

---

## 시뮬레이터만 테스트할 때

API: `http://127.0.0.1:8000` (기본값)  
별도 IP 설정 불필요.
