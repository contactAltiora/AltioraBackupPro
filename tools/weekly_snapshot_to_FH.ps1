# tools\weekly_snapshot_to_FH.ps1
# Weekly full snapshot -> ZIP + copy to F: and H: + retention
# Windows PowerShell 5.1 compatible

[CmdletBinding()]
param(
  [string]$RepoRoot = "C:\Dev\AltioraBackupPro",
  [string[]]$BackupRoots = @("F:\ALTIORA_RECOVERY", "H:\ALTIORA_RECOVERY"),
  [int]$KeepLast = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir([string]$p){
  if(-not (Test-Path -LiteralPath $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Fail([string]$m){ throw $m }

# --- Validate repo ---
if(-not (Test-Path -LiteralPath $RepoRoot)){
  Fail "RepoRoot introuvable: $RepoRoot"
}

# --- Validate backup roots ---
foreach($br in $BackupRoots){
  if(-not (Test-Path -LiteralPath $br)){
    Fail "Backup root manquant (disque non montÃ© ?) : $br"
  }
}

# --- Paths ---
$outDir = Join-Path $RepoRoot "_out\snapshots_weekly"
Ensure-Dir $outDir

$logDir = Join-Path $RepoRoot "_out\logs"
Ensure-Dir $logDir

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$zipName = "AltioraBackupPro_WEEKLY_$ts.zip"
$zipLocal = Join-Path $outDir $zipName
$logPath = Join-Path $logDir ("weekly_snapshot_$ts.log")

# --- Logging helper ---
function Log([string]$m){
  $line = ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m)
  $line | Tee-Object -FilePath $logPath -Append | Out-Host
}

Log "=== WEEKLY SNAPSHOT START ==="
Log "RepoRoot: $RepoRoot"
Log "Local snapshot dir: $outDir"
Log "ZIP: $zipLocal"
Log "KeepLast: $KeepLast"

# --- Create zip snapshot ---
if(Test-Path -LiteralPath $zipLocal){ Remove-Item -LiteralPath $zipLocal -Force }

# Exclusions (safe defaults): venv folders + heavy caches
# Adjust if you want to include them.
$excludeDirs = @(
  ".venv", ".venv_build", "__pycache__", ".pytest_cache", ".mypy_cache",
  "node_modules"
)

# We create a temp staging list for Compress-Archive by copying with Robocopy
# to ensure exclusions are respected.
$stage = Join-Path $outDir ("_stage_$ts")
Ensure-Dir $stage

Log "Staging to: $stage (with exclusions)"

# Build robocopy exclusion args
$xd = @()
foreach($d in $excludeDirs){
  $xd += @("/XD", (Join-Path $RepoRoot $d))
}
# Also exclude the output folder itself to avoid recursion
$xd += @("/XD", (Join-Path $RepoRoot "_out"))

# Copy repo -> stage (mirror-like but only one-way)
# /E include subdirs, /R:1 /W:1 minimal retries, /NFL /NDL reduce noise
$rc = & robocopy $RepoRoot $stage /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP $xd
# Robocopy returns codes >= 8 for failures
if($LASTEXITCODE -ge 8){
  Fail "Robocopy staging failed with exit code $LASTEXITCODE"
}
Log "Staging OK (robocopy exit code: $LASTEXITCODE)"

Log "Compress-Archive -> $zipLocal"

# Sanity: stage not empty
$stageItems = Get-ChildItem -LiteralPath $stage -Force
if(-not $stageItems -or $stageItems.Count -eq 0){
  Fail "Stage vide: rien Ã  zipper ($stage)"
}

# IMPORTANT: use -Path (wildcards allowed), not -LiteralPath
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipLocal -Force

# Some PS5.1 edge cases: zip may end up in current directory
if(-not (Test-Path -LiteralPath $zipLocal)){
  $alt = Join-Path (Get-Location).Path (Split-Path -Leaf $zipLocal)
  if(Test-Path -LiteralPath $alt){
    Move-Item -LiteralPath $alt -Destination $zipLocal -Force
  }
}

Log "ZIP created"

# Wait until file exists (PowerShell 5.1 safety)
$maxWait = 10
$waited = 0
while(-not (Test-Path -LiteralPath $zipLocal)){
    Start-Sleep -Milliseconds 300
    $waited++
    if($waited -gt ($maxWait * 3)){
        Fail "ZIP introuvable aprÃ¨s compression: $zipLocal"
    }
}

# Cleanup stage
Remove-Item -LiteralPath $stage -Recurse -Force
Log "Stage cleaned"

# Compute hash safely
$hashObj = Get-FileHash -LiteralPath $zipLocal -Algorithm SHA256
if(-not $hashObj){
    Fail "Impossible de calculer le hash"
}
$zipHash = $hashObj.Hash.ToUpper()

$hashFileLocal = "$zipLocal.sha256"
$zipHash | Set-Content -LiteralPath $hashFileLocal -Encoding ASCII
Log "ZIP SHA256: $zipHash"
Log "SHA256 file: $hashFileLocal"

# --- Copy to backup drives ---
foreach($br in $BackupRoots){
  $snapDir = Join-Path $br "04_SOURCE_SNAPSHOT\weekly"
  Ensure-Dir $snapDir

  $destZip = Join-Path $snapDir $zipName
  $destSha = "$destZip.sha256"

  Log "Copy -> $destZip"
  Copy-Item -LiteralPath $zipLocal -Destination $destZip -Force
  Copy-Item -LiteralPath $hashFileLocal -Destination $destSha -Force

  # Verify hash on destination
  $destHash = (Get-FileHash -LiteralPath $destZip -Algorithm SHA256).Hash.ToUpper()
  if($destHash -ne $zipHash){
    Fail "Hash mismatch after copy on $br (destHash != zipHash)"
  }
  Log "Verified OK on $br"
}

# --- Retention (keep last N) on local + each backup ---
function Apply-Retention([string]$dir, [int]$keep){
  if(-not (Test-Path -LiteralPath $dir)){ return }

  # Force array to avoid StrictMode issues when 0 or 1 item is returned
  $zips = @(Get-ChildItem -LiteralPath $dir -Filter "AltioraBackupPro_WEEKLY_*.zip" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)

  if($zips.Length -le $keep){ return }

  $toRemove = $zips | Select-Object -Skip $keep
  foreach($f in $toRemove){
    $sha = "$($f.FullName).sha256"
    Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sha -Force -ErrorAction SilentlyContinue
  }
}


Log "Retention local..."
Apply-Retention -dir $outDir -keep $KeepLast

foreach($br in $BackupRoots){
  $snapDir = Join-Path $br "04_SOURCE_SNAPSHOT\weekly"
  Log "Retention on $snapDir ..."
  Apply-Retention -dir $snapDir -keep $KeepLast
}

Log "=== WEEKLY SNAPSHOT COMPLETE ==="
Log "Local ZIP: $zipLocal"
Log "SHA256: $zipHash"
# --- cryptographic signature ---
$privateKey = Join-Path $RepoRoot "keys\altiora_private_key.pem"
$signScript = Join-Path $RepoRoot "tools\sign_file.py"

if(Test-Path $privateKey){

    Log "Signing snapshot..."

    py $signScript $privateKey $zipLocal

    $sigLocal = "$zipLocal.sig"

    foreach($br in $BackupRoots){

        $destDir = Join-Path $br "04_SOURCE_SNAPSHOT\weekly"

        Copy-Item $sigLocal $destDir -Force

    }

    Log "Signature created and copied"

}else{

    Log "WARNING: private key not found, snapshot not signed"

}
# --- Write LAST_RUN_STATUS ---
$statusText = @"
ALTIORA WEEKLY SNAPSHOT STATUS
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Result: SUCCESS

ZIP:
$zipLocal

SHA256:
$zipHash

Machine:
$env:COMPUTERNAME
"@

# local status
$statusLocal = Join-Path $RepoRoot "_out\LAST_WEEKLY_SNAPSHOT_STATUS.txt"
$statusText | Set-Content -LiteralPath $statusLocal -Encoding UTF8

# external status
foreach($br in $BackupRoots){

    $statusDir = Join-Path $br "STATUS"
    if(-not (Test-Path $statusDir)){
        New-Item -ItemType Directory -Force -Path $statusDir | Out-Null
    }

    $statusPath = Join-Path $statusDir "LAST_WEEKLY_SNAPSHOT_STATUS.txt"

    $statusText | Set-Content -LiteralPath $statusPath -Encoding UTF8
}

Log "STATUS files updated"
