# PowerShell 5.1 does not turn native nonzero exit codes into terminating errors.
function Invoke-TajGoCommand {
    param([string]$Command)
    $Arguments = $args
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command '$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE."
    }
}
