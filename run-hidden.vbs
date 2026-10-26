' Silent launcher for sat-auto.ps1 - runs PowerShell with NO console window.
Option Explicit
Dim sh, cmd, i
Set sh = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""C:\Users\Admin\Pictures\SatWall\sat-auto.ps1"""
For i = 0 To WScript.Arguments.Count - 1
  cmd = cmd & " " & WScript.Arguments(i)
Next
sh.Run cmd, 0, False
