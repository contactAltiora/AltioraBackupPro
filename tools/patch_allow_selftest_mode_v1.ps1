$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $target)){ throw "altiora.py introuvable: $target" }

$src = Get-Content -LiteralPath $target -Encoding UTF8

# We want: if ABP_SELFTEST_MODE=1 => skip verify_official_release() enforcement
# Strategy: replace the call line with a guarded call.
# We only touch the FIRST occurrence of the standalone call verify_official_release()
$replaced = $false
$out = New-Object System.Collections.Generic.List[string]

foreach($line in $src){
  if((-not $replaced) -and ($line -match '^\s*verify_official_release\(\)\s*$')){
    $out.Add('if os.environ.get("ABP_SELFTEST_MODE") == "1":')
    $out.Add('    pass  # allow selftest to run without release signature')
    $out.Add('else:')
    $out.Add('    verify_official_release()')
    $replaced = $true
    continue
  }
  $out.Add($line)
}

if(-not $replaced){
  throw "Could not find standalone call line: verify_official_release()"
}

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "SELFTEST MODE guard installed (deterministic)"
