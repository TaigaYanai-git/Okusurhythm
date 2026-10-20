#!/bin/zsh
# App Store 用スクリーンショットをシミュレータで撮る（サンプルデータで起動）
#   scripts/screenshots.sh [デバイス名]   → screenshots/<デバイス名>/*.png
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-iPhone 17 Pro Max}"
OUT="screenshots/${DEVICE// /_}"
BUNDLE_ID=com.taigayanai.okusurhythm
mkdir -p "$OUT"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$DEVICE" appearance "${APPEARANCE:-light}"

xcodebuild -project Okusurhythm.xcodeproj -scheme Okusurhythm -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath build/screens -quiet build
xcrun simctl install "$DEVICE" build/screens/Build/Products/Debug-iphonesimulator/Okusurhythm.app

shoot() {  # 名前 起動引数...
  local name=$1; shift
  xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -uiPreview "$@" >/dev/null
  sleep 3
  xcrun simctl io "$DEVICE" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "  $OUT/$name.png"
}

shoot 1_home -initialTab home
shoot 2_interactions -screen interactions
shoot 3_foods -screen foods
shoot 4_calendar -initialTab calendar
shoot 5_records -initialTab records
shoot 6_edit -screen edit
shoot 7_settings -screen settings
