# Packages the extension into dist/ — one ZIP for Chromium stores/sideload,
# one identical ZIP renamed for Firefox (to be signed on addons.mozilla.org).
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root "dist"
$src = Join-Path $root "extension"

$manifest = Get-Content (Join-Path $src "manifest.json") -Raw | ConvertFrom-Json
$version = $manifest.version

New-Item -ItemType Directory -Force $dist | Out-Null
$chromiumZip = Join-Path $dist "CookieCleaner-$version-chromium.zip"
$firefoxZip = Join-Path $dist "CookieCleaner-$version-firefox.zip"

foreach ($zip in $chromiumZip, $firefoxZip) {
    if (Test-Path $zip) { Remove-Item $zip -Force }
}

Compress-Archive -Path (Join-Path $src "*") -DestinationPath $chromiumZip
Copy-Item $chromiumZip $firefoxZip

Write-Host "Built:"
Write-Host "  $chromiumZip"
Write-Host "  $firefoxZip  (submit to addons.mozilla.org for signing)"
