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
Push-Location -LiteralPath (Join-Path $root 'functions')
try {
    npm.cmd ci
    npm.cmd run lint
    npm.cmd test
}
finally {
    Pop-Location
}

Write-Host "Will deploy ONLY Cloud Functions to $ProjectId."
Write-Host 'No Firestore documents will be deleted by this script.'
firebase.cmd deploy --only functions --project $ProjectId
