# Turns raw captures into Chrome Web Store screenshots (1280x800, no alpha).
# Usage:
#   1. Save raw captures (any size) into store-shots/raw/
#   2. powershell -File scripts/make-screenshots.ps1
#   3. Results land in assets/store/screenshots/
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$rawDir = Join-Path $root "store-shots\raw"
$outDir = Join-Path $root "assets\store\screenshots"
New-Item -ItemType Directory -Force $rawDir, $outDir | Out-Null

$W = 1280; $H = 800
$marginX = 90; $marginTop = 90; $marginBottom = 70

$raws = Get-ChildItem $rawDir -File -Include *.png, *.jpg, *.jpeg -Recurse
if (-not $raws) {
    Write-Host "Aucune image dans $rawDir"
    Write-Host "Depose tes captures brutes (popup, options...) dans ce dossier puis relance le script."
    exit 0
}

function New-RoundedPath([System.Drawing.RectangleF]$r, [float]$rad) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $rad * 2
    $p.AddArc($r.X, $r.Y, $d, $d, 180, 90)
    $p.AddArc($r.Right - $d, $r.Y, $d, $d, 270, 90)
    $p.AddArc($r.Right - $d, $r.Bottom - $d, $d, $d, 0, 90)
    $p.AddArc($r.X, $r.Bottom - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

foreach ($raw in $raws) {
    $src = [System.Drawing.Image]::FromFile($raw.FullName)

    # 24bpp = no alpha channel (the Web Store rejects transparency)
    $bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # background gradient
    $bgRect = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bgRect,
        [System.Drawing.Color]::FromArgb(255, 46, 51, 69),
        [System.Drawing.Color]::FromArgb(255, 18, 20, 28),
        35.0)
    $g.FillRectangle($bg, $bgRect)

    # wordmark top-left
    $fontB = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $amber = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 224, 164, 88))
    $g.DrawString("Cookie", $fontB, $white, 34, 26)
    $sz = $g.MeasureString("Cookie", $fontB)
    $g.DrawString("Cleaner", $fontB, $amber, 34 + $sz.Width - 8, 26)

    # fit the capture into the safe area (never upscale beyond 2x)
    $maxW = $W - 2 * $marginX
    $maxH = $H - $marginTop - $marginBottom
    $scale = [Math]::Min([Math]::Min($maxW / $src.Width, $maxH / $src.Height), 2.0)
    $dw = [int]($src.Width * $scale)
    $dh = [int]($src.Height * $scale)
    $dx = [int](($W - $dw) / 2)
    $dy = [int]($marginTop + ($maxH - $dh) / 2)

    # soft shadow
    for ($i = 5; $i -ge 1; $i--) {
        $sr = New-Object System.Drawing.RectangleF(($dx - $i), ($dy - $i + 4), ($dw + 2 * $i), ($dh + 2 * $i))
        $sp = New-RoundedPath $sr (14 + $i)
        $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb((14 - $i), 0, 0, 0))
        $g.FillPath($sb, $sp)
        $sp.Dispose()
    }

    # capture with rounded corners + border
    $rect = New-Object System.Drawing.RectangleF($dx, $dy, $dw, $dh)
    $path = New-RoundedPath $rect 12
    $g.SetClip($path)
    $g.DrawImage($src, $dx, $dy, $dw, $dh)
    $g.ResetClip()
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 46, 50, 61), 2)
    $g.DrawPath($pen, $path)

    $g.Dispose()
    $out = Join-Path $outDir ("screenshot-" + [System.IO.Path]::GetFileNameWithoutExtension($raw.Name) + "-1280x800.png")
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $src.Dispose()
    Write-Host "  $out"
}
Write-Host "Termine — images pretes pour le Chrome Web Store."
