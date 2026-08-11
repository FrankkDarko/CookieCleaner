# Packages the extension into dist/ — one ZIP for Chromium stores/sideload,
# one identical ZIP renamed for Firefox (to be signed on addons.mozilla.org).
#
# Note: Compress-Archive is NOT used on purpose — it writes backslash path
# separators inside the archive, which Mozilla's validator rejects
# ("Invalid file name in archive"). We build the ZIP manually with
# forward slashes, as the ZIP spec requires.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root "dist"
$src = (Resolve-Path (Join-Path $root "extension")).Path

$manifest = Get-Content (Join-Path $src "manifest.json") -Raw | ConvertFrom-Json
$version = $manifest.version

New-Item -ItemType Directory -Force $dist | Out-Null
$chromiumZip = Join-Path $dist "CookieCleaner-$version-chromium.zip"
$firefoxZip = Join-Path $dist "CookieCleaner-$version-firefox.zip"

function New-ExtensionZip([string]$sourceDir, [string]$zipPath) {
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        Get-ChildItem $sourceDir -Recurse -File | ForEach-Object {
            $entryName = $_.FullName.Substring($sourceDir.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $_.FullName, $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
}

New-ExtensionZip $src $chromiumZip
Copy-Item $chromiumZip $firefoxZip -Force

Write-Host "Built:"
Write-Host "  $chromiumZip"
Write-Host "  $firefoxZip  (submit to addons.mozilla.org for signing)"
