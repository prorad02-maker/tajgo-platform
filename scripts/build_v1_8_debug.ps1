[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path -LiteralPath $apk)) {
    throw "Debug APK was not created at $apk."
}
$hash = Get-FileHash -LiteralPath $apk -Algorithm SHA256
Write-Host "APK: $apk"
Write-Host "SHA-256: $($hash.Hash)"
