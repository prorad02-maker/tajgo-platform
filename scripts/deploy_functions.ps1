[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$Confirmation
)

$ErrorActionPreference = 'Stop'
$expectedProject = 'tajgo-4fcd0'
$expectedConfirmation = 'DEPLOY FUNCTIONS tajgo-4fcd0'

if ($ProjectId -cne $expectedProject) {
    throw "Refusing deploy: expected project '$expectedProject', received '$ProjectId'."
}
if ($Confirmation -cne $expectedConfirmation) {
    throw "Refusing deploy. Re-run with -Confirmation '$expectedConfirmation'."
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
. (Join-Path $PSScriptRoot 'native_command.ps1')
Push-Location -LiteralPath (Join-Path $root 'functions')
try {
    Invoke-TajGoCommand npm.cmd ci
    Invoke-TajGoCommand npm.cmd run lint
    Invoke-TajGoCommand npm.cmd test
}
finally {
    Pop-Location
}

Write-Host "Will deploy ONLY Cloud Functions to $ProjectId."
Write-Host 'No Firestore documents will be deleted by this script.'
Invoke-TajGoCommand firebase.cmd deploy --only functions --project $ProjectId
