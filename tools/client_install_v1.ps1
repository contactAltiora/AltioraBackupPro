param(
  [string]$SourceDir = "",
  [string]$InstallDir = "C:\ProgramData\AltioraBackupPro",
  [switch]$EnableProtectedMode
)

$ErrorActionPreference="Stop"

function Ensure-Dir([string]$p){
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

Write-Host "== AltioraBackupPro Client Install =="

# Resolve SourceDir safely
if([string]::IsNullOrWhiteSpace($SourceDir)){
  $SourceDir = $PWD.Path
}

if(!(Test-Path -Path $SourceDir)){
  throw "SourceDir not found: $SourceDir"
}

# Required files inside SourceDir (bundle root)
$exe      = Join-Path $SourceDir "AltioraBackupPro.exe"
$state    = Join-Path $SourceDir "STATE.md"
$stateSig = Join-Path $SourceDir "STATE.md.sig"
$stateH   = Join-Path $SourceDir "STATE.md.sha256"
$pubPem   = Join-Path $SourceDir "keys\altiora_public_key.pem"

foreach($p in @($exe,$state,$stateSig,$pubPem)){
  if(!(Test-Path -Path $p)){ throw "Missing required file in bundle: $p" }
}

Ensure-Dir $InstallDir
Ensure-Dir (Join-Path $InstallDir "keys")
Ensure-Dir (Join-Path $InstallDir "_out\releases")

Write-Host "Installing to: $InstallDir"

Copy-Item -Path $exe      -Destination (Join-Path $InstallDir "AltioraBackupPro.exe") -Force
Copy-Item -Path $state    -Destination (Join-Path $InstallDir "STATE.md") -Force
Copy-Item -Path $stateSig -Destination (Join-Path $InstallDir "STATE.md.sig") -Force
if(Test-Path -Path $stateH){
  Copy-Item -Path $stateH -Destination (Join-Path $InstallDir "STATE.md.sha256") -Force
}
Copy-Item -Path $pubPem   -Destination (Join-Path $InstallDir "keys\altiora_public_key.pem") -Force

# Optional audit/support artifacts
$relDir = Join-Path $SourceDir "_out\releases"
if(Test-Path -Path $relDir){
  Write-Host "Copying release artifacts for audit/support..."
  Copy-Item -Path (Join-Path $relDir "*") -Destination (Join-Path $InstallDir "_out\releases") -Force -ErrorAction SilentlyContinue
}

if($EnableProtectedMode){
  Write-Host "Enabling protected mode: setx ALTIORA_PROTECTED 1"
  setx ALTIORA_PROTECTED 1 | Out-Null
  Write-Host "NOTE: reopen terminal/session to apply environment variable."
}

Write-Host "OK Install complete."
Write-Host ("Run: `"{0}`" --version" -f (Join-Path $InstallDir "AltioraBackupPro.exe"))
