$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path

# --- 1) altiora.py: ensure __version__ is defined next to VERSION_STR ---
$alt = Join-Path $root "altiora.py"
if(!(Test-Path $alt)){ throw "altiora.py introuvable" }

$text = Get-Content -LiteralPath $alt -Raw -Encoding UTF8

if($text -match '__version__\s*='){ 
  Write-Host "INFO: __version__ already present in altiora.py"
} else {
  $pat = 'VERSION_STR\s*=\s*"Altiora Backup Pro v1\.0\.14"\s*'
  if($text -notmatch $pat){ throw "VERSION_STR v1.0.14 introuvable dans altiora.py (abort)" }
  $rep = 'VERSION_STR = "Altiora Backup Pro v1.0.14"' + "`n" + '__version__ = "1.0.14"'
  $text = [regex]::Replace($text, $pat, $rep, 1)
  Set-Content -LiteralPath $alt -Value $text -Encoding UTF8
  Write-Host "PATCH OK: altiora.py defines __version__ = 1.0.14"
}

# --- 2) src/backup_cli.py: bump embedded version string if present ---
$cli = Join-Path $root "src\backup_cli.py"
if(Test-Path $cli){
  $t = Get-Content -LiteralPath $cli -Raw -Encoding UTF8
  # replace any Altiora Backup Pro v1.0.xx with v1.0.14
  $t2 = [regex]::Replace($t, 'Altiora Backup Pro v1\.0\.\d+', 'Altiora Backup Pro v1.0.14')
  if($t2 -ne $t){
    Set-Content -LiteralPath $cli -Value $t2 -Encoding UTF8
    Write-Host "PATCH OK: src\backup_cli.py version strings -> v1.0.14"
  } else {
    Write-Host "INFO: no version string change needed in src\backup_cli.py"
  }
} else {
  Write-Host "INFO: src\backup_cli.py not found (skip)"
}

Write-Host "PATCH OK: version alignment v1.0.14 complete"
