#!/usr/bin/env bash
# Remove the Chrome (Quiet Debugger) launcher app.
set -euo pipefail

APP_NAME="Chrome (Quiet Debugger).app"
DEST="${HOME}/Applications/${APP_NAME}"

if [ ! -e "${DEST}" ]; then
  echo "找不到啟動器，似乎尚未安裝："
  echo "  ${DEST}"
  exit 0
fi

rm -rf "${DEST}"
echo "已移除："
echo "  ${DEST}"
echo
echo "若你有把它放到 Dock，請再把圖示拖離 Dock。"
echo "請完全結束 Chrome 後，再用原本的 Google Chrome 打開。"
