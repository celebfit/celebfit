#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/celebfit_app"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter가 설치되어 있지 않습니다."
  echo "1) https://docs.flutter.dev/get-started/install/macos"
  echo "2) 설치 후: flutter doctor"
  exit 1
fi

cd "$APP_DIR"
flutter create . --org com.celebfit --project-name celebfit_app --platforms=ios
flutter pub get

INFO_PLIST="ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Add :NSPhotoLibraryUsageDescription string '눈썹 스타일 적용을 위해 사진을 선택합니다.'" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :NSPhotoLibraryUsageDescription '눈썹 스타일 적용을 위해 사진을 선택합니다.'" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :NSCameraUsageDescription string '눈썹 스타일 적용을 위해 카메라를 사용합니다.'" "$INFO_PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :NSCameraUsageDescription '눈썹 스타일 적용을 위해 카메라를 사용합니다.'" "$INFO_PLIST"

/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$INFO_PLIST" 2>/dev/null || true

echo ""
echo "✅ iOS 프로젝트 준비 완료"
echo ""
echo "다음 단계:"
echo "  1) 터미널 1: ./scripts/start_api_gpu.sh"
echo "  2) iPhone과 Mac을 같은 Wi-Fi에 연결"
echo "  3) 앱 마이 탭 → Mac IP 입력 (예: http://192.168.x.x:8000)"
echo "  4) 터미널 2: cd celebfit_app && flutter run"
echo ""
