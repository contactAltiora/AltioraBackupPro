$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"
$src=Get-Content -LiteralPath $target -Encoding UTF8

# 1) remove all existing calls
$clean = New-Object System.Collections.Generic.List[string]
foreach($line in $src){
  if($line -match '^\s*verify_official_release\(\)\s*$'){ continue }
  $clean.Add($line)
}

# 2) find last top-level import line
$idx = -1
for($i=0;$i -lt $clean.Count;$i++){
  if($clean[$i] -match '^import\s+' -or $clean[$i] -match '^from\s+\S+\s+import\s+'){
    $idx = $i
  }
}
if($idx -lt 0){ throw "No import section found to inject after" }

# 3) build new file with a single guaranteed call
$out = New-Object System.Collections.Generic.List[string]
for($i=0;$i -le $idx;$i++){ $out.Add($clean[$i]) }

$out.Add("")
$out.Add("# Enforce official release signature (fail-closed when public key exists)")
$out.Add("verify_official_release()")
$out.Add("")

for($i=$idx+1;$i -lt $clean.Count;$i++){ $out.Add($clean[$i]) }

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "verify_official_release() moved right after imports (single call)"
