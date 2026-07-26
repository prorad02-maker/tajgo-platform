[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('indexes', 'rules')]
    [string]$Target,
    [Parameter(Mandatory = $true)][string]$Confirmation
)

$ErrorActionPreference = 'Stop'
$expectedProject = 'tajgo-4fcd0'
$expectedConfirmation = "DEPLOY FIRESTORE $($Target.ToUpperInvariant()) tajgo-4fcd0"

if ($ProjectId -cne $expectedProject) {
    throw "Refusing deploy: expected project '$expectedProject', received '$ProjectId'."
}
if ($Confirmation -cne $expectedConfirmation) {
    throw "Refusing deploy. Re-run with -Confirmation '$expectedConfirmation'."
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$firebaseTarget = "firestore:$Target"
Write-Host "Will deploy ONLY $firebaseTarget to $ProjectId."
Write-Host 'No Firestore documents will be deleted by this script.'
firebase.cmd deploy --only $firebaseTarget --project $ProjectId
