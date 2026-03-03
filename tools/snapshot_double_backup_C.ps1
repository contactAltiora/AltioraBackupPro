# Altiora Backup Pro
# ABP_SNAPSHOT_DOUBLE_BACKUP_C_V3
# Snapshot C + double sauvegarde vers F:\ABP_SNAPSHOTS et H:\ABP_SNAPSHOTS
# Compatible Windows PowerShell 5.1 (pas de -Exclude sur Compress-Archive)
# Exclut _out\snapshots\* en construisant la liste de fichiers à compresser.

$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repo | Out-Null

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = Join-Path $repo "_out\snapshots"
New-Item -ItemType Directory -Force $outDir | Out-Null

$zip = Join-Path $outDir ("ABP_C_" + $ts + ".zip")
Write-Host "Creating snapshot: $zip"

# Build file list excluding _out\snapshots\*
$snapshotsDir = (Join-Path $repo "_out\snapshots")
$files = Get-ChildItem -LiteralPath $repo -Recurse -File -Force -ErrorAction Stop |
  Where-Object {
    # Exclude anything under _out\snapshots
    ($_.FullName -notlike ($snapshotsDir + "\*"))
  } |
  Select-Object -ExpandProperty FullName

if(-not $files -or $files.Count -eq 0){
  throw "No files to compress (unexpected)."
}

Compress-Archive -LiteralPath $files -DestinationPath $zip -Force -CompressionLevel Optimal
Write-Host "Snapshot created."

$dests = @("F:\ABP_SNAPSHOTS", "H:\ABP_SNAPSHOTS")
foreach($d in $dests){
  $driveRoot = $d.Substring(0,3)
  if(Test-Path $driveRoot){
    New-Item -ItemType Directory -Force $d | Out-Null
    Write-Host "Copying snapshot to $d"
    Copy-Item -LiteralPath $zip -Destination $d -Force
  } else {
    Write-Host "WARN: drive missing -> $driveRoot"
  }
}

Write-Host "Snapshot double backup finished."
