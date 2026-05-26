# celebfit App

AI 눈썹 스타일 매칭 앱 — Flutter UI

## 화면 구성

| 탭 | 화면 | 상태 |
|----|------|------|
| 홈 | 사진 업로드 (카메라/갤러리) | 동작 |
| 분석 | AI 분석 UI (정적 mock 데이터) | UI만 |
| 스타일 | 필터 + 스타일 그리드 + 적용 | UI + mock 적용 |
| 결과 | Before/After 슬라이더 + 적합도 | UI + mock 결과 |
| MY | 마이페이지 | UI만 |

## 실행 방법

```bash
cd celebfit_app
flutter pub get
flutter run
```

iOS 시뮬레이터 / Android 에뮬레이터 / Chrome:

```bash
flutter run -d chrome   # 웹에서 빠르게 UI 확인
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── theme/app_theme.dart      # 핑크 포인트 디자인 시스템
├── models/app_models.dart    # 스타일·분석 mock 데이터
├── providers/app_state.dart  # 전역 상태 (업로드, 선택, 결과)
├── screens/                  # 5개 탭 화면
└── widgets/                  # 공통·시각 위젯
```

## 사용자 흐름

1. **홈** — 셀카 업로드
2. **분석** — mock 분석 결과 확인 (기능 없음, UI만)
3. **스타일** — 스타일 선택 → **FastAPI `/apply` 호출** → 결과 탭 이동
4. **결과** — API before/after로 Before/After 슬라이더

## API 연동

기본 Base URL (플랫폼별 자동):

- Android 에뮬레이터: `http://10.0.2.2:8000`
- iOS/macOS/Chrome: `http://127.0.0.1:8000`

커스텀:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

API 서버 실행은 프로젝트 루트 `INTEGRATION.md` 참고.

## 다음 단계

- 분석 탭: `/analyze` API 추가
- 결과 저장: `gallery_saver` / `share_plus`

## 디자인

- Primary: `#E8A0BF`
- Background: `#FAFAFA`
- Font: Noto Sans KR (google_fonts)
