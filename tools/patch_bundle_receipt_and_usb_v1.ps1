$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$rootExpected = "C:\Dev\AltioraBackupPro"
if($root.TrimEnd('\') -ne $rootExpected){
  throw "bundle_patch_v1: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "bundle_patch_v1: $m" }

function Ensure-File($path, $content){
  $dir = Split-Path -Parent $path
  if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}

# --- (A) bundle_BACKUP_PRO_ALTIORA.ps1 (avec receipt + vérif existence) ---
$bundlePath = Join-Path $root "tools\bundle_BACKUP_PRO_ALTIORA.ps1"

$bundleContent = @'
$ErrorActionPreference="Stop"

$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "BUNDLE: $m" }

# Trouver la release ZIP la plus récente
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

# Copie livrables
Copy-Item -LiteralPath $exe -Destination (Join-Path $staging "AltioraBackupPro.exe") -Force
Copy-Item -LiteralPath $relZip.FullName -Destination (Join-Path $staging $relZip.Name) -Force
Copy-Item -LiteralPath $relSha -Destination (Join-Path $staging (Split-Path $relSha -Leaf)) -Force

# Source repo (subset propre)
$srcOut = Join-Path $staging "source_repo"
New-Item -ItemType Directory -Force -Path $srcOut | Out-Null

$includePaths = @("src","tools","altiora.py","README.md","requirements.txt","requirements-build.txt")
foreach($p in $includePaths){
  $fp = Join-Path $root $p
  if(Test-Path $fp){
    Copy-Item -LiteralPath $fp -Destination (Join-Path $srcOut $p) -Recurse -Force
  }
}

# ZIP final (1 fichier)
$bundleZip = Join-Path $root "_out\BACKUP PRO ALTIORA.zip"
if(Test-Path $bundleZip){ Remove-Item -LiteralPath $bundleZip -Force }

Compress-Archive -LiteralPath $staging\* -DestinationPath $bundleZip -Force

# Vérifier existence réelle
if(!(Test-Path $bundleZip)){
  Fail "ZIP non créé: $bundleZip"
}

# Receipt (chemin exact)
$receipt = Join-Path $root "_out\bundle_receipt_BACKUP_PRO_ALTIORA.txt"
Set-Content -LiteralPath $receipt -Value $bundleZip -Encoding UTF8

Write-Host "✅ BUNDLE OK: $bundleZip"
Write-Host "Receipt: $receipt"
Write-Host "Contenu: EXE + release zip + sha256 + source (subset)"
'@

Ensure-File -path $bundlePath -content $bundleContent

# --- (B) bundle_BACKUP_PRO_ALTIORA_to_usb.ps1 (lit receipt; copie F/H; sha check) ---
$usbPath = Join-Path $root "tools\bundle_BACKUP_PRO_ALTIORA_to_usb.ps1"

$usbContent = @'
$ErrorActionPreference="Stop"

$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "BUNDLE-USB: $m" }

$bundleScript = Join-Path $root "tools\bundle_BACKUP_PRO_ALTIORA.ps1"
if(!(Test-Path $bundleScript)){
  Fail "Script bundle introuvable: $bundleScript"
}

Write-Host "[BUNDLE-USB] Génération bundle..."
& $bundleScript

$receipt = Join-Path $root "_out\bundle_receipt_BACKUP_PRO_ALTIORA.txt"
if(!(Test-Path $receipt)){
  Fail "Receipt introuvable après génération: $receipt"
}

$bundleZip = (Get-Content -LiteralPath $receipt -Encoding UTF8 -Raw).Trim()
if([string]::IsNullOrWhiteSpace($bundleZip)){
  Fail "Receipt vide: $receipt"
}
if(!(Test-Path $bundleZip)){
  Fail "ZIP indiqué par receipt introuvable: $bundleZip"
}

$bundleName = Split-Path $bundleZip -Leaf
Write-Host "[BUNDLE-USB] Bundle (receipt): $bundleZip"

$localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $bundleZip).Hash
$localSize = (Get-Item -LiteralPath $bundleZip).Length
Write-Host "[BUNDLE-USB] Local size: $localSize bytes"
Write-Host "[BUNDLE-USB] Local sha256: $localHash"

$drives = @("F:","H:")
$copied = 0

foreach($d in $drives){
  if(!(Test-Path "$d\")){
    Write-Host "[BUNDLE-USB] Drive absent: $d (skip)"
    continue
  }

  $destDir = Join-Path $d "ABP_RELEASES"
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null

  $destZip = Join-Path $destDir $bundleName

  Write-Host "[BUNDLE-USB] Copy -> $destZip"
  Copy-Item -LiteralPath $bundleZip -Destination $destZip -Force

  $destSize = (Get-Item -LiteralPath $destZip).Length
  if($destSize -ne $localSize){
    Fail "Taille différente sur $d : local=$localSize vs dest=$destSize"
  }

  $destHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destZip).Hash
  if($destHash -ne $localHash){
    Fail "SHA256 différent sur $d : local=$localHash vs dest=$destHash"
  }

  $shaPath = Join-Path $destDir ([IO.Path]::GetFileNameWithoutExtension($bundleName) + ".sha256")
  Set-Content -LiteralPath $shaPath -Value ($localHash + "  " + $bundleName) -Encoding ASCII

  Write-Host "[BUNDLE-USB] OK: $d"
  $copied++
}

if($copied -eq 0){
  Fail "Aucun disque cible trouvé (F: et H: absents)."
}

Write-Host "============================================================"
Write-Host "✅ DONE: bundle copié et vérifié sur $copied drive(s)"
Write-Host "============================================================"
'@

Ensure-File -path $usbPath -content $usbContent

Write-Host "[PATCH] OK: bundle scripts updated (receipt + usb copy)"