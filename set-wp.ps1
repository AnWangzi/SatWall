param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$Where = 'left',
  [int]$Index = -1
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not (Test-Path $Path)) { Write-Output "MISSING=$Path"; exit 1 }
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
public static class WPSet {
    [DllImport("ole32.dll")] private static extern int CoCreateInstance(ref Guid rclsid, IntPtr pUnkOuter, uint dwClsContext, ref Guid riid, out IntPtr ppv);
    public static IDesktopWallpaper Get() {
        Guid clsid = new Guid("C2CF3110-460E-4FC1-B9D0-8A1C0C9CC4BD");
        Guid iid = new Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B");
        IntPtr p; int hr = CoCreateInstance(ref clsid, IntPtr.Zero, 23, ref iid, out p);
        if (hr != 0) throw new COMException("hr=0x" + hr.ToString("X8"), hr);
        return (IDesktopWallpaper)Marshal.GetObjectForIUnknown(p);
    }
    public static string ApplyAt(int idx, string path) {
        var wp = Get(); uint n = wp.GetMonitorDevicePathCount();
        if (idx < 0 || idx >= n) throw new ArgumentException("bad monitor index " + idx + " (count=" + n + ")");
        string id = wp.GetMonitorDevicePathAt((uint)idx);
        wp.SetWallpaper(id, path);
        return id;
    }
    public static string Apply(string path, bool leftOnly) {
        var wp = Get(); uint n = wp.GetMonitorDevicePathCount();
        for (uint i = 0; i < n; i++) {
            string id = wp.GetMonitorDevicePathAt(i); RECT rc; wp.GetMonitorRECT(id, out rc);
            bool hit = leftOnly ? (rc.Left < 0) : true;
            if (hit) wp.SetWallpaper(id, path);
            if (hit && leftOnly) return id + " [" + rc.Left + "," + rc.Top + "]";
        }
        return "NOT_SET";
    }
}
'@
Add-Type -TypeDefinition $com -Language CSharp
if ($Index -ge 0) {
  Write-Output ('SET ' + [WPSet]::ApplyAt($Index, $Path))
} else {
  $leftOnly = ($Where -eq 'left')
  Write-Output ('SET ' + [WPSet]::Apply($Path, $leftOnly))
}
