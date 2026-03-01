# tools\release_secure_v1.ps1
# Secure release pipeline: build -> sign -> verify -> backup -> STATE/STATE_HISTORY
# Requires: PowerShell 5+, Python 3.11, cryptography, your existing tools scripts.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log([string]$m){
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Write-Host "[$ts] $m"
}

function Sha256([string]$p){
  if(-not (Test-Path -LiteralPath $p)){ throw "File missing: $p" }
  (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
}

# --- Repo layout ---
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$releasesDir = Join-Path $repoRoot "_out\releases"
$keysDir     = Join-Path $repoRoot "keys"
$pubKey      = Join-Path $keysDir "altiora_public_key.pem"
$privKey     = Join-Path $keysDir "altiora_private_key.pem"
$verifyPy    = Join-Path $repoRoot "tools\verify_signature.py"
$finalizePs1 = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"

$backupDirs  = @("F:\ABP_RELEASES","H:\ABP_RELEASES")

# --- Guardrails ---
Log "=== SECURE RELEASE START ==="
Log "Repo: $repoRoot"

foreach($p in @($releasesDir,$keysDir,$verifyPy,$finalizePs1)){
  if(-not (Test-Path -LiteralPath $p)){ throw "Missing required path: $p" }
}
foreach($p in @($pubKey,$privKey)){
  if(-not (Test-Path -LiteralPath $p)){ throw "Missing key: $p" }
}
foreach($d in $backupDirs){
  if(-not (Test-Path -LiteralPath $d)){ throw "Backup drive missing: $d" }
}

# --- Find latest release zip (the one produced by your build pipeline) ---
$zip = Get-ChildItem -LiteralPath $releasesDir -Filter "AltioraBackupPro_v*_release.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if(-not $zip){ throw "No release zip found in $releasesDir" }

$zipPath = $zip.FullName
$sigPath = $zipPath + ".sig"

Log "Release ZIP: $zipPath"

# --- Sign release zip (overwrite .sig deterministically) ---
Log "Signing release zip..."
# Use your existing verify_signature.py counterpart if you have a signer;
# Here we assume you have tools\sign_release.py OR verify_signature.py can’t sign.
# If you already sign inside release_finalize_and_state.ps1, we just ensure signature exists.

# If signature missing, call release_finalize_and_state.ps1 which signs+verifies+backs up+STATE.
# If signature exists, we still verify now.
# NOTE: your release_finalize_and_state.ps1 already does:
# - sign zip -> .sig
# - verify
# - backup to F/H
# - update STATE + history
# So we delegate to it to keep single source of truth.
Log "Delegating to: tools\release_finalize_and_state.ps1"
& $finalizePs1

# --- Post-checks (strict) ---
# Re-detect latest (in case finalize touched timestamps)
$zip2 = Get-ChildItem -LiteralPath $releasesDir -Filter "AltioraBackupPro_v*_release.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
$zipPath2 = $zip2.FullName
$sigPath2 = $zipPath2 + ".sig"

if(-not (Test-Path -LiteralPath $sigPath2)){
  throw "Signature not found after finalize: $sigPath2"
}

Log "Verifying signature (strict)..."
$py = $null
if(Get-Command py -ErrorAction SilentlyContinue){ $py="py" }
elseif(Get-Command python -ErrorAction SilentlyContinue){ $py="python" }
else{ throw "python launcher not found" }

& $py $verifyPy $pubKey $zipPath2 | Out-Host
if($LASTEXITCODE -ne 0){
  throw "Signature verification failed (exit=$LASTEXITCODE)"
}
Log "Signature verification OK"

# --- Verify backups contain the same zip + signature (hash match on zip; signature file existence) ---
$zipSha = Sha256 $zipPath2
Log "ZIP SHA256: $zipSha"

foreach($d in $backupDirs){
  $destZip = Join-Path $d (Split-Path -Leaf $zipPath2)
  $destSig = $destZip + ".sig"

  if(-not (Test-Path -LiteralPath $destZip)){ throw "Backup zip missing: $destZip" }
  if(-not (Test-Path -LiteralPath $destSig)){ throw "Backup sig missing: $destSig" }

  $destSha = Sha256 $destZip
  if($destSha -ne $zipSha){ throw "Backup hash mismatch on $d" }

  Log "Backup OK: $d"
}

Log "=== SECURE RELEASE COMPLETE ==="