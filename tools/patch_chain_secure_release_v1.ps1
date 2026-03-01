$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "Introuvable: $target" }

$src=Get-Content -LiteralPath $target -Encoding UTF8

# Prevent double-insert
if($src -match "release_secure_v1\.ps1"){
  Write-Host "Already chained"
  exit 0
}

$out=New-Object System.Collections.Generic.List[string]
foreach($line in $src){ $out.Add($line) }

$out.Add("")
$out.Add("# --- AUTO-CHAIN: secure signing + verify + backup + STATE ---")
$out.Add('$secure = Join-Path $PSScriptRoot "release_secure_v1.ps1"')
$out.Add('if(-not (Test-Path -LiteralPath $secure)){ throw "Missing secure pipeline: $secure" }')
$out.Add('& $secure')
$out.Add('if($LASTEXITCODE -ne 0){ throw "Secure release step failed (exit=$LASTEXITCODE)" }')
$out.Add("# --- END AUTO-CHAIN ---")

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "release_build_and_backup.ps1 now chains release_secure_v1.ps1"
