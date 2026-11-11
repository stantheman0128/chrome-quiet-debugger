#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$main = Join-Path $PSScriptRoot 'ChromeQuietDebugger.ps1'
& $main -Action Install @PSBoundParameters
