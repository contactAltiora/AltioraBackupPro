$ErrorActionPreference="Stop"
. "$PSScriptRoot\safe_fs.ps1"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path

# Guardrail: must be repo root
if(!(Test-Path -LiteralPath (Join-Path $root "altiora.py"))){
  throw "Not in repo root. Do: Set-Location C:\Dev\AltioraBackupPro"
}

# ---- Inputs (must exist)
$exe      = Join-Path $root "dist\AltioraBackupPro.exe"
$state    = Join-Path $root "STATE.md"
$stateSig = Join-Path $root "STATE.md.sig"
$stateH   = Join-Path $root "STATE.md.sha256"
$pubPem   = Join-Path $root "keys\altiora_public_key.pem"

$relZip = Join-Path $root "_out\releases\AltioraBackupPro_v1.0.17_release.zip"
$relSig = Join-Path $root "_out\releases\AltioraBackupPro_v1.0.17_release.zip.sig"
$relSha = Join-Path $root "_out\releases\AltioraBackupPro_v1.0.17_release.sha256"

foreach($p in @($exe,$state,$stateSig,$stateH,$pubPem,$relZip,$relSig,$relSha)){
  if(!(Test-Path -LiteralPath $p)){ throw "Missing required file: $p" }
}

# ---- Bundle locations
$bundleDir = Join-Path $root "_out\bundles\AltioraBackupPro_v1.0.17_client_bundle"
$outZip    = Join-Path $root "_out\bundles\AltioraBackupPro_v1.0.17_client_bundle.zip"
$outSha    = Join-Path $root "_out\bundles\AltioraBackupPro_v1.0.17_client_bundle.sha256"

New-Item -ItemType Directory -Force $bundleDir | Out-Null
New-Item -ItemType Directory -Force (Split-Path $outZip) | Out-Null

# ---- Clean bundle dir
Safe-GetChildItem -LiteralPath $bundleDir -Force -OnError SilentlyContinue | Remove-Item -Recurse -Force -OnError SilentlyContinue

# ---- Layout
New-Item -ItemType Directory -Force (Join-Path $bundleDir "keys") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $bundleDir "_out\releases") | Out-Null

# ---- Copy minimal runtime (EXE + STATE + SIG + PUBKEY)
Copy-Item -LiteralPath $exe      -Destination (Join-Path $bundleDir "AltioraBackupPro.exe") -Force
Copy-Item -LiteralPath $state    -Destination (Join-Path $bundleDir "STATE.md") -Force
Copy-Item -LiteralPath $stateSig -Destination (Join-Path $bundleDir "STATE.md.sig") -Force
Copy-Item -LiteralPath $stateH   -Destination (Join-Path $bundleDir "STATE.md.sha256") -Force
Copy-Item -LiteralPath $pubPem   -Destination (Join-Path $bundleDir "keys\altiora_public_key.pem") -Force

# ---- Copy audit/support artifacts (optional but recommended)
Copy-Item -LiteralPath $relZip -Destination (Join-Path $bundleDir "_out\releases\AltioraBackupPro_v1.0.17_release.zip") -Force
Copy-Item -LiteralPath $relSig -Destination (Join-Path $bundleDir "_out\releases\AltioraBackupPro_v1.0.17_release.zip.sig") -Force
Copy-Item -LiteralPath $relSha -Destination (Join-Path $bundleDir "_out\releases\AltioraBackupPro_v1.0.17_release.sha256") -Force

# ---- README
@"
ALTIORA BACKUP PRO — Client Bundle v1.0.17

CONTENTS
- AltioraBackupPro.exe
- STATE.md + STATE.md.sig + STATE.md.sha256
- keys\altiora_public_key.pem
- _out\releases\AltioraBackupPro_v1.0.17_release.zip (+ .sig + .sha256)  [audit/support]

INSTALL (Windows)
1) Copier ce dossier dans un chemin de confiance, ex:
   C:\ProgramData\AltioraBackupPro\

2) Activer le mode protégé (recommandé):
   setx ALTIORA_PROTECTED 1
   (relancer la session)

3) Tester:
   AltioraBackupPro.exe --version
   AltioraBackupPro.exe --help

PROTECTED MODE (fail-closed)
- Si ALTIORA_PROTECTED=1, l'app refuse de démarrer si:
  - STATE.md ou STATE.md.sig manquent
  - la signature Ed25519 de STATE.md est invalide
  - STATE.md.sha256 existe et ne correspond pas
  - le SHA256 du release ZIP ne correspond pas au .sha256 (si les fichiers existent)

SUPPORT
- Garder le dossier complet (dont _out\releases) pour audit et support.
"@ | Set-Content -LiteralPath (Join-Path $bundleDir "README_INSTALL.txt") -Encoding UTF8

# ---- Helper BAT (optional)
@"
@echo off
setlocal
echo Setting protected mode...
setx ALTIORA_PROTECTED 1 >nul
echo Done. Please reopen your terminal.
pause
"@ | Set-Content -LiteralPath (Join-Path $bundleDir "INSTALL_PROTECTED_MODE.bat") -Encoding ASCII

@"
@echo off
setlocal
echo Running version...
AltioraBackupPro.exe --version
echo.
echo Running help...
AltioraBackupPro.exe --help
pause
"@ | Set-Content -LiteralPath (Join-Path $bundleDir "SMOKE_TEST.bat") -Encoding ASCII

# ---- Zip bundle
if(Test-Path -LiteralPath $outZip){ Remove-Item -LiteralPath $outZip -Force }
Compress-Archive -Path (Join-Path $bundleDir "*") -DestinationPath $outZip -Force

# ---- Bundle sha256
$h = (Get-FileHash -LiteralPath $outZip -Algorithm SHA256).Hash
Set-Content -LiteralPath $outSha -Value $h -Encoding ASCII

Write-Host "OK BUNDLE DIR : $bundleDir"
Write-Host "OK BUNDLE ZIP : $outZip"
Write-Host "OK BUNDLE SHA : $outSha"
Write-Host "SHA256        : $h"

# ---- Quick isolated test (STRICT)
$testDir = Join-Path $env:TEMP "ABP_CLIENT_TEST_1016_OK"
Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $testDir | Out-Null

Expand-Archive -LiteralPath $outZip -DestinationPath $testDir -Force

# Defender/AV can delete the EXE after extraction -> fail fast if missing
$exeInTest = Join-Path $testDir "AltioraBackupPro.exe"
if(!(Test-Path -LiteralPath $exeInTest)){
  throw "Isolated test failed: EXE missing after extraction (possible AV quarantine): $exeInTest"
}

# Verify STATE signature in extracted bundle using python verifier (no EXE recursion)
$pubInTest   = Join-Path $testDir "keys\altiora_public_key.pem"
$stateInTest = Join-Path $testDir "STATE.md"
if(!(Test-Path -LiteralPath $pubInTest)){ throw "Isolated test failed: missing pubkey: $pubInTest" }
if(!(Test-Path -LiteralPath $stateInTest)){ throw "Isolated test failed: missing STATE.md: $stateInTest" }

Push-Location $testDir
try{
  Write-Host "TEST: verify STATE signature in bundle..."
  & python ".\tools\verify_signature.py" ".\keys\altiora_public_key.pem" ".\STATE.md"
  $code = $LASTEXITCODE
  if($code -ne 0){
    throw "Isolated test failed: STATE signature invalid (python verify exit=$code)"
  }

  # Force protected mode only for the EXE test
  $env:ALTIORA_PROTECTED = "1"

  Write-Host "TEST: running EXE from isolated dir: $testDir"
  & ".\AltioraBackupPro.exe" --version
  $code = $LASTEXITCODE
  if($code -ne 0){
    throw "Isolated test failed: EXE --version returned exit=$code"
  }

  & ".\AltioraBackupPro.exe" --help
  $code = $LASTEXITCODE
  if($code -ne 0){
    throw "Isolated test failed: EXE --help returned exit=$code"
  }

  Write-Host "OK: isolated client bundle test passed"
}
finally{
  Pop-Location
  Remove-Item Env:\ALTIORA_PROTECTED -ErrorAction SilentlyContinue
}



