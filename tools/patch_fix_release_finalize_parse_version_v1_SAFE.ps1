$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$path = Join-Path $root "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# FAIL-CLOSED markers (doivent exister)
$need = @("Cannot parse version")
foreach($m in $need){
  if($txt -notlike "*$m*"){ throw "FAIL-CLOSED: expected marker not found: $m" }
}

if($txt -notlike "*ABP_PARSE_VERSION_SUFFIX_V1*"){
  $txt2 = $txt
  # élargit les captures X.Y.Z vers X.Y.Z + suffix optionnel (p1/rc1/etc.)
  $txt2 = $txt2 -replace '\(\\d\+\\\.\\d\+\\\.\\d\+\)', '(\d+\.\d+\.\d+(?:[a-zA-Z]+\d+)?)  # ABP_PARSE_VERSION_SUFFIX_V1'
  $txt2 = $txt2 -replace '\^\s*\\d\+\\\.\\d\+\\\.\\d\+\s*\$', '^\d+\.\d+\.\d+(?:[a-zA-Z]+\d+)?$  # ABP_PARSE_VERSION_SUFFIX_V1'

  if($txt2 -eq $txt){ throw "FAIL-CLOSED: no version regex pattern patched (unexpected file layout)" }
  $txt = $txt2
}

Set-Content -LiteralPath $path -Value $txt -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 (version suffix accepted)"
