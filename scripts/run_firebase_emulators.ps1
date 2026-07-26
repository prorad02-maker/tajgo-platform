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

Push-Location -LiteralPath (Join-Path $root 'functions')
try {
    npm.cmd ci
    npm.cmd run lint
    npm.cmd run build
}
finally {
    Pop-Location
}

Write-Host 'Starting local-only TajGo emulators with demo project demo-tajgo.'
firebase.cmd emulators:start --only auth,firestore,functions --project demo-tajgo
