$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"
$src=Get-Content -LiteralPath $target -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]
$inFunc=$false
$inserted=$false

foreach($line in $src){
  $out.Add($line)

  if($line -match '^def verify_official_release\(\)\s*:'){
    $inFunc=$true
    continue
  }

  if($inFunc -and -not $inserted){
    # after the first import line inside function, inject tripwire
    if($line -match '^\s+import '){
      $out.Add("    sys.exit(99)  # TRIPWIRE: verify_official_release executed")
      $inserted=$true
      $inFunc=$false
    }
  }
}

if(-not $inserted){ throw "Tripwire insertion failed" }

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "TRIPWIRE injected (exit 99)"
