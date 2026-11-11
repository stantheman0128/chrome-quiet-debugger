#!/usr/bin/env bash
# Create a small launcher app that starts Google Chrome with
# --silent-debugger-extension-api. Compatible with macOS /bin/bash 3.2.
set -euo pipefail

FLAG="--silent-debugger-extension-api"
APP_NAME="Chrome (Quiet Debugger).app"
DEST_DIR="${HOME}/Applications"
DEST="${DEST_DIR}/${APP_NAME}"
STAGING="${DEST_DIR}/.chrome-quiet-debugger.staging.app"
IDENTIFIER="com.stantheman0128.chrome-quiet-debugger"

echo "將在以下位置建立啟動器："
echo "  ${DEST}"

mkdir -p "${DEST_DIR}"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/chrome-quiet-debugger.XXXXXX")"
cleanup() {
  rm -rf "${tmpdir}" "${STAGING}"
}
trap cleanup EXIT

app="${tmpdir}/${APP_NAME}"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"

cat > "${app}/Contents/MacOS/launch" << 'LAUNCH'
#!/bin/bash
# Hands off to Google Chrome with the quiet-debugger flag.
# Flags only apply if Chrome was fully quit before this launcher runs.
FLAG="--silent-debugger-extension-api"

if open -a "Google Chrome" --args "${FLAG}"; then
  exit 0
fi

echo "找不到 Google Chrome。請確認已安裝在 /Applications。" >&2
exit 1
LAUNCH
chmod 755 "${app}/Contents/MacOS/launch"

cat > "${app}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>launch</string>
  <key>CFBundleIdentifier</key>
  <string>${IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Chrome (Quiet Debugger)</string>
  <key>CFBundleDisplayName</key>
  <string>Chrome (Quiet Debugger)</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.13</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

rm -rf "${STAGING}"
# Stage on the same volume as the destination, then swap.
cp -R "${app}" "${STAGING}"
rm -rf "${DEST}"
mv "${STAGING}" "${DEST}"

trap - EXIT
rm -rf "${tmpdir}"

echo
echo "完成。啟動器已放到："
echo "  ${DEST}"
echo
echo "使用方式："
echo "  1. 先完全結束 Chrome（Cmd+Q，不要只關視窗）。"
echo "  2. 用這個啟動器打開 Chrome，不要點原本的 Chrome 圖示。"
echo "  3. 可把啟動器拖到 Dock，之後都從那裡開啟。"
echo
echo "確認方式：在 Chrome 網址列開 chrome://version，命令列應包含："
echo "  ${FLAG}"
echo
echo "請注意：若 Chrome 已完全結束，你再點網頁連結，macOS 仍會用原本的"
echo "Google Chrome.app 啟動，參數就不會帶上。請先用這個啟動器打開 Chrome，"
echo "之後再點連結就沒問題。"
