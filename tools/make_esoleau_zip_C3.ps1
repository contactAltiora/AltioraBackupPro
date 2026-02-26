[CmdletBinding()]
param(
  [string]$Root = "C:\Dev\AltioraBackupPro",
  [string]$Label = "C3",
  [switch]$IncludeRepoTree
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Dir([string]$p){
  if(!(Test-Path $p)){
    New-Item -ItemType Directory -Force $p | Out-Null
  }
}

function Hash-SHA256([string]$p){
  (Get-FileHash $p -Algorithm SHA256).Hash.ToUpperInvariant()
}

$timestamp = Get-Date -Format "yyyy-MM-dd__HHmmss"
$commit = (git -C $Root rev-parse --short HEAD)

$outBase = Join-Path $Root "_out\esoleau"
Assert-Dir $outBase

$tempDir = Join-Path $outBase "AltioraBackupPro_${Label}_$timestamp"
Assert-Dir $tempDir

# --- Fichiers principaux
Copy-Item "$Root\altiora.py" "$tempDir\" -Force
Copy-Item "$Root\src" "$tempDir\src" -Recurse -Force
Copy-Item "$Root\docs" "$tempDir\docs" -Recurse -Force
Copy-Item "$Root\tools\release_build_and_backup.ps1" "$tempDir\" -Force

# --- Release ZIP si existe
$releaseZip = Get-ChildItem "$Root\_out\releases\*.zip" | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if($releaseZip){
  Copy-Item $releaseZip.FullName "$tempDir\" -Force
}

# --- Manifest
$manifest = @"
ALTlORA BACKUP PRO — PREUVE TECHNIQUE
Date       : $timestamp
Commit     : $commit
Label      : $Label

Contenu :
- Code source complet
- Docs sécurité
- Script B2
- Release build
- SHA256 généré

© Altiora
"@

$manifest | Set-Content (Join-Path $tempDir "MANIFEST.txt") -Encoding UTF8

# --- Repo tree optionnel
if($IncludeRepoTree){
  tree $Root /F | Out-File (Join-Path $tempDir "REPO_TREE.txt")
}

# --- ZIP final
$zipPath = Join-Path $outBase "AltioraBackupPro_eSoleau_${Label}_$timestamp.zip"
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "✅ ZIP e-Soleau créé :" -ForegroundColor Green
Write-Host $zipPath -ForegroundColor Cyan


