$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$p = Join-Path (Get-Location).Path "tools\snapshot_double_backup_C.ps1"
if(-not (Test-Path -LiteralPath $p)){ throw "FAIL-CLOSED: tools\snapshot_double_backup_C.ps1 introuvable." }

# Fail-closed: on n'écrase que si on reconnait notre script
$old = Get-Content -LiteralPath $p -Encoding UTF8 -Raw
if(($old -notmatch "Snapshot double backup finished") -and ($old -notmatch "Snapshot C \\+ double sauvegarde")){
  throw "FAIL-CLOSED: snapshot_double_backup_C.ps1 ne semble pas être notre version (refuse overwrite)."
}

$fixed = @'
# Altiora Backup Pro
# ABP_SNAPSHOT_DOUBLE_BACKUP_C_V1
# Snapshot C + double sauvegarde vers F:\ABP_SNAPSHOTS et H:\ABP_SNAPSHOTS
# - Sans backticks (évite bug Compress-Archive)
# - Exclut _out\snapshots\* (évite auto-inclusion)

Stop = "Stop"

 = Resolve-Path (Join-Path  "..")
Set-Location  | Out-Null

 = Get-Date -Format "yyyyMMdd_HHmmss"
 = Join-Path  "_out\snapshots"
New-Item -ItemType Directory -Force  | Out-Null

 = Join-Path  ("ABP_C_" +  + ".zip")
Write-Host "Creating snapshot: "

# Assure que le chemin d'exclusion est bien formé
 = @(
  (Join-Path  "_out\snapshots\*")
)

# On compresse tout le repo (incluant _out) mais on exclut _out\snapshots
Compress-Archive -Path (Join-Path  "*") -DestinationPath  -Force -CompressionLevel Optimal -Exclude 

Write-Host "Snapshot created."

# destinations officielles
 = @("F:\ABP_SNAPSHOTS", "H:\ABP_SNAPSHOTS")

foreach( in ){
  if(Test-Path (.Substring(0,3))){
    New-Item -ItemType Directory -Force  | Out-Null
    Write-Host "Copying snapshot to "
    Copy-Item -LiteralPath  -Destination  -Force
  } else {
    Write-Host "WARN: drive missing -> "
  }
}

Write-Host "Snapshot double backup finished."
'@

Set-Content -LiteralPath $p -Value $fixed -Encoding UTF8
Write-Host "OK: fixed -> tools\snapshot_double_backup_C.ps1 (V1)"
