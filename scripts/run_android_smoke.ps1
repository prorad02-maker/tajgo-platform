param(
    [string]$Device = 'emulator-5554',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build\android-smoke'),
    [string]$Flutter = 'flutter.bat'
)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if ($Device -notmatch '^emulator-\d+$' -or (& $adb -s $Device shell getprop ro.kernel.qemu).Trim() -ne '1') {
    throw 'Use a dedicated Android emulator. This runner changes test-app permissions and mock GPS.'
}
$response = Invoke-WebRequest 'http://127.0.0.1:9099/emulator/v1/projects/demo-tajgo-android/verificationCodes' -TimeoutSec 5
if ($response.StatusCode -ne 200) { throw 'Start the local Auth emulator first; see docs/ANDROID_NATIVE_QA.md.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = (Resolve-Path $OutputDirectory).Path
$log = Join-Path $OutputDirectory 'android-native-test.log'
[System.IO.File]::WriteAllText($log, '')
$job = Start-Job -ArgumentList $repoPath,$Flutter,$Device,$log -ScriptBlock {
    param($repoPath,$flutter,$device,$log)
    Set-Location $repoPath
    # Keep builds within the memory available alongside the virtual phone.
    $env:JAVA_OPTS = '-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2'
    # Regenerate debug plugin registration even after a preceding release build.
    & $flutter --no-version-check test integration_test/android_native_test.dart -d $device --dart-define=TAJGO_NATIVE_SMOKE=true --dart-define=TAJGO_ENV=production 2>&1 |
        ForEach-Object { Add-Content -LiteralPath $log -Value $_.ToString() -Encoding utf8 }
    if ($LASTEXITCODE -ne 0) { throw "Android test failed ($LASTEXITCODE). Read $log" }
}
$seen = @{}
$deadline = (Get-Date).AddMinutes(15)
try {
    while ($job.State -eq 'Running') {
        if ((Get-Date) -gt $deadline) { throw 'Android smoke check exceeded 15 minutes.' }
        [string]$content = if (Test-Path -LiteralPath $log) { Get-Content -Raw -LiteralPath $log } else { '' }
        foreach ($phase in @('capture-sms','denied','disabled','granted','capture-map')) {
            if (!$seen[$phase] -and $null -ne $content -and $content.Contains("TAJGO_NATIVE_GATE:$phase")) {
                $seen[$phase] = $true
                if ($phase.StartsWith('capture-')) {
                    $focus = (& $adb -s $Device shell dumpsys window) -join "`n"
                    if ($focus -notmatch 'mCurrentFocus=.*tj\.tajgo\.app/') {
                        throw 'A system window obscures TajGo. Close it on the dedicated emulator and repeat the check.'
                    }
                    $imageName = 'android-native-' + $phase.Substring(8) + '.png'
                    & $adb -s $Device shell screencap -p "/sdcard/$imageName"
                    & $adb -s $Device pull "/sdcard/$imageName" (Join-Path $OutputDirectory $imageName) 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "Could not save $imageName" }
                } elseif ($phase -eq 'denied') {
                    & $adb -s $Device shell cmd location set-location-enabled true | Out-Null
                    foreach ($permission in @('ACCESS_FINE_LOCATION','ACCESS_COARSE_LOCATION')) {
                        & $adb -s $Device shell pm revoke tj.tajgo.app "android.permission.$permission" 2>$null
                        & $adb -s $Device shell pm set-permission-flags tj.tajgo.app "android.permission.$permission" user-set user-fixed
                    }
                } elseif ($phase -eq 'disabled') {
                    & $adb -s $Device shell cmd location set-location-enabled false | Out-Null
                } else {
                    & $adb -s $Device shell cmd location set-location-enabled true | Out-Null
                    foreach ($permission in @('ACCESS_COARSE_LOCATION','ACCESS_FINE_LOCATION')) {
                        & $adb -s $Device shell pm clear-permission-flags tj.tajgo.app "android.permission.$permission" user-set user-fixed
                        & $adb -s $Device shell pm grant tj.tajgo.app "android.permission.$permission"
                    }
                }
                & $adb -s $Device shell run-as tj.tajgo.app touch "cache/tajgo-native-$phase.ready"
                if ($LASTEXITCODE -ne 0) { throw "Could not acknowledge Android state: $phase" }
                Write-Host "Android state applied: $phase"
            }
        }
        if ($seen['granted']) { & $adb -s $Device emu geo fix 69.6222 40.2833 300 12 | Out-Null }
        Start-Sleep -Milliseconds 500
    }
    Receive-Job $job -ErrorAction Stop
    if ($job.State -ne 'Completed') { throw 'Android check did not complete.' }
    Get-Content -LiteralPath $log -Tail 15
} finally {
    if ($job.State -eq 'Running') { Stop-Job $job }
    Remove-Job $job -Force
    & $adb -s $Device shell cmd location set-location-enabled true | Out-Null
}
