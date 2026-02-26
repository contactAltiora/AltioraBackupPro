$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH requis" }

$root=(Get-Location).Path
$file=Join-Path $root "altiora.py"

$src=Get-Content -LiteralPath $file -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]

foreach($line in $src){
  $out.Add($line)

  if($line -match '^def _altiora_verify\(\):'){
    $out.Add(" print('TRIPWIRE: _altiora_verify called')")
    $out.Add(" import sys")
    $out.Add(" sys.exit(99)")
  }
}

$out | Set-Content -LiteralPath $file -Encoding UTF8
Write-Host "TRIPWIRE inserted into _altiora_verify (exit 99)"
