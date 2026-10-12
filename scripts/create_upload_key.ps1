# First Play upload only. Existing keystores are preserved.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
if (-not (Test-Path -LiteralPath $keytool)) {
    throw 'Android Studio keytool was not found.'
}

Write-Host 'Password input is visible on this local screen. Do not share screenshots.'
$password = Read-Host 'New password (at least 8 ASCII characters, no spaces)'
if ($password.Length -lt 8 -or $password -notmatch '^[\x21-\x7E]+$') {
    throw 'Use at least 8 ASCII characters without spaces.'
}
$confirmation = Read-Host 'Repeat password'
if ($password -cne $confirmation) { throw 'Passwords do not match.' }

$directory = Join-Path $env:USERPROFILE 'TajGo-signing'
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$keystore = Join-Path $directory ('tajgo-upload-' + [guid]::NewGuid().ToString('N') + '.jks')
try {
    # Environment options keep the password out of process command-line arguments.
    $env:TAJGO_UPLOAD_KEY_PASSWORD = $password
    & $keytool -genkeypair -v -keystore $keystore -storetype PKCS12 -alias tajgo-upload -keyalg RSA -keysize 2048 -validity 10000 -storepass:env TAJGO_UPLOAD_KEY_PASSWORD -keypass:env TAJGO_UPLOAD_KEY_PASSWORD -dname 'CN=TajGo Upload'
    if ($LASTEXITCODE -ne 0) { throw 'Key generation failed; signing configuration was not changed.' }

    # Java .properties requires literal backslashes to be escaped.
    $propertyPassword = $password.Replace('\', '\\')
    $lines = @(
        ('storeFile=' + $keystore.Replace('\', '/'))
        ('storePassword=' + $propertyPassword)
        'keyAlias=tajgo-upload'
        ('keyPassword=' + $propertyPassword)
    )
    $propertiesPath = Join-Path $root 'android/key.properties'
    if (Test-Path -LiteralPath $propertiesPath) {
        Copy-Item -LiteralPath $propertiesPath -Destination (Join-Path $directory ('key-properties-backup-' + [guid]::NewGuid().ToString('N') + '.properties'))
    }
    [System.IO.File]::WriteAllLines($propertiesPath, [string[]]$lines, [System.Text.Encoding]::ASCII)
    Write-Host "New upload key: $keystore"
    Write-Host 'android/key.properties configured. Back up the new key and its password.'
}
finally {
    Remove-Item Env:TAJGO_UPLOAD_KEY_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
    $confirmation = $null
    $propertyPassword = $null
}
