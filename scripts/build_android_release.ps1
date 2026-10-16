# TajGo — Android release build (PowerShell).
# Builds release APK + AAB and prints SHA-256 checksums.
# Requires a configured upload key. Debug signing fallback is forbidden.
#
# Usage:  ./scripts/build_android_release.ps1
# Requires: Flutter on PATH, JAVA_HOME set to a JDK 17+.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'native_command.ps1')

if (-not (Test-Path -LiteralPath 'android/key.properties')) {
    throw 'Release signing is missing. Follow RELEASE_SIGNING_SETUP.md before building.'
}

Write-Host '== flutter clean / pub get ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter clean
Invoke-TajGoCommand flutter pub get --enforce-lockfile

Write-Host '== flutter analyze ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter analyze --no-pub

Write-Host '== flutter test ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter test --no-pub

Write-Host '== build release APK ==' -ForegroundColor Cyan
# Let Flutter regenerate release plugin registration after debug/native tests.
# --no-pub reuses the debug registrant, which includes integration_test even
# though Gradle correctly excludes dev plugins from release dependencies.
Invoke-TajGoCommand flutter build apk --release --dart-define=TAJGO_ENV=production --dart-define=TAJGO_FF_NOTIFICATIONS=true --dart-define=TAJGO_FF_CRASH=true

Write-Host '== build release AAB ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter build appbundle --release --dart-define=TAJGO_ENV=production --dart-define=TAJGO_FF_NOTIFICATIONS=true --dart-define=TAJGO_FF_CRASH=true

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
        throw "$artifact not found"
    }
}
