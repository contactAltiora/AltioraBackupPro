$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"
$src=Get-Content -LiteralPath $target -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]
foreach($line in $src){
  if($line -match 'sys\.exit\(99\)\s+#\s+TRIPWIRE:\s+verify_official_release executed'){
    continue
  }
  $out.Add($line)
}

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "TRIPWIRE removed"
