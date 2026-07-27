# TajGo — Android release build (PowerShell).
# Builds release APK + AAB and prints SHA-256 checksums.
# If android/key.properties is absent, artifacts are DEBUG-SIGNED (not for store).
#
# Usage:  ./scripts/build_android_release.ps1
# Requires: Flutter on PATH, JAVA_HOME set to a JDK 17+.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host '== flutter clean / pub get ==' -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host '== flutter analyze ==' -ForegroundColor Cyan
flutter analyze

Write-Host '== flutter test ==' -ForegroundColor Cyan
flutter test

Write-Host '== build release APK ==' -ForegroundColor Cyan
flutter build apk --release

Write-Host '== build release AAB ==' -ForegroundColor Cyan
flutter build appbundle --release

$apk = 'build/app/outputs/flutter-apk/app-release.apk'
$aab = 'build/app/outputs/bundle/release/app-release.aab'

foreach ($artifact in @($apk, $aab)) {
    if (Test-Path $artifact) {
        $hash = (Get-FileHash -Algorithm SHA256 $artifact).Hash
        $size = (Get-Item $artifact).Length
        Write-Host "`n$artifact" -ForegroundColor Green
        Write-Host "  size:   $size bytes"
        Write-Host "  sha256: $hash"
    } else {
        Write-Warning "$artifact not found"
    }
}

if (-not (Test-Path 'android/key.properties')) {
    Write-Warning 'android/key.properties missing -> artifacts are DEBUG-SIGNED (not production).'
}
