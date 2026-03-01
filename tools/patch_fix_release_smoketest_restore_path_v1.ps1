$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "introuvable: $target" }

$arr = Get-Content -LiteralPath $target -Encoding UTF8

# Replace the strict Join-Path check with a recursive search
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*\$restored\s*=\s*Join-Path\s+\$out\s+"hello_smoke\.txt"\s*$'){
    # Expect next line to be the Test-Path throw
    $arr[$i]   = '  # Restore may recreate source subfolders; locate file anywhere under $out'
    $arr[$i+1] = '  $found = Get-ChildItem -Path $out -Recurse -File -Filter "hello_smoke.txt" -ErrorAction SilentlyContinue | Select-Object -First 1'
    $arr[$i+2] = '  if(-not $found){ throw "Smoke failed: restored file missing" }'
    $arr[$i+3] = '  $restored = $found.FullName'
    break
  }
}

Set-Content -LiteralPath $target -Value $arr -Encoding UTF8
Write-Host "OK: smoke restore path check made recursive"
