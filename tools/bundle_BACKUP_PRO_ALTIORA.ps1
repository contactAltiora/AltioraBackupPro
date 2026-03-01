$ErrorActionPreference="Stop"
. "$PSScriptRoot\safe_fs.ps1"


$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "BUNDLE: $m" }

$outDir = Join-Path $root "_out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Trouver la release ZIP la plus rÃ©cente
$relZip = Get-ChildItem -LiteralPath "$root\_out\releases" -Filter "AltioraBackupPro_v*_release.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if(-not $relZip){ Fail "Release ZIP introuvable dans _out\releases (lance release_build_and_backup.ps1 d'abord)" }

$relSha = "$($relZip.FullName -replace '\.zip$','.sha256')"
if(!(Test-Path $relSha)){ Fail "SHA256 introuvable: $relSha" }

$exe = "$root\dist\AltioraBackupPro.exe"
if(!(Test-Path $exe)){ Fail "EXE introuvable: $exe" }

# Staging
$staging = Join-Path $root "_out\bundle_BACKUP_PRO_ALTIORA"
if(Test-Path $staging){ Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Copy-Item -LiteralPath $exe -Destination (Join-Path $staging "AltioraBackupPro.exe") -Force
Copy-Item -LiteralPath $relZip.FullName -Destination (Join-Path $staging $relZip.Name) -Force
Copy-Item -LiteralPath $relSha -Destination (Join-Path $staging (Split-Path $relSha -Leaf)) -Force

# Source repo (subset)
$srcOut = Join-Path $staging "source_repo"
New-Item -ItemType Directory -Force -Path $srcOut | Out-Null
$includePaths = @("src","tools","altiora.py","README.md","requirements.txt","requirements-build.txt")
foreach($p in $includePaths){
  $fp = Join-Path $root $p
  if(Test-Path $fp){
    Copy-Item -LiteralPath $fp -Destination (Join-Path $srcOut $p) -Recurse -Force
  }
}

# --- CLEAN source_repo ---
# On nettoie uniquement les artefacts inutiles dans source_repo (pycache/pyc/bak/old)
$srcRepo = Join-Path $staging "source_repo"
if(Test-Path $srcRepo){
  # 1) dossiers __pycache__
Safe-GetChildItem -LiteralPath $srcRepo -Recurse -Directory -Force -OnError SilentlyContinue |
    Where-Object { $_.Name -ieq "__pycache__" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

  # 2) fichiers *.pyc
Safe-GetChildItem -LiteralPath $srcRepo -Recurse -File -Force -OnError SilentlyContinue |
    Where-Object { $_.Extension -ieq ".pyc" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }

  # 3) fichiers *.bak / *.old (souvent du bruit dans les bundles)
Safe-GetChildItem -LiteralPath $srcRepo -Recurse -File -Force -OnError SilentlyContinue |
    Where-Object { $_.Extension -ieq ".bak" -or $_.Extension -ieq ".old" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}
# --- DIAG staging ---
$files = Get-ChildItem -LiteralPath $staging -Recurse -File -ErrorAction SilentlyContinue
$cnt   = @($files).Count
$bytes = 0
foreach($f in $files){ $bytes += $f.Length }

Write-Host "[BUNDLE] staging=$staging"
Write-Host "[BUNDLE] files=$cnt bytes=$bytes"
if($cnt -eq 0){
  Fail "staging vide (aucun fichier copiÃ©)."
}

Write-Host "[BUNDLE] sample files:"
$files | Select-Object -First 30 FullName,Length | Format-Table -AutoSize | Out-String | Write-Host

# ZIP via ZipFile
Add-Type -AssemblyName System.IO.Compression.FileSystem

$finalZip = Join-Path $outDir "BACKUP PRO ALTIORA.zip"
$tmpZip   = Join-Path $outDir "BACKUP_PRO_ALTIORA.tmp.zip"

if(Test-Path $tmpZip){ Remove-Item -LiteralPath $tmpZip -Force }
if(Test-Path $finalZip){ Remove-Item -LiteralPath $finalZip -Force }

try{
  [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $tmpZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
}catch{
  Write-Host "[BUNDLE] ZipFile FAILED: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
  Write-Host "[BUNDLE] Diagnostic listing _out:"
Safe-GetChildItem -LiteralPath $outDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
  throw
}

if(!(Test-Path $tmpZip)){
  Write-Host "[BUNDLE] Diagnostic listing _out:"
Safe-GetChildItem -LiteralPath $outDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
  Fail "ZIP temp non crÃ©Ã©: $tmpZip"
}

Move-Item -LiteralPath $tmpZip -Destination $finalZip -Force

if(!(Test-Path $finalZip)){
  Write-Host "[BUNDLE] Diagnostic listing _out:"
Safe-GetChildItem -LiteralPath $outDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
  Fail "ZIP final non crÃ©Ã©: $finalZip"
}

$receipt = Join-Path $outDir "bundle_receipt_BACKUP_PRO_ALTIORA.txt"
Set-Content -LiteralPath $receipt -Value $finalZip -Encoding UTF8

Write-Host "âœ… BUNDLE OK: $finalZip"
Write-Host "Receipt: $receipt"
Write-Host "Contenu: EXE + release zip + sha256 + source (subset)"

