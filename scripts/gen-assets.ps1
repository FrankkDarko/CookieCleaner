# Generates all CookieCleaner visual assets with WPF vector rendering:
#   extension/icons/icon{16,32,48,128}.png   — extension + toolbar icons
#   assets/banner.png                        — README header (1200x300)
#   assets/store/store-icon-128.png          — Chrome Web Store icon (96px art in 128 canvas)
#   assets/store/promo-small-440x280.png     — Chrome Web Store small promo tile
#   assets/store/promo-marquee-1400x560.png  — Chrome Web Store marquee
Add-Type -AssemblyName PresentationCore, WindowsBase

$root = Split-Path $PSScriptRoot -Parent
$iconDir = Join-Path $root "extension\icons"
$assetDir = Join-Path $root "assets"
$storeDir = Join-Path $assetDir "store"
New-Item -ItemType Directory -Force $iconDir, $assetDir, $storeDir | Out-Null

function C([string]$hex) { [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }

function New-Grad([string]$c1, [string]$c2) {
    $b = New-Object System.Windows.Media.LinearGradientBrush
    $b.StartPoint = New-Object System.Windows.Point(0, 0)
    $b.EndPoint = New-Object System.Windows.Point(1, 1)
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((C $c1), 0)))
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop((C $c2), 1)))
    $b.Freeze()
    return $b
}

function New-Solid([string]$hex) {
    $b = New-Object System.Windows.Media.SolidColorBrush((C $hex))
    $b.Freeze()
    return $b
}

$bgBrush     = New-Grad "#2E3345" "#12141C"
$cookieBrush = New-Grad "#F0BC72" "#C9853F"
$edgeBrush   = New-Solid "#9A6630"
$chipBrush   = New-Solid "#4A2E14"
$shieldBrush = New-Grad "#41C27C" "#1E7A49"
$shieldEdge  = New-Solid "#141821"
$whiteBrush  = New-Solid "#FFFFFF"
$amberBrush  = New-Solid "#E0A458"
$mutedBrush  = New-Solid "#9AA1B0"

$sparklePath = "M 0,-7 C 1.2,-1.2 1.2,-1.2 7,0 C 1.2,1.2 1.2,1.2 0,7 C -1.2,1.2 -1.2,1.2 -7,0 C -1.2,-1.2 -1.2,-1.2 0,-7 Z"

# Draws the logo into a square of $s pixels at ($x,$y); design space is 100x100.
function Draw-Logo($dc, [double]$x, [double]$y, [double]$s) {
    $dc.PushTransform((New-Object System.Windows.Media.TranslateTransform($x, $y)))
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform(($s / 100), ($s / 100))))

    # rounded-square background
    $dc.DrawRoundedRectangle($bgBrush, $null, (New-Object System.Windows.Rect(0, 0, 100, 100)), 22, 22)

    # cookie with a bite taken out (top right)
    $cookie = New-Object System.Windows.Media.EllipseGeometry((New-Object System.Windows.Point(46, 46)), 30, 30)
    $bite = New-Object System.Windows.Media.EllipseGeometry((New-Object System.Windows.Point(72, 20)), 13, 13)
    $bitten = [System.Windows.Media.Geometry]::Combine($cookie, $bite, [System.Windows.Media.GeometryCombineMode]::Exclude, $null)
    $edgePen = New-Object System.Windows.Media.Pen($edgeBrush, 3)
    $dc.DrawGeometry($cookieBrush, $edgePen, $bitten)

    # chocolate chips
    foreach ($p in @(@(35, 34, 5), @(56, 31, 4.5), @(30, 55, 4.5), @(47, 47, 4), @(42, 66, 4))) {
        $dc.DrawEllipse($chipBrush, $null, (New-Object System.Windows.Point($p[0], $p[1])), $p[2], $p[2])
    }

    # crumbs flying off the bite
    $dc.DrawEllipse($amberBrush, $null, (New-Object System.Windows.Point(85, 16)), 2.2, 2.2)
    $dc.DrawEllipse($amberBrush, $null, (New-Object System.Windows.Point(80, 30)), 1.5, 1.5)

    # sparkle (bottom left)
    $dc.PushTransform((New-Object System.Windows.Media.TranslateTransform(15, 83)))
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform(0.8, 0.8)))
    $dc.DrawGeometry($whiteBrush, $null, [System.Windows.Media.Geometry]::Parse($sparklePath))
    $dc.Pop(); $dc.Pop()

    # shield with check (bottom right)
    $dc.PushTransform((New-Object System.Windows.Media.TranslateTransform(57, 51)))
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform(1.45, 1.45)))
    $shield = [System.Windows.Media.Geometry]::Parse("M12,0 L24,5 L24,14 C24,22 18,26 12,28 C6,26 0,22 0,14 L0,5 Z")
    $shieldPen = New-Object System.Windows.Media.Pen($shieldEdge, 1.8)
    $dc.DrawGeometry($shieldBrush, $shieldPen, $shield)
    $checkPen = New-Object System.Windows.Media.Pen($whiteBrush, 3)
    $checkPen.StartLineCap = "Round"; $checkPen.EndLineCap = "Round"; $checkPen.LineJoin = "Round"
    $check = [System.Windows.Media.Geometry]::Parse("M6.5,14 L10.5,18 L17.5,9.5")
    $dc.DrawGeometry($null, $checkPen, $check)
    $dc.Pop(); $dc.Pop()

    $dc.Pop(); $dc.Pop()
}

function New-Text([string]$text, [double]$size, $brush, [bool]$bold = $true) {
    $weight = if ($bold) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::Normal }
    $tf = New-Object System.Windows.Media.Typeface(
        (New-Object System.Windows.Media.FontFamily("Segoe UI")),
        [System.Windows.FontStyles]::Normal, $weight, [System.Windows.FontStretches]::Normal)
    New-Object System.Windows.Media.FormattedText(
        $text, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight, $tf, $size, $brush, 1.0)
}

# Draws "CookieCleaner" (two-tone) centered horizontally if $centerWidth > 0, else at $x. Returns total width.
function Draw-Wordmark($dc, [double]$size, [double]$x, [double]$y, [double]$centerWidth = 0) {
    $t1 = New-Text "Cookie" $size $whiteBrush
    $t2 = New-Text "Cleaner" $size $amberBrush
    $total = $t1.WidthIncludingTrailingWhitespace + $t2.WidthIncludingTrailingWhitespace
    if ($centerWidth -gt 0) { $x = ($centerWidth - $total) / 2 }
    $dc.DrawText($t1, (New-Object System.Windows.Point($x, $y)))
    $dc.DrawText($t2, (New-Object System.Windows.Point(($x + $t1.WidthIncludingTrailingWhitespace), $y)))
    return $total
}

function Draw-CenteredText($dc, [string]$text, [double]$size, $brush, [double]$y, [double]$canvasWidth, [bool]$bold = $false) {
    $ft = New-Text $text $size $brush $bold
    $x = ($canvasWidth - $ft.WidthIncludingTrailingWhitespace) / 2
    $dc.DrawText($ft, (New-Object System.Windows.Point($x, $y)))
}

function Render-Png([int]$w, [int]$h, [scriptblock]$draw, [string]$path) {
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    & $draw $dc
    $dc.Close()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [System.IO.File]::Open($path, 'Create')
    $enc.Save($fs)
    $fs.Close()
    Write-Host "  $path"
}

Write-Host "Generating assets:"

# --- extension icons (full-bleed logo) ---
foreach ($s in 16, 32, 48, 128) {
    Render-Png $s $s { param($dc) Draw-Logo $dc 0 0 $s }.GetNewClosure() (Join-Path $iconDir "icon$s.png")
}

# --- Chrome Web Store icon: 96px of art centered in a 128 canvas ---
Render-Png 128 128 { param($dc) Draw-Logo $dc 16 16 96 } (Join-Path $storeDir "store-icon-128.png")

# --- localized banners & promo tiles (fr = default filenames, en = "-en" suffix) ---
$locales = @(
    @{
        suffix       = ""
        promoTag     = "Nettoyage automatique de cookies"
        marqueeTag   = "Vos sessions sensibles, nettoyées automatiquement."
        marqueeSub   = "Gratuit · Open-source · Zéro télémétrie"
        bannerTag    = "Anti-vol de cookies — nettoyage automatique de vos sessions"
        bannerSub    = "Gratuit · Open-source · Chrome & Firefox"
    },
    @{
        suffix       = "-en"
        promoTag     = "Automatic cookie cleanup"
        marqueeTag   = "Your sensitive sessions, cleaned automatically."
        marqueeSub   = "Free · Open-source · Zero telemetry"
        bannerTag    = "Anti cookie-theft — automatic cleanup of your sessions"
        bannerSub    = "Free · Open-source · Chrome & Firefox"
    }
)

foreach ($loc in $locales) {
    $sfx = $loc.suffix

    # small promo tile 440x280
    Render-Png 440 280 {
        param($dc)
        $dc.DrawRectangle($bgBrush, $null, (New-Object System.Windows.Rect(0, 0, 440, 280)))
        Draw-Logo $dc 165 28 110
        Draw-Wordmark $dc 36 0 152 440 | Out-Null
        Draw-CenteredText $dc $loc.promoTag 16 $mutedBrush 210 440
    }.GetNewClosure() (Join-Path $storeDir "promo-small-440x280$sfx.png")

    # marquee 1400x560
    Render-Png 1400 560 {
        param($dc)
        $dc.DrawRectangle($bgBrush, $null, (New-Object System.Windows.Rect(0, 0, 1400, 560)))
        Draw-Logo $dc 140 140 280
        Draw-Wordmark $dc 96 520 160 | Out-Null
        $t = New-Text $loc.marqueeTag 34 $mutedBrush $false
        $dc.DrawText($t, (New-Object System.Windows.Point(526, 316)))
        $t2 = New-Text $loc.marqueeSub 28 $amberBrush
        $dc.DrawText($t2, (New-Object System.Windows.Point(526, 380)))
    }.GetNewClosure() (Join-Path $storeDir "promo-marquee-1400x560$sfx.png")

    # README banner 1200x300
    Render-Png 1200 300 {
        param($dc)
        $dc.DrawRectangle($bgBrush, $null, (New-Object System.Windows.Rect(0, 0, 1200, 300)))
        Draw-Logo $dc 85 55 190
        Draw-Wordmark $dc 74 330 70 | Out-Null
        $t = New-Text $loc.bannerTag 28 $mutedBrush $false
        $dc.DrawText($t, (New-Object System.Windows.Point(336, 180)))
        $t2 = New-Text $loc.bannerSub 22 $amberBrush
        $dc.DrawText($t2, (New-Object System.Windows.Point(336, 228)))
    }.GetNewClosure() (Join-Path $assetDir "banner$sfx.png")
}

Write-Host "Done."
