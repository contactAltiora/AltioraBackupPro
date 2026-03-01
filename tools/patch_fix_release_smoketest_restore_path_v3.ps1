$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "introuvable: $target" }

$arr = Get-Content -LiteralPath $target -Encoding UTF8

$idx = -1
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*\$restored\s*=\s*Join-Path\s+\$out\s+"hello_smoke\.txt"\s*$'){
    $idx = $i
    break
  }
}
if($idx -lt 0){ throw "Patch v3: ligne `$restored = Join-Path `$out `"hello_smoke.txt`" introuvable" }

# On remplace le bloc:
#   $restored = Join-Path $out "hello_smoke.txt"
#   if(!(Test-Path -LiteralPath $restored)){ throw "Smoke failed: restored file missing" }
# par une recherche récursive sous $out
$replacement = @(
'  # Restore may recreate source subfolders; locate file anywhere under $out',
'  $found = Get-ChildItem -Path $out -Recurse -File -Filter "hello_smoke.txt" -ErrorAction SilentlyContinue | Select-Object -First 1',
'  if(-not $found){ throw "Smoke failed: restored file missing" }',
'  $restored = $found.FullName'
)

# On supprime la ligne $restored + la ligne "if(!(Test-Path...))" si elle est juste après
$removeCount = 1
if(($idx + 1) -lt $arr.Count -and $arr[$idx + 1] -match 'Test-Path\s+-LiteralPath\s+\$restored'){
  $removeCount = 2
}

$newArr = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $arr.Count; $i++){
  if($i -eq $idx){
    foreach($l in $replacement){ [void]$newArr.Add($l) }
    $i += ($removeCount - 1)
    continue
  }
  [void]$newArr.Add($arr[$i])
}

Set-Content -LiteralPath $target -Value $newArr -Encoding UTF8
Write-Host "OK: Smoke test restore path check updated (recursive search) [v3]"
