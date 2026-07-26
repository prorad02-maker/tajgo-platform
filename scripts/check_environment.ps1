[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

function Show-ToolVersion {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' was not found in PATH."
    }
    & $Command
}

Write-Host "TajGo environment check: $root"
Show-ToolVersion -Name 'git' -Command { git --version }
Show-ToolVersion -Name 'flutter' -Command { flutter --version }
Show-ToolVersion -Name 'dart' -Command { dart --version }
Show-ToolVersion -Name 'node' -Command { node --version }
Show-ToolVersion -Name 'npm' -Command { npm.cmd --version }
Show-ToolVersion -Name 'firebase' -Command { firebase.cmd --version }
Show-ToolVersion -Name 'java' -Command { java -version }

$pubspec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
if ($pubspec -notmatch '(?m)^version:\s+1\.8\.0\+31\s*$') {
    throw 'pubspec.yaml must contain version 1.8.0+31.'
}

$gradle = Get-Content -LiteralPath 'android/app/build.gradle.kts' -Raw
if ($gradle -notmatch 'applicationId\s*=\s*"tj\.tajgo\.app"') {
    throw 'Android applicationId is not tj.tajgo.app.'
}

$firebaseOptions = Get-Content -LiteralPath 'lib/firebase_options.dart' -Raw
if ($firebaseOptions -notmatch 'tajgo-4fcd0') {
    throw 'firebase_options.dart does not reference tajgo-4fcd0.'
}

$trackedSecrets = git ls-files |
    Where-Object {
        $_ -match '(^|/)(key\.properties|.*\.jks|.*\.keystore|service-account.*\.json)$'
    }
if ($trackedSecrets) {
    throw "Potential release secret is tracked:`n$($trackedSecrets -join "`n")"
}

Write-Host 'Identity OK: project=tajgo-4fcd0, package=tj.tajgo.app, version=1.8.0+31'
Write-Host 'No tracked key.properties, keystore, or service-account file was found.'
flutter devices
