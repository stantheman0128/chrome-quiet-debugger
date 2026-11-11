**繁體中文** | [English](README.en.md)

# chrome-quiet-debugger

把 Chrome 那條「已開始為這個瀏覽器偵錯」提示藏起來。作法是讓 Chrome 啟動時帶上 `--silent-debugger-extension-api`。不會修改 Chrome 程式檔，也不會開啟遠端偵錯連接埠。

![使用前出現提示條，使用後提示條消失](docs/before-after.png)

加上這個參數後，**所有**使用偵錯 API 的擴充功能都不會再顯示這條提示。請先確認你安裝的擴充功能都信得過；共用或公司管理的電腦不要用。

更完整的說明（會改哪些地方、不用腳本的作法、限制、安全說明、其他做法）見 [詳細說明](docs/DETAILS.md)。

## 給 AI agent 安裝

把下面這段貼給 Claude Code、Codex、Cursor 或其他能改你電腦設定的 AI agent：

```
請幫我安裝 https://github.com/stantheman0128/chrome-quiet-debugger
請先讀 repo 裡的 AGENTS.md，再依作業系統執行。不要修改 chrome.exe 或 Google Chrome.app，不要開啟遠端偵錯連接埠，不要更動任何擴充功能。做完後列出你改了哪些項目，讓我過目。只有「完全結束並重開 Chrome」和「到 chrome://version 確認命令列」需要我動手。
```

## 手動安裝

### Windows

1. 從 [這個 repo](https://github.com/stantheman0128/chrome-quiet-debugger) 下載 ZIP 並解壓縮。先完全結束 Chrome（系統匣裡的圖示也要結束）。
2. 在該資料夾打開 PowerShell，執行：

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\windows\install.ps1
   ```

3. 重新打開 Chrome。

### macOS

1. 下載並解壓縮這個 repo（或 `git clone`）。完全結束 Chrome（`Cmd+Q`）。
2. 在該資料夾執行：

   ```bash
   chmod +x mac/install.sh
   ./mac/install.sh
   ```

3. 用 `~/Applications/Chrome (Quiet Debugger).app` 打開 Chrome（可拖到 Dock）。不要點原本的 Chrome 圖示。

## 怎麼確認

到 `chrome://version` 看「命令列」是否包含 `--silent-debugger-extension-api`。請先完全結束 Chrome 再重開。

## 移除

Windows（同樣先跑 `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`）：`.\windows\uninstall.ps1`。macOS：`./mac/uninstall.sh`。

## 授權

[MIT](LICENSE)。Copyright (c) 2026 Stan Shih。
