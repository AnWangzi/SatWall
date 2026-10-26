param(
  [int]$Grid = 8,
  [int]$Tile = 550,
  [int]$OutW = 0,
  [int]$OutH = 0,
  [int]$DiscPx = 2200,
  [int]$BackMinutes = 25,
  [int]$MonitorIndex = -1,
  [switch]$NoSet,
  [string]$Base = ''
)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not $Base) { $Base = $PSScriptRoot }
Add-Type -AssemblyName System.Drawing
$work = Join-Path $Base "work$Grid"
if (-not (Test-Path $work)) { New-Item -ItemType Directory -Path $work -Force | Out-Null }
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36'

# ---- 1. 定位可用时间戳 ----
$stampT = $null
for ($k = 0; $k -lt 6; $k++) {
  $t = (Get-Date).ToUniversalTime().AddMinutes(-$BackMinutes - 10 * $k)
  $t = $t.AddMinutes(-($t.Minute % 10)).AddSeconds(-$t.Second).AddMilliseconds(-$t.Millisecond)
  $s = '{0:yyyy}/{0:MM}/{0:dd}/{0:HHmm}00' -f $t
  $probe = Join-Path $work 'probe.png'
  try {
    Invoke-WebRequest -Uri "https://himawari.asia/img/D531106/1d/$Tile/$s`_0_0.png" -OutFile $probe -UserAgent $UA -TimeoutSec 25 -UseBasicParsing -ErrorAction Stop
    if ((Get-Item $probe).Length -gt 20000) { $stampT = $t; $stamp = $s; break }
  } catch { }
}
if (-not $stampT) { Write-Output 'NO_TIMESTAMP'; exit 1 }
Write-Output ("IMG_UTC=" + $stampT.ToString('yyyy-MM-dd HH:mm') + "  (" + $stamp + ")")

# ---- 2. 拼瓦片 ----
$dim = $Grid * $Tile
$disc = New-Object System.Drawing.Bitmap($dim, $dim)
$gd = [System.Drawing.Graphics]::FromImage($disc)
$gd.Clear([System.Drawing.Color]::Black)
$ok = 0; $miss = 0
for ($y = 0; $y -lt $Grid; $y++) {
  for ($x = 0; $x -lt $Grid; $x++) {
    $f = Join-Path $work "t${x}_${y}.png"
    $got = $false
    for ($r = 0; $r -lt 3; $r++) {
      try {
        Invoke-WebRequest -Uri "https://himawari.asia/img/D531106/${Grid}d/$Tile/$stamp`_${x}_${y}.png" -OutFile $f -UserAgent $UA -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        $got = $true; break
      } catch { Start-Sleep -Milliseconds 300 }
    }
    if ($got) {
      try {
        $im = [System.Drawing.Image]::FromFile($f)
        $gd.DrawImage($im, ($x * $Tile), ($y * $Tile), $Tile, $Tile)
        $im.Dispose(); $ok++
      } catch { $miss++ }
    } else { $miss++ }
  }
}
$gd.Dispose()
Write-Output "TILES ok=$ok miss=$miss"
if ($ok -eq 0) { Write-Output 'NO_TILES'; exit 2 }

# ---- 3. 输出（默认原分辨率，不裁不缩不加水印）----
$out = Join-Path $Base 'wallpaper.jpg'
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int64]95)
if ($OutW -gt 0 -and $OutH -gt 0) {
  $canvas = New-Object System.Drawing.Bitmap($OutW, $OutH)
  $g = [System.Drawing.Graphics]::FromImage($canvas)
  $g.Clear([System.Drawing.Color]::Black)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SetClip((New-Object System.Drawing.Rectangle 0, 0, $OutW, $OutH))
  $g.DrawImage($disc, [int](($OutW - $DiscPx) / 2), [int](($OutH - $DiscPx) / 2), $DiscPx, $DiscPx)
  $g.ResetClip(); $g.Dispose()
  $canvas.Save($out, $enc, $ep)
  $canvas.Dispose()
  Write-Output "OUT=$out bytes=$((Get-Item $out).Length) ${OutW}x${OutH}"
} else {
  $disc.Save($out, $enc, $ep)
  Write-Output "OUT=$out bytes=$((Get-Item $out).Length) ${dim}x${dim}"
}
$disc.Dispose()
Get-ChildItem $work -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Output "OUT=$out bytes=$((Get-Item $out).Length)"

# ---- 5. 设副屏壁纸 ----
if ($NoSet) { Write-Output 'SKIP_SET'; exit 0 }
$com = @'
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[ComImport, Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IDesktopWallpaper {
    void SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);
    [return: MarshalAs(UnmanagedType.LPWStr)] string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);
    [return: MarshalAs(UnmanagedType.LPWStr)] string GetMonitorDevicePathAt(uint monitorIndex);
    uint GetMonitorDevicePathCount();
    void GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID, out RECT displayRect);
    void SetBackgroundColor(uint color); uint GetBackgroundColor();
    void SetPosition(int position); int GetPosition();
    void SetSlideshow(IntPtr items); IntPtr GetSlideshow();
    void SetSlideshowOptions(int options, uint slideshowTick);
    void GetSlideshowOptions(out int options, out uint slideshowTick);
    void AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, int direction);
    int GetStatus(); void Enable(bool enable);
}
public static class WP3 {
    [DllImport("ole32.dll")] private static extern int CoCreateInstance(ref Guid rclsid, IntPtr pUnkOuter, uint dwClsContext, ref Guid riid, out IntPtr ppv);
    public static IDesktopWallpaper Get() {
        Guid clsid = new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD");
        Guid iid = new Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B");
        IntPtr p; int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 23, ref iid, out p);
        if (hr != 0) throw new COMException("hr=0x" + hr.ToString("X8"), hr);
        return (IDesktopWallpaper)Marshal.GetObjectForIUnknown(p);
    }
    public static string SetByIndex(int idx, string path) {
        var wp = Get(); uint n = wp.GetMonitorDevicePathCount();
        if (idx < 0 || idx >= n) throw new ArgumentException("bad monitor index " + idx + " (count=" + n + ")");
        string id = wp.GetMonitorDevicePathAt((uint)idx);
        wp.SetWallpaper(id, path);
        return id;
    }
    public static string SetSecondary(string path) {
        var wp = Get(); uint n = wp.GetMonitorDevicePathCount();
        for (uint i = 0; i < n; i++) {
            string id = wp.GetMonitorDevicePathAt(i); RECT rc; wp.GetMonitorRECT(id, out rc);
            if (rc.Left < 0) { wp.SetWallpaper(id, path); return id; }
        }
        return "NO_LEFT_MONITOR";
    }
}
'@
Add-Type -TypeDefinition $com -Language CSharp
try {
  if ($MonitorIndex -ge 0) {
    $id = [WP3]::SetByIndex($MonitorIndex, $out)
  } else {
    $id = [WP3]::SetSecondary($out)
  }
  Write-Output "SET=$id"
} catch { Write-Output ('SET_FAIL: ' + $_.Exception.Message) }
