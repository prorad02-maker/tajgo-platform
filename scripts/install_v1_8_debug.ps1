[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DeviceId
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'

if (-not (Test-Path -LiteralPath $apk)) {
    throw "APK is missing. Run scripts/build_v1_8_debug.ps1 first."
}

$devices = flutter devices --machine | ConvertFrom-Json
if (-not ($devices | Where-Object { $_.id -eq $DeviceId })) {
    throw "Flutter device '$DeviceId' is not connected."
}

Write-Host "Installing TajGo debug APK on device '$DeviceId'."
flutter install --debug -d $DeviceId
