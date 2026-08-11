# Generates the "international" store screenshot (1280x800, no alpha):
# a showcase of the 5 supported languages.
# Output: assets/store/screenshots/screenshot-languages-1280x800.png
Add-Type -AssemblyName PresentationCore, WindowsBase, System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "assets\store\screenshots"
New-Item -ItemType Directory -Force $outDir | Out-Null
$outFile = Join-Path $outDir "screenshot-languages-1280x800.png"
$logoFile = Join-Path $root "extension\icons\icon128.png"

$W = 1280; $H = 800

function C([string]$hex) { [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
function New-Solid([string]$hex) { $b = New-Object System.Windows.Media.SolidColorBrush((C $hex)); $b.Freeze(); $b }

$whiteBrush = New-Solid "#FFFFFF"
$amberBrush = New-Solid "#E0A458"
$mutedBrush = New-Solid "#9AA1B0"
$panelBrush = New-Solid "#1D2027"
$borderPen = New-Object System.Windows.Media.Pen((New-Solid "#2E323D"), 1.5)

$bgBrush = New-Object System.Windows.Media.LinearGradientBrush
$bgBrush.StartPoint = New-Object System.Windows.Point(0, 0)
$bgBrush.EndPoint = New-Object System.Windows.Point(1, 1)
$bgBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop((C "#2E3345"), 0)))
$bgBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop((C "#12141C"), 1)))
$bgBrush.Freeze()

function New-Text([string]$text, [double]$size, $brush, [bool]$bold = $true) {
    $weight = if ($bold) { [System.Windows.FontWeights]::Bold } else { [System.Windows.FontWeights]::Normal }
    $tf = New-Object System.Windows.Media.Typeface(
        (New-Object System.Windows.Media.FontFamily("Segoe UI")),
        [System.Windows.FontStyles]::Normal, $weight, [System.Windows.FontStretches]::Normal)
    New-Object System.Windows.Media.FormattedText(
        $text, [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight, $tf, $size, $brush, 1.0)
}

$LANGS = @(
    @{ name = "Français";  tag = "Nettoyage automatique de cookies et de sessions" },
    @{ name = "English";   tag = "Automatic cookie & session cleaner" },
    @{ name = "Español";   tag = "Limpiador automático de cookies y sesiones" },
    @{ name = "Deutsch";   tag = "Automatischer Cookie- & Sitzungsbereiniger" },
    @{ name = "Italiano";  tag = "Pulitore automatico di cookie e sessioni" }
)

$dv = New-Object System.Windows.Media.DrawingVisual
$dc = $dv.RenderOpen()

# background
$dc.DrawRectangle($bgBrush, $null, (New-Object System.Windows.Rect(0, 0, $W, $H)))

# logo + wordmark top-left
$logo = New-Object System.Windows.Media.Imaging.BitmapImage
$logo.BeginInit(); $logo.UriSource = New-Object System.Uri($logoFile); $logo.EndInit()
$dc.DrawImage($logo, (New-Object System.Windows.Rect(36, 24, 52, 52)))
$t1 = New-Text "Cookie" 30 $whiteBrush
$t2 = New-Text "Cleaner" 30 $amberBrush
$dc.DrawText($t1, (New-Object System.Windows.Point(102, 32)))
$dc.DrawText($t2, (New-Object System.Windows.Point((102 + $t1.WidthIncludingTrailingWhitespace), 32)))

# title, centered
$title = New-Text "One extension, five languages" 36 $whiteBrush
$dc.DrawText($title, (New-Object System.Windows.Point((($W - $title.WidthIncludingTrailingWhitespace) / 2), 102)))

# language rows
$rowW = 920.0; $rowH = 90.0; $gap = 16.0
$rowX = ($W - $rowW) / 2
$y = 178.0
foreach ($lang in $LANGS) {
    $dc.DrawRoundedRectangle($panelBrush, $borderPen, (New-Object System.Windows.Rect($rowX, $y, $rowW, $rowH)), 14, 14)
    $name = New-Text $lang.name 29 $amberBrush
    $tag = New-Text $lang.tag 25 $mutedBrush $false
    $dc.DrawText($name, (New-Object System.Windows.Point(($rowX + 42), ($y + ($rowH - $name.Height) / 2))))
    $dc.DrawText($tag, (New-Object System.Windows.Point(($rowX + 320), ($y + ($rowH - $tag.Height) / 2))))
    $y += $rowH + $gap
}

# footer
$footer = New-Text "The UI follows your browser language — or pick one manually in the settings" 22 $mutedBrush $false
$dc.DrawText($footer, (New-Object System.Windows.Point((($W - $footer.WidthIncludingTrailingWhitespace) / 2), ($y + 18))))

$dc.Close()

# render, then re-save as 24bpp (the Web Store rejects alpha channels)
$rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($W, $H, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
$rtb.Render($dv)
$enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
$tmp = Join-Path $env:TEMP "cc-intl-tmp.png"
$fs = [System.IO.File]::Open($tmp, 'Create'); $enc.Save($fs); $fs.Close()

$src = [System.Drawing.Image]::FromFile($tmp)
$bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0, $W, $H)
$g.Dispose(); $src.Dispose()
Remove-Item $tmp -Force
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "  $outFile"
