[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$androidJbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path -LiteralPath $androidJbr) {
    $env:JAVA_HOME = $androidJbr
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

flutter pub get
flutter analyze
flutter test

Push-Location -LiteralPath (Join-Path $root 'functions')
try {
    npm.cmd ci
    npm.cmd run lint
    npm.cmd run build
    npm.cmd test
    npm.cmd run test:rules
    npm.cmd run test:functions
}
finally {
    Pop-Location
}

Write-Host 'TajGo v1.8 local Flutter, Rules, Functions, and integration checks passed.'
