param([string]$Root = '')
$ErrorActionPreference = 'Continue'
if (-not $Root) { $Root = $PSScriptRoot }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$sig = '[DllImport("user32.dll", SetLastError=true)] public static extern bool DestroyIcon(IntPtr hIcon);'
$U32 = Add-Type -MemberDefinition $sig -Name IconApi -Namespace Tray -PassThru

$script:Root = $Root
$script:proc = $null
$script:curIcon = $null
$script:curHicon = [IntPtr]::Zero
$script:lastKey = ''

function Get-Status {
  $p = Join-Path $script:Root 'status.json'
  if (Test-Path $p) {
    try { return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
  }
  return $null
}

function Set-TrayIcon([string]$path) {
  try {
    $bmp = [System.Drawing.Bitmap]::FromFile($path)
    $side = [Math]::Min($bmp.Width, $bmp.Height)
    $sx = [int](($bmp.Width - $side) / 2)
    $sy = [int](($bmp.Height - $side) / 2)
    $thumb = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($thumb)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $dst = New-Object System.Drawing.Rectangle 0, 0, 32, 32
    $src = New-Object System.Drawing.Rectangle $sx, $sy, $side, $side
    $g.DrawImage($bmp, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $bmp.Dispose()
    $h = $thumb.GetHicon()
    $thumb.Dispose()
    if ($script:curIcon) { $script:curIcon.Dispose() }
    if ($script:curHicon -ne [IntPtr]::Zero) { [Tray.IconApi]::DestroyIcon($script:curHicon) | Out-Null }
    $script:curHicon = $h
    $script:curIcon = [System.Drawing.Icon]::FromHandle($h)
    $ni.Icon = $script:curIcon
  } catch { }
}

$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Text = '卫星云图'
$ni.Visible = $false

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miStatus = $menu.Items.Add('状态读取中…')
$miStatus.Enabled = $false
$menu.Items.Add('-') | Out-Null
$miRefresh = $menu.Items.Add('立即刷新（自动判断昼夜）')
$miTrue = $menu.Items.Add('强制切到可见光')
$miIR = $menu.Items.Add('强制切到红外')
$menu.Items.Add('-') | Out-Null
$miPause = $menu.Items.Add('暂停自动刷新')
$miResume = $menu.Items.Add('恢复自动刷新')
$menu.Items.Add('-') | Out-Null
$miOpenImg = $menu.Items.Add('打开当前大图')
$miOpenDir = $menu.Items.Add('打开图片文件夹')
$menu.Items.Add('-') | Out-Null
$miExit = $menu.Items.Add('退出托盘')
$ni.ContextMenuStrip = $menu

function Start-Refresh([string]$flag) {
  if ($script:proc -and -not $script:proc.HasExited) { return }
  $a = @('-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $script:Root 'sat-auto.ps1'))
  if ($flag) { $a += $flag }
  $script:proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $a -WindowStyle Hidden -PassThru
  $ni.Text = '卫星云图 · 正在刷新…'
}

function Update-Display {
  $st = Get-Status
  if (-not $st) { $ni.Text = '卫星云图 · 尚未抓取'; return }
  $m = '红外'; if ($st.mode -eq 'truecolor') { $m = '可见光' }
  $txt = "卫星云图 · $m · $($st.time)"
  if ($script:proc -and -not $script:proc.HasExited) { $txt = '卫星云图 · 正在刷新…' }
  if ($txt.Length -gt 62) { $txt = $txt.Substring(0, 62) }
  $ni.Text = $txt
  $miStatus.Text = "当前：$m   更新于 $($st.time)"
  if ($st.img -and (Test-Path $st.img)) {
    $f = Get-Item $st.img
    $key = "$($st.img)|$($f.LastWriteTime.Ticks)"
    if ($script:lastKey -ne $key) { $script:lastKey = $key; Set-TrayIcon $st.img }
  }
}

$miRefresh.Add_Click({ Start-Refresh $null })
$miTrue.Add_Click({ Start-Refresh '-ForceTrue' })
$miIR.Add_Click({ Start-Refresh '-ForceIR' })
$miOpenImg.Add_Click({
  $st = Get-Status
  if ($st -and (Test-Path $st.img)) { Start-Process $st.img }
})
$miOpenDir.Add_Click({ Start-Process explorer.exe $script:Root })
$miPause.Add_Click({
  try { Disable-ScheduledTask -TaskName 'SatWallpaper' -ErrorAction Stop | Out-Null; $ni.ShowBalloonTip(2000, '已暂停', '自动刷新停止，手动刷新仍可用', 'Info') }
  catch { schtasks.exe /change /tn SatWallpaper /disable | Out-Null; $ni.ShowBalloonTip(2000, '已暂停', '自动刷新停止', 'Info') }
})
$miResume.Add_Click({
  try { Enable-ScheduledTask -TaskName 'SatWallpaper' -ErrorAction Stop | Out-Null; $ni.ShowBalloonTip(2000, '已恢复', '每 30 分钟自动刷新', 'Info') }
  catch { schtasks.exe /change /tn SatWallpaper /enable | Out-Null; $ni.ShowBalloonTip(2000, '已恢复', '每 30 分钟自动刷新', 'Info') }
})
$miExit.Add_Click({
  $ni.Visible = $false
  $ni.Dispose()
  if ($script:ctx) { $script:ctx.ExitThread() }
})

$ni.Add_MouseDoubleClick({ Start-Refresh $null })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
  if ($script:proc -and $script:proc.HasExited) { $script:proc = $null }
  Update-Display
})
$timer.Start()

Update-Display
$ni.Visible = $true
$ni.ShowBalloonTip(3000, '卫星云图托盘已启动', '双击图标立即刷新；右键可强制切换模式', 'Info')

$script:ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($script:ctx)
