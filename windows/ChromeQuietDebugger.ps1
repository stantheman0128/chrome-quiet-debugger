#Requires -Version 5.1
<#
.SYNOPSIS
    為 Chrome 加上 --silent-debugger-extension-api，隱藏「已開始對這個瀏覽器進行偵錯」提示。
.DESCRIPTION
    備份並修改目前使用者能寫入的 Chrome 捷徑，以及 HKCU 底下的 ChromeHTML（或類似）開啟指令。
    不會修改 chrome.exe、不會開啟遠端偵錯連接埠、也不會更動任何擴充功能。
.EXAMPLE
    .\ChromeQuietDebugger.ps1 -Action Install
.EXAMPLE
    .\ChromeQuietDebugger.ps1 -Action Install -WhatIf
.EXAMPLE
    .\ChromeQuietDebugger.ps1 -Action Status
.EXAMPLE
    .\ChromeQuietDebugger.ps1 -Action Uninstall
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Flag = '--silent-debugger-extension-api'
$BackupRoot = Join-Path $env:USERPROFILE 'chrome-quiet-debugger-backup'
$ManifestPath = Join-Path $BackupRoot 'manifest.json'
$FlagTokenPattern = '(?i)(?<!\S)--silent-debugger-extension-api(?!\S)'

function Test-HasFlag {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }
    return [regex]::IsMatch($Text, $FlagTokenPattern)
}

function Add-FlagToArgs {
    param([string]$Text)
    if (Test-HasFlag $Text) {
        return $Text
    }
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Flag
    }
    return ($Text.TrimEnd() + ' ' + $Flag)
}

function Add-FlagToCommandLine {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $Command
    }
    if (Test-HasFlag $Command) {
        return $Command
    }

    $exe = $null
    $rest = $null
    if ($Command -match '^(?<exe>\s*"[^"]+")(?<rest>.*)$') {
        $exe = $Matches['exe']
        $rest = $Matches['rest']
    }
    elseif ($Command -match '^(?<exe>\s*\S+)(?<rest>.*)$') {
        $exe = $Matches['exe']
        $rest = $Matches['rest']
    }
    else {
        return ($Command.TrimEnd() + ' ' + $Flag)
    }

    if ($rest -match '\S') {
        return ($exe.TrimEnd() + ' ' + $Flag + ' ' + $rest.TrimStart())
    }
    return ($exe.TrimEnd() + ' ' + $Flag)
}

function Remove-FlagFromText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }
    $cleaned = [regex]::Replace($Text, '(?i)\s+--silent-debugger-extension-api(?!\S)', '')
    $cleaned = [regex]::Replace($cleaned, '(?i)--silent-debugger-extension-api(?!\S)\s*', '')
    return $cleaned.Trim()
}

function Test-ChromeExePath {
    param([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) {
        return $false
    }
    $trimmed = $TargetPath.Trim().Trim('"')
    return ($trimmed -like '*\chrome.exe')
}

function Get-ShortcutSearchRoots {
    $candidates = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('StartMenu'),
        [Environment]::GetFolderPath('CommonStartMenu')
    )
    if ($env:APPDATA) {
        $candidates += (Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
    }

    $roots = @()
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            $roots += $candidate
        }
    }
    return $roots
}

function Get-ChromeShortcutPaths {
    $paths = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    foreach ($root in Get-ShortcutSearchRoots) {
        Get-ChildItem -LiteralPath $root -Filter '*.lnk' -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                $full = $_.FullName
                $key = $full.ToLowerInvariant()
                if ($seen.ContainsKey($key)) {
                    return
                }
                $info = Get-ShortcutData $full
                if ($null -ne $info -and (Test-ChromeExePath $info.TargetPath)) {
                    [void]$paths.Add($full)
                    $seen[$key] = $true
                }
            }
    }
    return @($paths)
}

function Get-ShortcutData {
    param([string]$Path)
    $shell = New-Object -ComObject WScript.Shell
    try {
        $lnk = $shell.CreateShortcut($Path)
        return [pscustomobject]@{
            Path        = $Path
            TargetPath  = [string]$lnk.TargetPath
            Arguments   = [string]$lnk.Arguments
            Description = [string]$lnk.Description
        }
    }
    catch {
        Write-Warning "無法讀取捷徑：$Path（$($_.Exception.Message)）"
        return $null
    }
    finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

function Set-ShortcutArguments {
    param(
        [string]$Path,
        [string]$Arguments
    )
    $shell = New-Object -ComObject WScript.Shell
    try {
        $lnk = $shell.CreateShortcut($Path)
        $lnk.Arguments = $Arguments
        $lnk.Save()
    }
    finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

function Get-RegistryCommandValue {
    param(
        [ValidateSet('HKCU', 'HKLM')]
        [string]$Hive,
        [string]$ProgId
    )
    $relative = "Software\Classes\$ProgId\shell\open\command"
    $root = if ($Hive -eq 'HKCU') {
        [Microsoft.Win32.Registry]::CurrentUser
    }
    else {
        [Microsoft.Win32.Registry]::LocalMachine
    }
    $key = $root.OpenSubKey($relative)
    if ($null -eq $key) {
        return $null
    }
    try {
        return $key.GetValue('')
    }
    finally {
        $key.Close()
    }
}

function Test-HkcuCommandKeyExists {
    param([string]$ProgId)
    $relative = "Software\Classes\$ProgId\shell\open\command"
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($relative)
    if ($null -eq $key) {
        return $false
    }
    $key.Close()
    return $true
}

function Set-HkcuCommandValue {
    param(
        [string]$ProgId,
        [string]$Value
    )
    $relative = "Software\Classes\$ProgId\shell\open\command"
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($relative)
    try {
        $key.SetValue('', $Value, [Microsoft.Win32.RegistryValueKind]::String)
    }
    finally {
        $key.Close()
    }
}

function Remove-HkcuCommandKey {
    param([string]$ProgId)
    $relative = "Software\Classes\$ProgId\shell\open\command"
    try {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($relative, $false)
    }
    catch [System.ArgumentException] {
        # Key already absent.
    }
}

function Get-ChromeHtmlProgIds {
    $known = @('ChromeHTML', 'ChromeBHTML', 'ChromeDHTML', 'ChromeSSHTM')
    $found = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($name in $known) {
        $hkcu = Get-RegistryCommandValue -Hive HKCU -ProgId $name
        $hklm = Get-RegistryCommandValue -Hive HKLM -ProgId $name
        $combined = @($hkcu, $hklm) | Where-Object { $_ }
        foreach ($value in $combined) {
            if ($value -match '(?i)chrome\.exe') {
                if (-not $seen.ContainsKey($name)) {
                    [void]$found.Add($name)
                    $seen[$name] = $true
                }
            }
        }
    }

    $hives = @([Microsoft.Win32.Registry]::CurrentUser, [Microsoft.Win32.Registry]::LocalMachine)
    foreach ($hive in $hives) {
        $classes = $hive.OpenSubKey('Software\Classes')
        if ($null -eq $classes) {
            continue
        }
        try {
            foreach ($name in $classes.GetSubKeyNames()) {
                if ($name -notmatch '^Chrome[A-Za-z0-9]*HTM[A-Za-z0-9]*$') {
                    continue
                }
                if ($seen.ContainsKey($name)) {
                    continue
                }
                $cmdKey = $classes.OpenSubKey("$name\shell\open\command")
                if ($null -eq $cmdKey) {
                    continue
                }
                try {
                    $value = $cmdKey.GetValue('')
                    if ($value -and ($value -match '(?i)chrome\.exe')) {
                        [void]$found.Add($name)
                        $seen[$name] = $true
                    }
                }
                finally {
                    $cmdKey.Close()
                }
            }
        }
        catch {
            # Some machines have unreadable Classes subkeys; known IDs above still work.
        }
        finally {
            $classes.Close()
        }
    }

    return @($found)
}

function Get-EffectiveCommand {
    param([string]$ProgId)
    $hkcu = Get-RegistryCommandValue -Hive HKCU -ProgId $ProgId
    if ($null -ne $hkcu) {
        return $hkcu
    }
    return (Get-RegistryCommandValue -Hive HKLM -ProgId $ProgId)
}

function New-EmptyManifest {
    return [pscustomobject]@{
        version    = 1
        createdAt  = (Get-Date).ToString('o')
        updatedAt  = (Get-Date).ToString('o')
        flag       = $Flag
        shortcuts  = @()
        registry   = @()
    }
}

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return $null
    }
    $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    return ($raw | ConvertFrom-Json)
}

function Write-Manifest {
    param($Manifest)
    $Manifest.updatedAt = (Get-Date).ToString('o')
    if (-not (Test-Path -LiteralPath $BackupRoot)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }
    $json = $Manifest | ConvertTo-Json -Depth 8
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($ManifestPath, $json, $utf8NoBom)
}

function Get-ManifestShortcutMap {
    param($Manifest)
    $map = @{}
    if ($null -eq $Manifest -or $null -eq $Manifest.shortcuts) {
        return $map
    }
    foreach ($item in @($Manifest.shortcuts)) {
        if ($item.path) {
            $map[$item.path.ToLowerInvariant()] = $item
        }
    }
    return $map
}

function Get-ManifestRegistryMap {
    param($Manifest)
    $map = @{}
    if ($null -eq $Manifest -or $null -eq $Manifest.registry) {
        return $map
    }
    foreach ($item in @($Manifest.registry)) {
        if ($item.progId) {
            $map[$item.progId] = $item
        }
    }
    return $map
}

function Get-UniqueBackupFileName {
    param(
        [string]$Directory,
        [string]$PreferredName
    )
    $safe = [regex]::Replace($PreferredName, '[<>:"/\\|?*]', '_')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = 'shortcut.lnk'
    }
    $candidate = Join-Path $Directory $safe
    $i = 1
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Directory ('{0}-{1}' -f $i, $safe)
        $i++
    }
    return $candidate
}

function Invoke-Install {
    $shortcutPaths = Get-ChromeShortcutPaths
    $progIds = Get-ChromeHtmlProgIds
    $manifest = Read-Manifest
    if ($null -eq $manifest) {
        $manifest = New-EmptyManifest
    }
    $shortcutMap = Get-ManifestShortcutMap $manifest
    $registryMap = Get-ManifestRegistryMap $manifest

    $shortcutItems = @($manifest.shortcuts)
    if ($null -eq $manifest.shortcuts) {
        $shortcutItems = @()
    }
    $registryItems = @($manifest.registry)
    if ($null -eq $manifest.registry) {
        $registryItems = @()
    }

    $changed = 0
    $skipped = 0
    $failed = 0

    Write-Host "正在檢查 Chrome 捷徑…"
    if ($shortcutPaths.Count -eq 0) {
        Write-Host "  在桌面、開始功能表與工作列釘選位置，沒有找到指向 chrome.exe 的捷徑。"
    }

    foreach ($path in $shortcutPaths) {
        $info = Get-ShortcutData $path
        if ($null -eq $info) {
            $failed++
            continue
        }
        if (Test-HasFlag $info.Arguments) {
            Write-Host "  已加上參數（略過）：$path"
            $skipped++
            continue
        }

        $newArgs = Add-FlagToArgs $info.Arguments
        if (-not $PSCmdlet.ShouldProcess($path, "在捷徑引數加上 $Flag")) {
            continue
        }

        try {
            $key = $path.ToLowerInvariant()
            if (-not $shortcutMap.ContainsKey($key)) {
                $backupDir = Join-Path $BackupRoot 'shortcuts'
                if (-not (Test-Path -LiteralPath $backupDir)) {
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                }
                $backupFile = Get-UniqueBackupFileName -Directory $backupDir -PreferredName ([IO.Path]::GetFileName($path))
                Copy-Item -LiteralPath $path -Destination $backupFile -Force
                $entry = [pscustomobject]@{
                    path               = $path
                    backup             = $backupFile
                    originalArguments  = $info.Arguments
                }
                $shortcutItems += $entry
                $shortcutMap[$key] = $entry
            }

            Set-ShortcutArguments -Path $path -Arguments $newArgs
            Write-Host "  已更新：$path"
            $changed++
        }
        catch {
            Write-Warning "無法更新捷徑：$path（$($_.Exception.Message)）若這是所有使用者的捷徑，可能需要系統管理員權限。"
            $failed++
        }
    }

    Write-Host "正在檢查 ChromeHTML 開啟指令（HKCU 覆寫，不需要系統管理員）…"
    if ($progIds.Count -eq 0) {
        Write-Host "  找不到 ChromeHTML / ChromeBHTML 等開啟指令。若尚未安裝 Chrome，可先安裝後再跑一次。"
    }

    foreach ($progId in $progIds) {
        $effective = Get-EffectiveCommand -ProgId $progId
        if ([string]::IsNullOrWhiteSpace($effective)) {
            Write-Warning "  $progId 沒有可用的開啟指令，略過。"
            continue
        }
        if (Test-HasFlag $effective) {
            Write-Host "  已加上參數（略過）：$progId"
            $skipped++
            continue
        }

        $hkcuExists = Test-HkcuCommandKeyExists $progId
        $hkcuValue = Get-RegistryCommandValue -Hive HKCU -ProgId $progId
        $sourceValue = $effective
        $newValue = Add-FlagToCommandLine $sourceValue
        $display = "HKCU\\Software\\Classes\\$progId\\shell\\open\\command"

        if (-not $PSCmdlet.ShouldProcess($display, "寫入含 $Flag 的開啟指令")) {
            continue
        }

        try {
            if (-not $registryMap.ContainsKey($progId)) {
                $regDir = Join-Path $BackupRoot 'registry'
                if (-not (Test-Path -LiteralPath $regDir)) {
                    New-Item -ItemType Directory -Path $regDir -Force | Out-Null
                }
                $backupFile = Join-Path $regDir ($progId + '.txt')
                $originalToStore = if ($hkcuExists) { [string]$hkcuValue } else { [string]$sourceValue }
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($backupFile, $originalToStore, $utf8NoBom)
                $entry = [pscustomobject]@{
                    progId            = $progId
                    hkcuExisted       = $hkcuExists
                    originalValue     = $originalToStore
                    backup            = $backupFile
                }
                $registryItems += $entry
                $registryMap[$progId] = $entry
            }

            Set-HkcuCommandValue -ProgId $progId -Value $newValue
            Write-Host "  已更新：$display"
            $changed++
        }
        catch {
            Write-Warning "無法寫入 $display（$($_.Exception.Message)）"
            $failed++
        }
    }

    if ($PSCmdlet.ShouldProcess($ManifestPath, '寫入備份清單')) {
        $manifest.shortcuts = @($shortcutItems)
        $manifest.registry = @($registryItems)
        if ($null -eq $manifest.createdAt) {
            $manifest.createdAt = (Get-Date).ToString('o')
        }
        Write-Manifest $manifest
        Write-Host "備份位置：$BackupRoot"
    }

    Write-Host ""
    Write-Host ("完成。更新 {0} 項，略過 {1} 項，失敗 {2} 項。" -f $changed, $skipped, $failed)
    Write-Host "請完全結束 Chrome（系統匣的圖示也要結束），再重新打開。"
    Write-Host "確認方式：在 Chrome 網址列開 chrome://version，命令列應包含 $Flag"
}

function Invoke-Uninstall {
    $manifest = Read-Manifest
    $restored = 0
    $stripped = 0
    $failed = 0

    if ($null -ne $manifest) {
        Write-Host "依備份還原…"
        foreach ($item in @($manifest.shortcuts)) {
            $path = [string]$item.path
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($path, '還原捷徑')) {
                continue
            }
            try {
                $backup = [string]$item.backup
                if ($backup -and (Test-Path -LiteralPath $backup)) {
                    if (Test-Path -LiteralPath $path) {
                        Copy-Item -LiteralPath $backup -Destination $path -Force
                    }
                    else {
                        Copy-Item -LiteralPath $backup -Destination $path -Force
                    }
                    Write-Host "  已還原捷徑：$path"
                    $restored++
                }
                elseif (Test-Path -LiteralPath $path) {
                    $info = Get-ShortcutData $path
                    if ($null -ne $info -and (Test-HasFlag $info.Arguments)) {
                        Set-ShortcutArguments -Path $path -Arguments (Remove-FlagFromText $info.Arguments)
                        Write-Host "  備份遺失，已從捷徑移除參數：$path"
                        $stripped++
                    }
                }
                else {
                    Write-Warning "  找不到捷徑，也沒有備份檔：$path"
                }
            }
            catch {
                Write-Warning "無法還原捷徑：$path（$($_.Exception.Message)）"
                $failed++
            }
        }

        foreach ($item in @($manifest.registry)) {
            $progId = [string]$item.progId
            if ([string]::IsNullOrWhiteSpace($progId)) {
                continue
            }
            $display = "HKCU\\Software\\Classes\\$progId\\shell\\open\\command"
            if (-not $PSCmdlet.ShouldProcess($display, '還原開啟指令')) {
                continue
            }
            try {
                $existed = $false
                if ($item.PSObject.Properties.Name -contains 'hkcuExisted') {
                    $existed = [bool]$item.hkcuExisted
                }
                if (-not $existed) {
                    Remove-HkcuCommandKey -ProgId $progId
                    Write-Host "  已移除我們建立的覆寫：$display"
                    $restored++
                }
                else {
                    $original = [string]$item.originalValue
                    if ($item.backup -and (Test-Path -LiteralPath $item.backup)) {
                        $original = [System.IO.File]::ReadAllText([string]$item.backup)
                    }
                    Set-HkcuCommandValue -ProgId $progId -Value $original
                    Write-Host "  已還原：$display"
                    $restored++
                }
            }
            catch {
                Write-Warning "無法還原 $display（$($_.Exception.Message)）"
                $failed++
            }
        }
    }
    else {
        Write-Host "找不到備份清單（$ManifestPath），改為直接移除參數。"
        foreach ($path in Get-ChromeShortcutPaths) {
            $info = Get-ShortcutData $path
            if ($null -eq $info) {
                $failed++
                continue
            }
            if (-not (Test-HasFlag $info.Arguments)) {
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($path, "從捷徑移除 $Flag")) {
                continue
            }
            try {
                Set-ShortcutArguments -Path $path -Arguments (Remove-FlagFromText $info.Arguments)
                Write-Host "  已移除參數：$path"
                $stripped++
            }
            catch {
                Write-Warning "無法更新捷徑：$path（$($_.Exception.Message)）"
                $failed++
            }
        }

        foreach ($progId in Get-ChromeHtmlProgIds) {
            $hkcuValue = Get-RegistryCommandValue -Hive HKCU -ProgId $progId
            if ([string]::IsNullOrWhiteSpace($hkcuValue) -or -not (Test-HasFlag $hkcuValue)) {
                continue
            }
            $display = "HKCU\\Software\\Classes\\$progId\\shell\\open\\command"
            $strippedValue = Remove-FlagFromText $hkcuValue
            $hklmValue = Get-RegistryCommandValue -Hive HKLM -ProgId $progId
            if (-not $PSCmdlet.ShouldProcess($display, "還原開啟指令")) {
                continue
            }
            try {
                if ($hklmValue -and ((Remove-FlagFromText $hkcuValue) -eq $hklmValue)) {
                    Remove-HkcuCommandKey -ProgId $progId
                    Write-Host "  已移除與系統預設相同的覆寫：$display"
                }
                else {
                    Set-HkcuCommandValue -ProgId $progId -Value $strippedValue
                    Write-Host "  已從覆寫移除參數：$display"
                }
                $stripped++
            }
            catch {
                Write-Warning "無法更新 $display（$($_.Exception.Message)）"
                $failed++
            }
        }
    }

    Write-Host ""
    Write-Host ("完成。還原 {0} 項，移除參數 {1} 項，失敗 {2} 項。" -f $restored, $stripped, $failed)
    Write-Host "請完全結束 Chrome 後再打開，變更才會生效。"
}

function Invoke-Status {
    $shortcutPaths = Get-ChromeShortcutPaths
    $progIds = Get-ChromeHtmlProgIds
    $withFlag = 0
    $withoutFlag = 0

    Write-Host "捷徑"
    if ($shortcutPaths.Count -eq 0) {
        Write-Host "  （沒有找到指向 chrome.exe 的捷徑）"
    }
    foreach ($path in $shortcutPaths) {
        $info = Get-ShortcutData $path
        if ($null -eq $info) {
            Write-Host "  [?]  $path"
            Write-Host "      無法讀取"
            continue
        }
        if (Test-HasFlag $info.Arguments) {
            Write-Host "  [已加上]  $path"
            $withFlag++
        }
        else {
            Write-Host "  [未加上]  $path"
            $withoutFlag++
        }
        $argDisplay = $info.Arguments
        if ([string]::IsNullOrWhiteSpace($argDisplay)) {
            $argDisplay = '（沒有引數）'
        }
        Write-Host "            $argDisplay"
    }

    Write-Host ""
    Write-Host "開啟指令（點連結時用來打開 Chrome 的那個）"
    if ($progIds.Count -eq 0) {
        Write-Host "  （找不到 ChromeHTML 等登錄項目）"
    }
    foreach ($progId in $progIds) {
        $hkcuExists = Test-HkcuCommandKeyExists $progId
        $effective = Get-EffectiveCommand -ProgId $progId
        $source = if ($hkcuExists) { 'HKCU' } else { 'HKLM（系統預設，尚未覆寫）' }
        if (Test-HasFlag $effective) {
            Write-Host "  [已加上]  $progId（$source）"
            $withFlag++
        }
        else {
            Write-Host "  [未加上]  $progId（$source）"
            $withoutFlag++
        }
        if ($effective) {
            Write-Host "            $effective"
        }
    }

    Write-Host ""
    if (Test-Path -LiteralPath $ManifestPath) {
        Write-Host "備份清單：$ManifestPath"
    }
    else {
        Write-Host "尚未建立備份清單。"
    }
    Write-Host ("目前已加上參數 {0} 項，尚未加上 {1} 項。" -f $withFlag, $withoutFlag)
}

switch ($Action) {
    'Install'   { Invoke-Install }
    'Uninstall' { Invoke-Uninstall }
    'Status'    { Invoke-Status }
}
