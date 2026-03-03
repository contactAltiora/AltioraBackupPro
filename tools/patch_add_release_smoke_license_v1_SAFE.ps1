$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$p = Join-Path (Get-Location).Path "tools\release_build_and_backup.ps1"
if(-not (Test-Path -LiteralPath $p)){ throw "FAIL-CLOSED: tools\release_build_and_backup.ps1 introuvable." }

$txt = Get-Content -LiteralPath $p -Encoding UTF8 -Raw
$marker = "ABP_RELEASE_SMOKE_LICENSE_V1"
if($txt -match $marker){
  Write-Host "Already present: release smoke license V1. No change."
  exit 0
}

# Append a new block at end (non-invasive)
$append = @'
# ABP_RELEASE_SMOKE_LICENSE_V1
# Optional license smoke test (PRO edition must be enabled with a valid Ed25519 license).
try {
   = "PRO"

  # Prefer explicit path (caller can set ABP_SMOKE_LICENSE_FILE), else pick newest license in _out\licenses
   = ( ?? "").Trim()
  if([string]::IsNullOrWhiteSpace()){
     = Get-ChildItem -LiteralPath (Join-Path  "..\_out\licenses") -Filter "*.license.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if(){  = .FullName }
  }

  if([string]::IsNullOrWhiteSpace() -or (-not (Test-Path -LiteralPath ))){
    Write-Host "WARN: license smoke skipped (no license file found). Set ABP_SMOKE_LICENSE_FILE to enable."
  } else {
     = 
    py -c "from src import backup_core as bc; assert bc.EDITION=='PRO', (bc.EDITION, bc.EDITION_REASON); print('OK: license smoke passed')"
    if( -ne 0){ throw "license smoke failed (exit=)" }
  }
} finally {
  Remove-Item Env:\ALTIORA_LICENSE_FILE -ErrorAction SilentlyContinue
  Remove-Item Env:\ALTIORA_EDITION -ErrorAction SilentlyContinue
}
'@

$txt2 = $txt.TrimEnd() + "

" + $append + "
"
Set-Content -LiteralPath $p -Value $txt2 -Encoding UTF8
Write-Host "OK: added license smoke to release_build_and_backup.ps1 (V1)"
