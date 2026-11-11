# AGENTS.md

Instructions for an AI agent installing, verifying, or removing chrome-quiet-debugger on a user's machine.

## What this is

A small installer that hides Chrome's debugger-extension infobar (`"…" started debugging this browser` / 「『…』已開始為這個瀏覽器偵錯」) by launching Chrome with Chromium's own `--silent-debugger-extension-api` switch.

Repo: https://github.com/stantheman0128/chrome-quiet-debugger

## Rules

- Do not modify `chrome.exe` or the `Google Chrome.app` binary.
- Do not open a remote debugging port (do not add `--remote-debugging-port`).
- Do not install, remove, or change any Chrome extensions.
- Do not run the installers against a machine that is not the user's.
- Do not present `motty@…` or other guessed addresses as part of this task; this repo is only about the Chrome infobar.
- After making changes, list the shortcuts, registry values, or launcher path you changed so the user can review them.
- Detect Windows vs macOS yourself. Do not ask the user to paste commands step by step. The only user actions you should request are: fully quit and reopen Chrome, and check `chrome://version`.

## Install

If the source is not already on the machine, clone this repository or download and extract the GitHub ZIP.

### Windows (PowerShell 5.1+)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\status.ps1
.\windows\install.ps1
```

Preview without writing: `.\windows\install.ps1 -WhatIf`.

The installer is idempotent. It appends `--silent-debugger-extension-api` to Chrome `.lnk` shortcuts (current-user Desktop, Public Desktop, Start Menu for the user and for all users, and taskbar pins under `%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar`) and to a per-user `ChromeHTML` / Chrome*HTM* open-command override at `HKCU\Software\Classes\…\shell\open\command` (copied from HKLM if needed). Administrator rights are not required for user-level items. If all-users shortcuts fail, say which ones were skipped.

Backups go to `%USERPROFILE%\chrome-quiet-debugger-backup` with a manifest.

### macOS

```bash
chmod +x mac/install.sh mac/uninstall.sh
./mac/install.sh
```

This creates `~/Applications/Chrome (Quiet Debugger).app`, a launcher that runs `open -a "Google Chrome" --args --silent-debugger-extension-api`. It does not patch every launch path. If Chrome is fully quit and the user clicks a link, macOS starts the official `Google Chrome.app` without the flag. Tell the user to start from the launcher (and optionally pin it to the Dock).

## After install

Ask the user to fully quit Chrome (Windows: also check the notification area; macOS: `Cmd+Q`, not just closing windows) and reopen it:

- Windows: the usual Chrome shortcut is fine once it has been updated.
- macOS: use `Chrome (Quiet Debugger).app`.

Then ask them to open `chrome://version` and confirm that the Command Line / 「命令列」 contains `--silent-debugger-extension-api`.

## Uninstall

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\uninstall.ps1
```

```bash
./mac/uninstall.sh
```

Windows restores from the backup if present, otherwise it strips the flag. macOS removes the launcher app; remind the user to drag it out of the Dock if they pinned it. Ask them to fully quit Chrome afterwards.

## Status (Windows only)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows\status.ps1
```

Shows which shortcuts and open-command entries already have the flag.

## Security note to give the user

The flag hides the infobar for every extension that uses the debugger API, not only one agent. They should use this only if they trust their installed extensions, and should not use it on a shared or managed machine.
