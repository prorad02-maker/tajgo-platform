# TajGo v1.8 — local smoke test (PowerShell).
# Runs Flutter analyze/test and the full Functions + Rules emulator suite.
# Does NOT touch production Firebase (emulator project demo-tajgo only).
#
# Requires: Flutter, Node/npm, Firebase CLI, JDK 21+ (Firebase CLI requirement).
# Set JAVA_HOME to a JDK 21+ (e.g. Android Studio jbr).

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
. (Join-Path $PSScriptRoot 'native_command.ps1')

if (-not $env:JAVA_HOME) {
    $jbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
}
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

Write-Host '== Flutter analyze ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter analyze

Write-Host '== Flutter test ==' -ForegroundColor Cyan
Invoke-TajGoCommand flutter test --no-pub

Write-Host '== Functions unit + rules + integration (emulator) ==' -ForegroundColor Cyan
Push-Location functions
try {
    Invoke-TajGoCommand npm.cmd ci
    Invoke-TajGoCommand npm.cmd run test:core
} finally {
    Pop-Location
}

Write-Host "`nSmoke test complete." -ForegroundColor Green
