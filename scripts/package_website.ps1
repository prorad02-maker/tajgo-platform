# Static hosting package; no account credentials or application source are included.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'native_command.ps1')
Invoke-TajGoCommand node (Join-Path $PSScriptRoot 'version_website_assets.mjs')
Invoke-TajGoCommand node (Join-Path $PSScriptRoot 'check_website.mjs')
$output = Join-Path $root 'build/release'
$site = Join-Path $output ('tajgo-site-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $site -Force | Out-Null
Copy-Item -Path (Join-Path $root 'public/*') -Destination $site
# Directory indexes preserve /privacy etc. on ordinary static web servers.
foreach ($page in @('privacy', 'terms', 'support', 'account-deletion')) {
    $directory = Join-Path $site $page
    New-Item -ItemType Directory -Path $directory | Out-Null
    Move-Item -LiteralPath (Join-Path $site "$page.html") -Destination (Join-Path $directory 'index.html')
}
$archive = "$site.zip"
Compress-Archive -Path (Join-Path $site '*') -DestinationPath $archive
Write-Host "Website ZIP: $archive"
Get-FileHash -LiteralPath $archive -Algorithm SHA256
