<#  tools\release_build_and_backup.ps1
    Altiora Backup Pro — Release builder (deterministic)

    Steps:
      1) Ensure .venv_build exists (create if missing)
      2) Install/upgrade pip + pyinstaller + cryptography (or requirements-build.txt if present)
      3) Clean build artifacts (optional)
      4) Build onefile EXE via PyInstaller
      5) Smoke tests using the built EXE
      6) Create release folder: _release\vX.Y.Z\ (EXE renamed + SHA256 + README)
      7) Zip release to: _out\releases\AltioraBackupPro_vX.Y.Z_release.zip (+ SHA256)
      8) Copy zip (+ sha) to drives F:, H: -> ABP_RELEASES
#>

[CmdletBinding()]
param([switch]$NoUsbRequired, 
[string]$Root = "C:\Dev\AltioraBackupPro",
  [string]$Version = "",                 # optional, auto-detect if empty
  [string]$BuildVenv = ".venv_build",
  [switch]$CleanBuild,                   # if set: remove build/, dist/, *.spec before build
  [switch]$SkipTests,                    # if set: skip smoke tests
  [string]$ProPrice = "49,99€/mois",
  [string]$FreeRestoreLimit = "1 GiB",
  [string[]]$Drives = @("F:","H:"),
  [string]$ReleaseBase = "_release",
  [string]$OutReleases = "_out\releases"
)

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

$__ABP_NO_USB_REQUIRED = $NoUsbRequired

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "safe_fs.ps1")
. "$PSScriptRoot\safe_fs.ps1"

# BEGIN ABP_GATE_SELFTEST_NONCE
# ------------------------------------------------------------
# ULTRA STRICT GATE : selftest crypto nonce (fixture versionnée)
# Config via env: ABP_SELFTEST_PASSWORD (required), ABP_SELFTEST_N (default 10)
# ------------------------------------------------------------

$fixture = Join-Path (Get-Location).Path "_fixtures\selftest_src"
if(!(Test-Path $fixture)){ throw "Fixture selftest introuvable: $fixture" }
if(-not (Get-ChildItem $fixture -File)){ throw "Fixture vide: $fixture" }

$st = Join-Path $PSScriptRoot "selftest_crypto_nonce.ps1"
if(!(Test-Path $st)){ throw "Selftest introuvable: $st" }

$pwd = $env:ABP_SELFTEST_PASSWORD
if([string]::IsNullOrWhiteSpace($pwd)){ throw "ABP_SELFTEST_PASSWORD requis pour lancer la release" }

$n = 10
if(-not [string]::IsNullOrWhiteSpace($env:ABP_SELFTEST_N)){
  $tmp = 0
  if(-not [int]::TryParse($env:ABP_SELFTEST_N, [ref]$tmp)){ throw "ABP_SELFTEST_N invalide (int attendu): $env:ABP_SELFTEST_N" }
  if($tmp -lt 1 -or $tmp -gt 200){ throw "ABP_SELFTEST_N hors bornes (1..200): $tmp" }
  $n = $tmp
}

Write-Host ("RUN SELFTEST (ULTRA STRICT) N={0}" -f $n)
$ps = (Get-Command powershell).Source
$args = @(
  "-NoProfile","-ExecutionPolicy","Bypass",
  "-File",$st,
  "-N",$n.ToString(),
  "-Password",$pwd,
  "-SourceDir",$fixture,
  "-AltioraPy",(Join-Path (Get-Location).Path "altiora.py")
)

$p = Start-Process -FilePath $ps -ArgumentList $args -NoNewWindow -Wait -PassThru
if($p.ExitCode -ne 0){ throw ("Selftest crypto nonce FAILED (exit={0}) => RELEASE ABORTED" -f $p.ExitCode) }
Write-Host "SELFTEST OK"
# END ABP_GATE_SELFTEST_NONCE
# ------------------------------------------------------------
# Gate release: selftest crypto nonce/salt (deterministic)
# Fail the release if exit code != 0

function Assert-Dir([string]$p){
  if(!(Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p | Out-Null
  }
}

function Hash-SHA256([string]$p){
  return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-RepoCommitShort([string]$repo){
  try{
    $c = (git -C $repo rev-parse --short HEAD 2>$null)
    if($LASTEXITCODE -eq 0 -and $c){ return $c.Trim() }
  } catch {}
  return ""
}

function Detect-Version([string]$repo){
  try{
    Push-Location $repo
    $out = & python ".\altiora.py" "--version" 2>$null
    Pop-Location

    if($out){
      foreach($line in $out){
        $m = [regex]::Match($line, "v(\d+\.\d+\.\d+)")
        if($m.Success){ return $m.Groups[1].Value }
      }
    }
  } catch {
    try { Pop-Location } catch {}
  }

  try{
    $d = (git -C $repo describe --tags --abbrev=0 2>$null)
    if($LASTEXITCODE -eq 0 -and $d){
      $d = $d.Trim()
      if($d.StartsWith("v")){ return $d.Substring(1) }
      return $d
    }
  } catch {}

  throw "Impossible de détecter la version. Passe -Version '1.0.12' en paramètre."
}

function Ensure-BuildVenv([string]$repo,[string]$venvRel){
  $venvPath = Join-Path $repo $venvRel
  $py = Join-Path $venvPath "Scripts\python.exe"

  if(!(Test-Path -LiteralPath $py)){
    Write-Host "▶ Création venv build: $venvPath" -ForegroundColor Cyan
    Push-Location $repo
    & python -m venv $venvRel
    Pop-Location
  }

  if(!(Test-Path -LiteralPath $py)){
    throw "Venv build introuvable ou invalide: $py"
  }

  Write-Host "▶ Upgrade pip" -ForegroundColor Cyan
  & $py -m pip install --upgrade pip | Out-Null

  $reqBuild = Join-Path $repo "requirements-build.txt"
  if(Test-Path -LiteralPath $reqBuild){
    Write-Host "▶ Install requirements-build.txt" -ForegroundColor Cyan
    & $py -m pip install -r $reqBuild | Out-Null
  } else {
    Write-Host "▶ Install pyinstaller + cryptography (fallback)" -ForegroundColor Cyan
    & $py -m pip install pyinstaller cryptography | Out-Null
  }

  return $py
}

function Clean-BuildArtifacts([string]$repo){
  Write-Host "▶ Clean build artifacts (build/, dist/, *.spec)" -ForegroundColor Yellow
  $build = Join-Path $repo "build"
  $dist  = Join-Path $repo "dist"
  if(Test-Path $build){ Remove-Item -Recurse -Force $build -ErrorAction SilentlyContinue }
  if(Test-Path $dist){ Remove-Item -Recurse -Force $dist -ErrorAction SilentlyContinue }
Get-ChildItem -LiteralPath $repo -Filter "*.spec" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
  }
}

function Build-Exe([string]$repo,[string]$py){
  Write-Host "▶ Build EXE (PyInstaller onefile)" -ForegroundColor Cyan
  Push-Location $repo
  if(!(Test-Path -LiteralPath ".\altiora.py")){ throw "altiora.py introuvable dans $repo" }

  & $py -m PyInstaller --noconfirm --clean --onefile --name "AltioraBackupPro" ".\altiora.py"
  Pop-Location

  $exe = Join-Path $repo "dist\AltioraBackupPro.exe"
  if(!(Test-Path -LiteralPath $exe)){ throw "EXE non généré: $exe" }
  return $exe
}

function Smoke-Tests([string]$repo,[string]$exe){
  Write-Host "▶ Smoke tests EXE" -ForegroundColor Cyan

  $tmp = Join-Path $repo "_tmp_release_smoke"
  if(Test-Path $tmp){ Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Force $tmp | Out-Null

  $src = Join-Path $tmp "src"
  $out = Join-Path $tmp "out"
  New-Item -ItemType Directory -Force $src | Out-Null
  New-Item -ItemType Directory -Force $out | Out-Null

  $file = Join-Path $src "hello_smoke.txt"
  "hello_smoke" | Set-Content -LiteralPath $file -Encoding UTF8

  $altb = Join-Path $tmp "smoke.altb"

  $env:ALTIORA_EDITION = "FREE"


  # Ensure protected-mode assets exist next to EXE (frozen base dir)
  $exeDir = Split-Path -Parent $exe
  $repoRoot = $Root
  $kSrc = Join-Path $repoRoot "keys\altiora_public_key.pem"
  $s1  = Join-Path $repoRoot "STATE.md"
  $s2  = Join-Path $repoRoot "STATE.md.sig"
  if(!(Test-Path -LiteralPath $kSrc)){ throw "Smoke: missing repo key: $kSrc" }
  if(!(Test-Path -LiteralPath $s1)){  throw "Smoke: missing repo state: $s1" }
  if(!(Test-Path -LiteralPath $s2)){  throw "Smoke: missing repo state sig: $s2" }
  $kDstDir = Join-Path $exeDir "keys"
  New-Item -ItemType Directory -Force $kDstDir | Out-Null
  Copy-Item -LiteralPath $kSrc -Destination (Join-Path $kDstDir "altiora_public_key.pem") -Force
  Copy-Item -LiteralPath $s1  -Destination (Join-Path $exeDir "STATE.md") -Force
  Copy-Item -LiteralPath $s2  -Destination (Join-Path $exeDir "STATE.md.sig") -Force

  & $exe "backup"  $src  $altb -p "x" | Out-Null
  & $exe "verify"  $altb -p "x" | Out-Null
  & $exe "restore" $altb $out  -p "x" | Out-Null

  $restored = Join-Path $out "hello_smoke.txt"
  if(!(Test-Path -LiteralPath $restored)){ throw "Smoke failed: restored file missing" }

  $content = Get-Content -LiteralPath $restored -ErrorAction Stop
  if($content -ne "hello_smoke"){ throw "Smoke failed: restored content mismatch" }

  Write-Host "OK Smoke tests OK" -ForegroundColor Green
}

function Make-ReleasePackage([string]$repo,[string]$exe,[string]$ver,[string]$proPrice,[string]$freeLimit){
  $relBase = Join-Path $repo $ReleaseBase
  $relDir  = Join-Path $relBase ("v" + $ver)
  Assert-Dir $relDir

  $exeName = "AltioraBackupPro_v$ver.exe"
  $exeOut  = Join-Path $relDir $exeName
  Copy-Item -LiteralPath $exe -Destination $exeOut -Force

  # Include protected-mode assets in release folder (required by EXE in protected mode)
  $kSrc = Join-Path $repo "keys\altiora_public_key.pem"
  $s1  = Join-Path $repo "STATE.md"
  $s2  = Join-Path $repo "STATE.md.sig"
  if(!(Test-Path -LiteralPath $kSrc)){ throw "Release: missing repo key: $kSrc" }
  if(!(Test-Path -LiteralPath $s1)){  throw "Release: missing repo state: $s1" }
  if(!(Test-Path -LiteralPath $s2)){  throw "Release: missing repo state sig: $s2" }
  $kDstDir = Join-Path $relDir "keys"
  New-Item -ItemType Directory -Force $kDstDir | Out-Null
  Copy-Item -LiteralPath $kSrc -Destination (Join-Path $kDstDir "altiora_public_key.pem") -Force
  Copy-Item -LiteralPath $s1  -Destination (Join-Path $relDir "STATE.md") -Force
  Copy-Item -LiteralPath $s2  -Destination (Join-Path $relDir "STATE.md.sig") -Force


  $exeHash = Hash-SHA256 $exeOut
  $shaPath = Join-Path $relDir ("AltioraBackupPro_v$ver.sha256")
  $exeHash | Set-Content -LiteralPath $shaPath -Encoding ASCII

  $commit = Get-RepoCommitShort $repo
  $readme = @"
ALTIORA BACKUP PRO — RELEASE $ver

Chiffrement : AES-256-GCM
PBKDF2     : 300 000 itérations
Edition    :
  - Free : restauration limitée à $freeLimit
  - Pro  : restauration illimitée ($proPrice)

Build info :
  - Commit : $commit

Fichiers :
  - $exeName
  - AltioraBackupPro_v$ver.sha256
  - STATE.md
  - STATE.md.sig
  - keys\altiora_public_key.pem

Vérification intégrité :
  certutil -hashfile $exeName SHA256

© Altiora
"@
  $readmePath = Join-Path $relDir ("README_RELEASE_v$ver.txt")
  $readme | Set-Content -LiteralPath $readmePath -Encoding UTF8

  Write-Host "OK Release folder ready: $relDir" -ForegroundColor Green
  return $relDir
}

function Zip-And-BackupRelease([string]$repo,[string]$relDir,[string]$ver,[string[]]$drives){
  $outDir = Join-Path $repo $OutReleases
  Assert-Dir $outDir

  # IMPORTANT: avoid $ver_release variable parsing
  $zipName = "AltioraBackupPro_v{0}_release.zip" -f $ver
  $zipPath = Join-Path $outDir $zipName
  if(Test-Path $zipPath){ Remove-Item -Force $zipPath -ErrorAction SilentlyContinue }

  Compress-Archive -Path (Join-Path $relDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

  $zipHash = Hash-SHA256 $zipPath
  $zipSha  = Join-Path $outDir ("AltioraBackupPro_v{0}_release.sha256" -f $ver)
  $zipHash | Set-Content -LiteralPath $zipSha -Encoding ASCII

  foreach($d in $drives){
    if(Test-Path $d){
      $dest = Join-Path $d "ABP_RELEASES"
      Assert-Dir $dest
      Copy-Item -LiteralPath $zipPath -Destination $dest -Force
      Copy-Item -LiteralPath $zipSha  -Destination $dest -Force
    }
  }

  Write-Host "OK Release ZIP: $zipPath" -ForegroundColor Green
  Write-Host "OK ZIP SHA256 : $zipSha" -ForegroundColor Green
  Write-Host "OK Copied to drives (if present): $($drives -join ', ')" -ForegroundColor Green
  return $zipPath
}

# ---------------- MAIN ----------------
if(!(Test-Path -LiteralPath $Root)){ throw "Root introuvable: $Root" }

if([string]::IsNullOrWhiteSpace($Version)){
  $Version = Detect-Version $Root
}

Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "ALTIORA RELEASE BUILDER" -ForegroundColor White
Write-Host "Root    : $Root" -ForegroundColor Gray
Write-Host "Version : $Version" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor DarkGray

$pyBuild = Ensure-BuildVenv $Root $BuildVenv

if($CleanBuild){
  Clean-BuildArtifacts $Root
}

$exe = Build-Exe $Root $pyBuild

if(-not $SkipTests){
  Smoke-Tests $Root $exe
} else {
  Write-Host "ℹ Smoke tests skipped (-SkipTests)" -ForegroundColor Yellow
}

$relDir = Make-ReleasePackage $Root $exe $Version $ProPrice $FreeRestoreLimit

$zip = Zip-And-BackupRelease $Root $relDir $Version $Drives

Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "OK DONE" -ForegroundColor Green
Write-Host "EXE : $exe" -ForegroundColor Gray
Write-Host "REL : $relDir" -ForegroundColor Gray
Write-Host "ZIP : $zip" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor DarkGray









# --- AUTO-CHAIN: secure signing + verify + backup + STATE ---
$secure = Join-Path $PSScriptRoot "release_secure_v1.ps1"
if(-not (Test-Path -LiteralPath $secure)){ throw "Missing secure pipeline: $secure" }
& $secure
if($LASTEXITCODE -ne 0){ throw "Secure release step failed (exit=$LASTEXITCODE)" }
# --- END AUTO-CHAIN ---

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

