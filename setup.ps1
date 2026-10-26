param(
  [string]$Dest = '',
  [int]$MonitorIndex = -2,
  [double]$Latitude = 32.0,
  [int]$IntervalMinutes = 30,
  [switch]$SkipFirstRun,
  [switch]$NoTasks
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$src = $PSScriptRoot
if (-not $Dest) { $Dest = $src }
if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
$Dest = (Resolve-Path $Dest).Path

Write-Output '================================================'
Write-Output ' Satellite Wallpaper - setup'
Write-Output '================================================'
Write-Output ("source : " + $src)
Write-Output ("target : " + $Dest)

# ---- 1) 复制文件 ----
$files = @('sat-auto.ps1','sat-ir.ps1','sat-tray.ps1','set-wall.ps1','set-wp.ps1','run-hidden.vbs','run-tray.vbs','README.md')
if ($Dest -ne $src) {
  foreach ($f in $files) {
    $p = Join-Path $src $f
    if (Test-Path $p) { Copy-Item $p (Join-Path $Dest $f) -Force; Write-Output ("copied " + $f) }
    else { Write-Output ("MISSING " + $f) }
  }
} else {
  Write-Output 'in-place install'
}

# VBS launchers hardcode the source path - rewrite them to the target
foreach ($v in @('run-hidden.vbs','run-tray.vbs')) {
  $vp = Join-Path $Dest $v
  if (Test-Path $vp) {
    $c = Get-Content $vp -Raw
    $c = $c.Replace('C:\Users\Admin\Pictures\SatWall', $Dest)
    if ($Dest -ne $src) { $c = $c.Replace($src, $Dest) }
    Set-Content -Path $vp -Value $c -Encoding ASCII
    Write-Output ("rewrote " + $v)
  }
}

# ---- 2) 列出显示器 ----
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
public static class Mon {
    [DllImport("ole32.dll")] private static extern int CoCreateInstance(ref Guid rclsid, IntPtr pUnkOuter, uint dwClsContext, ref Guid riid, out IntPtr ppv);
    public static IDesktopWallpaper Get() {
        Guid clsid = new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD");
        Guid iid = new Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B");
        IntPtr p; int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 23, ref iid, out p);
        if (hr != 0) throw new COMException("hr=0x" + hr.ToString("X8"), hr);
        return (IDesktopWallpaper)Marshal.GetObjectForIUnknown(p);
    }
    public static string[] List() {
        var wp = Get(); uint n = wp.GetMonitorDevicePathCount(); string[] r = new string[n];
        for (uint i = 0; i < n; i++) {
            string id = wp.GetMonitorDevicePathAt(i); RECT rc; wp.GetMonitorRECT(id, out rc);
            r[i] = i + "|" + id + "|" + rc.Left + "," + rc.Top + "|" + (rc.Right - rc.Left) + "x" + (rc.Bottom - rc.Top);
        }
        return r;
    }
}
'@
Add-Type -TypeDefinition $com -Language CSharp

Write-Output ''
Write-Output '--- monitors ---'
$mons = [Mon]::List()
$i = 0
foreach ($m in $mons) {
  $parts = $m.Split('|')
  $tag = ''
  if ($parts[2] -eq '0,0') { $tag = '  <-- primary' }
  Write-Output ("  [" + $parts[0] + "] " + $parts[3] + " at " + $parts[2] + $tag)
  $i++
}

# ---- 3) 选显示器 ----
$auto = -1
for ($k = 0; $k -lt $mons.Count; $k++) {
  $parts = $mons[$k].Split('|')
  if ($parts[2] -ne '0,0') { $auto = [int]$parts[0]; break }
}
if ($MonitorIndex -eq -2) {
  Write-Output ''
  Write-Output ("Which monitor should show the satellite? (default " + $auto + ", Enter to accept)")
  $ans = Read-Host 'index'
  if ([string]::IsNullOrWhiteSpace($ans)) { $MonitorIndex = $auto }
  else { $MonitorIndex = [int]$ans }
}
Write-Output ("monitor -> " + $MonitorIndex)

# ---- 4) 写 config ----
$cfg = [ordered]@{
  root            = $Dest
  monitorIndex    = $MonitorIndex
  latitude        = $Latitude
  intervalMinutes = $IntervalMinutes
  trueColorGrid   = 8
  infraredZoom    = 2
}
$cfgPath = Join-Path $Dest 'config.json'
($cfg | ConvertTo-Json) | Set-Content -Path $cfgPath -Encoding UTF8
Write-Output ("config -> " + $cfgPath)

# ---- 5) 计划任务 ----
if (-not $NoTasks) {
$taskName = 'SatWallpaper'
$ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$wscript = "$env:SystemRoot\System32\wscript.exe"
$vbsAuto = Join-Path $Dest 'run-hidden.vbs'
$old = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($old) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
$act = New-ScheduledTaskAction -Execute $wscript -Argument ('"' + $vbsAuto + '"')
$trg = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
Register-ScheduledTask -TaskName $taskName -Action $act -Trigger $trg -Settings $set -Description 'Satellite wallpaper auto refresh' -Force | Out-Null
Write-Output ("task -> " + $taskName + " every " + $IntervalMinutes + "min")

# ---- 6) 托盘开机自启 ----
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'SatelliteWallpaper.lnk'
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath = $wscript
$sc.Arguments = '"' + (Join-Path $Dest 'run-tray.vbs') + '"'
$sc.WindowStyle = 7
$sc.WorkingDirectory = $Dest
$sc.Description = 'Satellite wallpaper tray'
$sc.Save()
Write-Output ("tray shortcut -> " + $lnk)
}

# ---- 7) 首次抓图 ----
if (-not $SkipFirstRun) {
  Write-Output ''
  Write-Output 'first fetch (about 1-4 min)...'
  & (Join-Path $Dest 'sat-auto.ps1') -MonitorIndex $MonitorIndex -Latitude $Latitude
}

Write-Output ''
Write-Output 'DONE. Restart tray: run sat-tray.ps1 (or log off/on).'
