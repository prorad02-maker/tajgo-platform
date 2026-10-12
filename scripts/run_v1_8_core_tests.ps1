[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
. (Join-Path $PSScriptRoot 'native_command.ps1')

$androidJbr = 'C:\Program Files\Android\Android Studio\jbr'
if (Test-Path -LiteralPath $androidJbr) {
    $env:JAVA_HOME = $androidJbr
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

Invoke-TajGoCommand flutter pub get --enforce-lockfile
Invoke-TajGoCommand flutter analyze --no-pub
Invoke-TajGoCommand flutter test --no-pub

Push-Location -LiteralPath (Join-Path $root 'functions')
try {
    Invoke-TajGoCommand npm.cmd ci
    Invoke-TajGoCommand npm.cmd run lint
    Invoke-TajGoCommand npm.cmd run build
    Invoke-TajGoCommand npm.cmd test
    Invoke-TajGoCommand npm.cmd run test:rules
    Invoke-TajGoCommand npm.cmd run test:functions
}
finally {
    Pop-Location
}

Write-Host 'TajGo v1.8 local Flutter, Rules, Functions, and integration checks passed.'
