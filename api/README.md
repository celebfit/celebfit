# celebfit API

눈썹 스타일 적용 FastAPI 백엔드

## 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 서버·엔진 상태 |
| GET | `/api/v1/styles` | 스타일 목록 |
| POST | `/api/v1/apply` | 이미지 + style_id → before/after |

### POST /api/v1/apply

**multipart/form-data**

- `image`: JPEG/PNG 파일
- `style_id`: `go_yoonjung`, `shin_sekyung`, `hong_sooju`, `natural`, `soft_arch`, `straight`

**응답**

```json
{
  "style_id": "go_yoonjung",
  "style_name": "고윤정",
  "engine": "sd_inpaint",
  "device": "cuda",
  "before_image_base64": "...",
  "after_image_base64": "..."
}
```

## 설치 & 실행

```bash
cd /Users/leejiwon/Downloads/celebfit
python3 -m venv .venv
source .venv/bin/activate
pip install -r api/requirements.txt

# 프로젝트 루트에서
export PYTHONPATH=$PWD
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000
```

또는:

```bash
chmod +x api/run.sh
./api/run.sh
```

## 모델 다운로드 (최초 1회)

서버 시작 시 자동 다운로드:

- MediaPipe `face_landmarker.task`
- BiSeNet `79999_iter.pth`
- GitHub LoRA (`celeb_eyebrows_all_gender_integrated`, v4 fallback)
- epiCRealism + LaMa (diffusers/simple-lama-inpainting)

`weights/` 폴더에 저장됩니다.

## GPU / Fallback

- **GPU + 모델 정상**: LaMa 눈썹 제거 → SD Inpaint + LoRA
- **GPU/모델 없음**: `allow_fallback=true` 시 OpenCV 기반 미리보기 (앱 연동 테스트용)

`.env` 예시:

```
ALLOW_FALLBACK=true
API_PORT=8000
```

## Flutter 앱 연결

| 환경 | Base URL |
|------|----------|
| Android 에뮬레이터 | `http://10.0.2.2:8000` |
| iOS/macOS | `http://127.0.0.1:8000` |
| Chrome | `http://localhost:8000` |

커스텀 URL:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000
```
