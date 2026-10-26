param(
  [int]$Zoom = 2,
  [int]$Grid = 4,
  [int]$Tile = 688,
  [int]$BackMinutes = 0,
  [switch]$NoSet,
  [string]$Base = ''
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not $Base) { $Base = $PSScriptRoot }
Add-Type -AssemblyName System.Drawing
$work = Join-Path $Base "irwork$Zoom"
if (-not (Test-Path $work)) { New-Item -ItemType Directory -Path $work -Force | Out-Null }
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'

function Fetch($url, $out, $tries = 5) {
  for ($i = 1; $i -le $tries; $i++) {
    try {
      Invoke-WebRequest -Uri $url -UserAgent $UA -TimeoutSec 30 -UseBasicParsing -OutFile $out -ErrorAction Stop
      return $true
    } catch { Start-Sleep -Milliseconds 600 }
  }
  return $false
}

# ---- 1. 取最新红外时间戳 ----
$idx = Join-Path $work 'times.json'
if (-not (Fetch 'https://slider.cira.colostate.edu/data/json/himawari/full_disk/band_13/latest_times.json' $idx)) {
  Write-Output 'IDX_FAIL'; exit 1
}
$obj = Get-Content $idx -Raw | ConvertFrom-Json
$ts = [string]$obj.timestamps_int[0]
Write-Output "TS=$ts"
$y = $ts.Substring(0,4); $m = $ts.Substring(4,2); $d = $ts.Substring(6,2)
$root = "https://slider.cira.colostate.edu/data/rammb-slider9/slider/output/imagery/$y/$m/$d/himawari---full_disk/band_13/$ts"
$zdir = ('{0:D2}' -f $Zoom)
Write-Output "ROOT=$root/$zdir"

# ---- 2. 拼瓦片 ----
$dim = $Grid * $Tile
$big = New-Object System.Drawing.Bitmap($dim, $dim)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.Clear([System.Drawing.Color]::Black)
$ok = 0; $miss = 0
for ($r = 0; $r -lt $Grid; $r++) {
  for ($c = 0; $c -lt $Grid; $c++) {
    $name = ('{0:D3}_{1:D3}.png' -f $r, $c)
    $u = "$root/$zdir/$name"
    $f = Join-Path $work $name
    if (Fetch $u $f 4) {
      try {
        $im = [System.Drawing.Image]::FromFile($f)
        $g.DrawImage($im, ($c * $Tile), ($r * $Tile), $Tile, $Tile)
        $im.Dispose(); $ok++
      } catch { $miss++ }
    } else { $miss++ }
  }
}
$g.Dispose()
Write-Output "TILES ok=$ok miss=$miss"
if ($ok -eq 0) { Write-Output 'NO_TILES'; exit 2 }

$out = Join-Path $Base 'wallpaper_ir.jpg'
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]95)
$big.Save($out, $enc, $ep)
$big.Dispose()
Get-ChildItem $work -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Output "OUT=$out bytes=$((Get-Item $out).Length) ${dim}x${dim}"
if ($NoSet) { Write-Output 'SKIP_SET'; exit 0 }
