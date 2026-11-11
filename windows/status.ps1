#Requires -Version 5.1
[CmdletBinding()]
param()

$main = Join-Path $PSScriptRoot 'ChromeQuietDebugger.ps1'
& $main -Action Status
