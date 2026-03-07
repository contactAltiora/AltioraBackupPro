# SAFE_FS_BOOTSTRAP_V4
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$safeFs = Join-Path $PSScriptRoot "safe_fs.ps1"
if(Test-Path -LiteralPath $safeFs){ . $safeFs }
if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){
  throw "FAIL-CLOSED: Safe-GetChildItem introuvable (safe_fs.ps1 non chargé)."
}

# ================================
# ABP_SAFEFS_FALLBACK_V3
# Ensure Safe-GetChildItem exists in this runspace
# ================================
try {
  $safeFs = Join-Path $PSScriptRoot "safe_fs.ps1"
  if(Test-Path -LiteralPath $safeFs){ . $safeFs }
} catch { }

if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){
  function Safe-GetChildItem {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory=$true)][string]$LiteralPath,
      [string]$Filter,
      [switch]$Recurse,
      [switch]$File,
      [switch]$Directory
    )

# ABP_PARSE_VERSION_SUFFIX_V3
function ABP-GetVersionCore {
  param([Parameter(Mandatory=$true)][string]$V)
  $v2 = $V.Trim()
  $m = [regex]::Match($v2, '^(?<core>\d+\.\d+\.\d+)')
  if($m.Success){ return $m.Groups["core"].Value }
  return $v2
}
    $ea = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    try {
      if(!(Test-Path -LiteralPath $LiteralPath)){ return @() }
      $args = @{ LiteralPath = $LiteralPath; Force = $true }
      if($Filter){ $args.Filter = $Filter }
      if($Recurse){ $args.Recurse = $true }
      if($File){ $args.File = $true }
      if($Directory){ $args.Directory = $true }
      return @(Get-ChildItem @args)
    } finally {
      $ErrorActionPreference = $ea
    }
  }
}

if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){
  throw "FAIL-CLOSED: Safe-GetChildItem introuvable même après fallback."
}

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "safe_fs.ps1")
# detect repo root
$repoRoot = Split-Path -Parent $PSScriptRoot

$releasesDir = Join-Path $repoRoot "_out\releases"

if(-not (Test-Path $releasesDir)){
    throw "Releases directory missing: $releasesDir"
}

# find latest release
  $lastZip = Get-ChildItem -LiteralPath $releasesDir -Filter "AltioraBackupPro_v*_release.zip" -File -ErrorAction Stop |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1

if(-not $lastZip){
    throw "No release zip found"
}

# extract version
# # ABP_HELPER_SCOPE_V3I_C
# ABP_FIX_COMMENT_SPLIT_V3J
if(-not (Get-Command -Name ABP-GetVersionCore -ErrorAction SilentlyContinue)){
  function ABP-GetVersionCore {
    param([Parameter(Mandatory=$true)][string]$V)
    $v2 = $V.Trim()
    $m = [regex]::Match($v2, '^(?<core>\d+\.\d+\.\d+)')
    if($m.Success){ return $m.Groups['core'].Value }
    return $v2
  }
}

# ABP_USE_NAME_BASENAME_V3H (use Name -> basename; avoid flaky .BaseName)
$bn = [IO.Path]::GetFileNameWithoutExtension($lastZip.Name)
if($bn -match "^AltioraBackupPro_(v\d+\.\d+\.\d+)(?:[A-Za-z0-9\.\+\-_]+)?_release$"){
    $version = $Matches[1]
    $version = "v" + (ABP-GetVersionCore ($version.TrimStart("v")))
}else{
    throw "Cannot parse version"
}
Write-Host ""
Write-Host "Release detected:" $version

# compute hash
$zipHash = (Get-FileHash $lastZip.FullName -Algorithm SHA256).Hash.ToUpper()

Write-Host "ZIP SHA256:" $zipHash
# --- sign release zip (Ed25519) ---
$privateKey = Join-Path $repoRoot "keys\altiora_private_key.pem"
$signScript = Join-Path $repoRoot "tools\sign_file.py"
$verifyScript = Join-Path $repoRoot "tools\verify_signature.py"
$publicKey = Join-Path $repoRoot "keys\altiora_public_key.pem"

if(-not (Test-Path -LiteralPath $privateKey)){ throw "Private key missing: $privateKey" }
if(-not (Test-Path -LiteralPath $signScript)){ throw "sign_file.py missing: $signScript" }
if(-not (Test-Path -LiteralPath $publicKey)){ throw "Public key missing: $publicKey" }
if(-not (Test-Path -LiteralPath $verifyScript)){ throw "verify_signature.py missing: $verifyScript" }

Write-Host "Signing release zip..."
& py $signScript $privateKey $lastZip.FullName | Out-Host

$localSig = "$($lastZip.FullName).sig"
if(-not (Test-Path -LiteralPath $localSig)){ throw "Signature not created: $localSig" }

# Verify signature locally (strict)
Write-Host "Verifying release signature..."
& py $verifyScript $publicKey $lastZip.FullName | Out-Host
if($LASTEXITCODE -ne 0){ throw "Release signature verification failed (local)" }

Write-Host "Release signature OK (local)"

# verify backup drives
$backupDirs = @("F:\ABP_RELEASES","H:\ABP_RELEASES")

foreach($d in $backupDirs){

    if(-not (Test-Path $d)){
        throw "Backup drive missing: $d"
    }

    $dest = Join-Path $d $lastZip.Name

    Copy-Item $lastZip.FullName $dest -Force
    # copy .sig alongside the zip
    Copy-Item -LiteralPath "$($lastZip.FullName).sig" -Destination "$dest.sig" -Force

    $destHash = (Get-FileHash $dest -Algorithm SHA256).Hash.ToUpper()

    if($destHash -ne $zipHash){
        throw "Hash mismatch on $d"
    }
    # verify signature on copied zip (strict)
    & py $verifyScript $publicKey $dest | Out-Host
    if($LASTEXITCODE -ne 0){ throw "Release signature verification failed on $d" }
    Write-Host "Backup verified:" $d
}

# update STATE.md
& "$repoRoot\tools\update_state_md.ps1"

# create STATE_HISTORY
$historyDir = Join-Path $repoRoot "_out\state_history"

if(-not (Test-Path $historyDir)){
    New-Item $historyDir -ItemType Directory | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Copy-Item `
(Join-Path $repoRoot "STATE.md") `
(Join-Path $historyDir "STATE_${version}_$timestamp.md")

Copy-Item `
(Join-Path $repoRoot "STATE.md.sha256") `
(Join-Path $historyDir "STATE_${version}_$timestamp.md.sha256")

Write-Host ""
# --- sign STATE.md ---
$statePath = Join-Path $repoRoot "STATE.md"
$stateSig  = "$statePath.sig"

Write-Host "Signing STATE.md..."
& py $signScript $privateKey $statePath | Out-Host

if(-not (Test-Path -LiteralPath $stateSig)){
    throw "STATE signature not created"
}

# verify STATE signature
& py $verifyScript $publicKey $statePath | Out-Host
if($LASTEXITCODE -ne 0){
    throw "STATE signature verification failed"
}

# copy STATE + signature to backup drives
foreach($d in $backupDirs){

    $dstState = "$d\STATE.md"
    $dstSig   = "$d\STATE.md.sig"

    Copy-Item $statePath $dstState -Force
    Copy-Item $stateSig  $dstSig  -Force

    if(-not (Test-Path -LiteralPath $dstState)){
        throw "STATE.md missing on $d after copy"
    }

    if(-not (Test-Path -LiteralPath $dstSig)){
        throw "STATE.md.sig missing on $d after copy"
    }

    & py $verifyScript $publicKey $dstState | Out-Host

    if($LASTEXITCODE -ne 0){
        throw "STATE signature invalid on $d"
    }

    Write-Host "STATE backed up and verified on $d"
}
Write-Host "STATE updated"
Write-Host "STATE_HISTORY recorded"
Write-Host ""
Write-Host "Release pipeline COMPLETE"











