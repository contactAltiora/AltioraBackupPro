$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$txt  = Get-Content $path -Raw -Encoding UTF8

# Remplacer les TAB par 4 espaces (Python indentation stable)
$beforeTabs = ($txt.ToCharArray() | Where-Object { $_ -eq "`t" }).Count
$txt2 = $txt.Replace("`t", "    ")
Set-Content -Path $path -Value $txt2 -Encoding UTF8

Write-Host "OK: detab appliqué (tabs remplacés: $beforeTabs)"
