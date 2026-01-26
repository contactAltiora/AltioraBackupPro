$ErrorActionPreference="Stop"
Set-Location "C:\Dev\AltioraBackupPro"

$gitignore = ".gitignore"
$wanted = @(
  "backups.json",
  "*.altb",
  "__pycache__/",
  "*.pyc",
  "altiora.py.bak_*",
  "src/*.py.bak_*",
  "tools/*.py",
  "tools/patch_*.ps1",
  "tools/patch_*.py"
)

if (!(Test-Path $gitignore)) {
  Set-Content -Encoding UTF8 $gitignore ("# AltioraBackupPro`r`n")
}

$cur = Get-Content $gitignore -ErrorAction SilentlyContinue
$toAdd = $wanted | Where-Object { $_ -notin $cur }
if ($toAdd.Count -gt 0) {
  Add-Content -Encoding UTF8 $gitignore ("`r`n# Generated / local artifacts`r`n" + ($toAdd -join "`r`n") + "`r`n")
  Write-Host "OK: .gitignore updated (+$($toAdd.Count))"
} else {
  Write-Host "OK: .gitignore already up to date"
}

New-Item -ItemType Directory -Force .\tools\_patches | Out-Null
$movePatterns = @("patch_*.ps1","patch_*.py","probe_*.py","read_header_*.py","scan_kdf_*.py","init_master_key.py","add_master_key_module_v1.ps1")
foreach($pat in $movePatterns){
  Get-ChildItem .\tools -File -Filter $pat -ErrorAction SilentlyContinue | ForEach-Object {
    Move-Item -Force $_.FullName (Join-Path .\tools\_patches $_.Name)
  }
}
Write-Host "OK: tools patched scripts moved to tools\_patches (if any found)"

powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\smoke.ps1
Write-Host "OK: harden_repo_v1 done"
