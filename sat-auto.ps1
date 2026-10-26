param(
  [switch]$ForceIR,
  [switch]$ForceTrue,
  [double]$Latitude = 0,
  [int]$MonitorIndex = -999
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$root = $PSScriptRoot
$cfgPath = Join-Path $root 'config.json'
$cfg = $null
if (Test-Path $cfgPath) { try { $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
if ($Latitude -le 0) {
  $Latitude = 32.0
  if ($cfg -and $cfg.latitude) { $Latitude = [double]$cfg.latitude }
}
if ($MonitorIndex -eq -999) {
  $MonitorIndex = -1
  if ($cfg -and $null -ne $cfg.monitorIndex) { $MonitorIndex = [int]$cfg.monitorIndex }
}

# ---- 按太阳赤纬算日出日落（地方太阳时，约等于北京时间）----
$n = (Get-Date).DayOfYear
$declDeg = 23.45 * [Math]::Sin(2 * [Math]::PI * (284 + $n) / 365.0)
$decl = $declDeg * [Math]::PI / 180.0
$phi = $Latitude * [Math]::PI / 180.0
$cosw = -[Math]::Tan($phi) * [Math]::Tan($decl)
if ($cosw -gt 1) { $cosw = 1 }
if ($cosw -lt -1) { $cosw = -1 }
$w = [Math]::Acos($cosw) * 180.0 / [Math]::PI
$sunrise = 12.0 - $w / 15.0
$sunset = 12.0 + $w / 15.0

function FmtH($x) {
  $hh = [int][Math]::Floor($x)
  $mm = [int][Math]::Round(($x - $hh) * 60)
  if ($mm -eq 60) { $hh++; $mm = 0 }
  return ('{0:D2}:{1:D2}' -f $hh, $mm)
}

$now = Get-Date
$nowH = $now.Hour + $now.Minute / 60.0
# 可见光：日出后 30 分钟 到 日落前 15 分钟
$visStart = $sunrise + 0.5
$visEnd = $sunset - 0.25
$isDay = ($nowH -ge $visStart -and $nowH -le $visEnd)
if ($ForceIR) { $isDay = $false }
if ($ForceTrue) { $isDay = $true }

$stamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
Write-Output ("[$stamp] sun: rise=" + (FmtH $sunrise) + " set=" + (FmtH $sunset) + " (lat=$Latitude)")
Write-Output ("[$stamp] vis window=" + (FmtH $visStart) + "-" + (FmtH $visEnd) + " now=" + (FmtH $nowH))

if ($isDay) {
  Write-Output "[$stamp] MODE=truecolor"
  & "$root\set-wall.ps1" -MonitorIndex $MonitorIndex
} else {
  Write-Output "[$stamp] MODE=infrared"
  & "$root\sat-ir.ps1" -NoSet
  $ir = Join-Path $root 'wallpaper_ir.jpg'
  if (Test-Path $ir) {
    & "$root\set-wp.ps1" -Path $ir -Index $MonitorIndex
  } else {
    Write-Output 'IR_MISSING'
  }
}
Write-Output "[$stamp] DONE"

# ---- 写状态文件给托盘用 ----
try {
  $modeName = 'infrared'
  $img = Join-Path $root 'wallpaper_ir.jpg'
  if ($isDay) { $modeName = 'truecolor'; $img = Join-Path $root 'wallpaper.jpg' }
  $st = [ordered]@{
    time = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    mode = $modeName
    img  = $img
    ok   = (Test-Path $img)
  }
  ($st | ConvertTo-Json -Compress) | Set-Content -Path (Join-Path $root 'status.json') -Encoding UTF8
} catch {
  Write-Output ('STATUS_FAIL: ' + $_.Exception.Message)
}
