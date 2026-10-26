' Silent launcher for sat-tray.ps1 - starts the tray with no console window.
Option Explicit
Dim sh
Set sh = CreateObject("WScript.Shell")
sh.Run "powershell.exe -STA -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\Users\Admin\Pictures\SatWall\sat-tray.ps1""", 0, False
