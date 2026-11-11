# chrome-quiet-debugger

把 Chrome 那條「已開始對這個瀏覽器進行偵錯」提示藏起來。

Claude in Chrome、Codex 或其他瀏覽器 agent 透過 `chrome.debugger` 控制網頁時，Chrome 會在視窗上方顯示這條提示。這個工具會讓 Chrome **一律**帶著 Chromium 內建的啟動參數 `--silent-debugger-extension-api` 開啟，提示就不會再出現。

它不會修改 `chrome.exe`、不會開啟遠端偵錯連接埠，也不會更動任何擴充功能。

## 這是什麼問題

下圖是示意圖，不是實際截圖。修改前那種黃色提示條，就是這個工具要處理的東西：

![示意圖：修改前會出現「已開始對這個瀏覽器進行偵錯」提示條，修改後不再出現](docs/before-after.png)

*示意圖（非實際截圖）。圖中是一般瀏覽器外觀，不是官方介面還原。*

實際看到的文字大致是：

- 中文：`「Claude」已開始對這個瀏覽器進行偵錯`，右側有「取消」
- 英文：`"Claude" started debugging this browser`，右側有 `Cancel`

擴充功能名稱會依你實際在用的工具而變。

## 它做什麼、不做什麼

**會做**

- Windows：備份後，把啟動參數加到目前使用者桌面、公用桌面、開始功能表（個人與所有使用者），以及工作列釘選的 Chrome 捷徑。同時在 `HKCU` 覆寫 `ChromeHTML`（以及 Beta / Dev / Canary 等類似項目）的開啟指令，讓你點連結開啟 Chrome 時也會帶上這個參數。不需要系統管理員權限。
- macOS：在 `~/Applications` 建立一個名為 `Chrome (Quiet Debugger).app` 的啟動器，用它來開啟 Chrome。

**不會做**

- 不修改 Chrome 的程式檔
- 不開啟 `--remote-debugging-port`
- 不安裝、移除或改設定任何擴充功能
- 不改 `chrome://flags`

同一個參數不會被加兩次。再跑一次安裝是安全的。

## Windows 安裝

先完全結束 Chrome（系統匣裡的圖示也要結束）。

用 PowerShell，在這個資料夾執行：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\install.ps1
```

若你是從 GitHub 下載 ZIP（`Code` → `Download ZIP`），先解壓縮，進入解出來的 `chrome-quiet-debugger-main` 資料夾，再執行上面兩行。

看目前哪些捷徑和開啟指令已經加上參數：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\status.ps1
```

先預覽、不實際寫入：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\install.ps1 -WhatIf
```

解除安裝（有備份就還原，沒有備份就只把參數拿掉）：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\uninstall.ps1
```

備份會寫到 `%USERPROFILE%\chrome-quiet-debugger-backup`。

如果「所有使用者」的桌面或開始功能表捷徑更新失敗，多半是權限不夠。你自己桌面上的捷徑，以及點連結時用的開啟指令，一般仍會改成功。也可以用系統管理員權限再跑一次，專門補那幾個捷徑。

改完後請重新開啟 Chrome，變更才會生效。

## macOS 安裝

macOS 沒有跟 Windows 一樣乾淨的「改掉所有開啟入口」作法，所以這裡用啟動器，而不是去改系統裡的 Chrome。

```bash
chmod +x mac/install.sh mac/uninstall.sh
./mac/install.sh
```

從 ZIP 安裝的話，同樣先解壓縮、進入資料夾，再執行上面的指令。

使用方式：

1. 先完全結束 Chrome（`Cmd+Q`，不要只關視窗）。
2. 用 `Chrome (Quiet Debugger).app` 打開 Chrome，不要點原本的 Chrome 圖示。
3. 可以把這個啟動器拖到 Dock，之後都從那裡開啟。

解除安裝：

```bash
./mac/uninstall.sh
```

**macOS 的限制：** 如果 Chrome 已經完全結束，你再去點一個網頁連結，系統還是會用原本的 `Google Chrome.app` 啟動，這次就不會帶上參數，提示條可能又出現。請先用啟動器打開 Chrome，之後再點連結，就會沿用已經帶參數的那個行程。

## 怎麼確認有沒有成功

1. 完全結束 Chrome 後再打開（Windows 用平常的捷徑；macOS 用啟動器）。
2. 在網址列進入 `chrome://version`。
3. 看「命令列」（Command Line）那一段，裡面應該要有 `--silent-debugger-extension-api`。

## 安全上的取捨

這條提示是在告訴你：有擴充功能正在透過偵錯介面控制這個瀏覽器。上面的「取消」也可以立刻切斷這種控制。

加上這個參數之後，**所有**使用偵錯 API 的擴充功能都不會再顯示這條提示，不是只針對 Claude 或 Codex。請先確認你安裝的擴充功能都信得過，再使用這個工具。

共用電腦、公司管理的電腦，或你不確定裝了哪些擴充功能時，不要用。

## 其他做法

- [thelabcorner/chrome-silent-debugger](https://github.com/thelabcorner/chrome-silent-debugger) 是類似的 Windows 工具，用的也是同一個啟動參數。
- 比較精準的作法是用企業政策 `ExtensionInstallForcelist` 強制安裝特定擴充功能。走這條路時，Chrome 本來就不會對「被政策強制安裝」的那個擴充功能顯示這條提示。不過要改系統層級的設定（通常需要系統管理員），而且那個擴充功能使用者不能自己移除；公司電腦也可能跟 IT 政策衝突。
- 有人在 Anthropic 的 issue 追蹤裡建議官方提供內建選項：[anthropics/claude-code#69287](https://github.com/anthropics/claude-code/issues/69287)。

## 授權

[MIT](LICENSE)。Copyright (c) 2026 Stan Shih。

---

## English

A small tool that hides Chrome's `"<extension>" started debugging this browser` infobar (the yellow/grey bar with a Cancel button). It does this by launching Chrome with Chromium's own `--silent-debugger-extension-api` switch.

It does not patch `chrome.exe`, does not open a remote debugging port, and does not change any extensions.

**Windows:** run `.\windows\install.ps1` from PowerShell after `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. That updates Chrome shortcuts (Desktop, Start Menu, pinned taskbar) and a per-user `ChromeHTML` open-command override, so no administrator account is required. Use `.\windows\status.ps1` and `.\windows\uninstall.ps1` to inspect or restore. Backups go to `%USERPROFILE%\chrome-quiet-debugger-backup`.

**macOS:** run `./mac/install.sh`. This creates `~/Applications/Chrome (Quiet Debugger).app`. Quit Chrome fully (`Cmd+Q`) and open it from that launcher. Limitation: if Chrome is fully quit and you then click a link, macOS still starts the official `Google Chrome.app` without the flag. Open the launcher first, then click links.

**Verify:** open `chrome://version` and check that the command line contains `--silent-debugger-extension-api`.

**Security:** the flag hides the infobar for *all* extensions that use the debugger API, not only one agent. Use it only if you trust the extensions you already have installed. Do not use it on a shared or managed machine.

See also [thelabcorner/chrome-silent-debugger](https://github.com/thelabcorner/chrome-silent-debugger), the `ExtensionInstallForcelist` policy approach, and [anthropics/claude-code#69287](https://github.com/anthropics/claude-code/issues/69287).

MIT license, copyright Stan Shih.
