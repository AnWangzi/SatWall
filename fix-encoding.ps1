$ErrorActionPreference = 'Stop'
$dir = 'C:\Users\Admin\Pictures\SatWall'
$enc = New-Object System.Text.UTF8Encoding($true)
Get-ChildItem $dir -Filter '*.ps1' | ForEach-Object {
  $c = Get-Content -Path $_.FullName -Raw -Encoding UTF8
  [System.IO.File]::WriteAllText($_.FullName, $c, $enc)
  $b = [System.IO.File]::ReadAllBytes($_.FullName)
  $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
  Write-Output ("{0,-24} bom={1} bytes={2}" -f $_.Name, $hasBom, $b.Length)
}
