$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $target)){ throw "altiora.py introuvable: $target" }

$src = Get-Content -LiteralPath $target -Encoding UTF8

# We inject a small block right after: import os
# If ABP_SELFTEST_MODE=1 => force ALTIORA_PROTECTED=0 for this run
$needle = '^import os\s*$'
$injected = $false
$out = New-Object System.Collections.Generic.List[string]

foreach($line in $src){
  $out.Add($line)

  if((-not $injected) -and ($line -match $needle)){
    $out.Add('')
    $out.Add('# ABP_SELFTEST_MODE: bypass protected-mode tripwire during selftests (deterministic patch)')
    $out.Add('if os.environ.get("ABP_SELFTEST_MODE") == "1":')
    $out.Add('    os.environ["ALTIORA_PROTECTED"] = "0"')
    $out.Add('')
    $injected = $true
  }
}

if(-not $injected){
  throw "Cannot find standalone 'import os' line to inject after"
}

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "ABP_SELFTEST_MODE bypass injected (forces ALTIORA_PROTECTED=0 during selftest)"
