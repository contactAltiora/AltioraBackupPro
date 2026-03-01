$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

# Repo root robuste: patch est dans /tools => root = parent
$toolsDir = $PSScriptRoot
$root = Split-Path -Parent $toolsDir

$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "introuvable: $target (root=$root toolsDir=$toolsDir)" }

Write-Host "PATCH v4 target = $target" -ForegroundColor Cyan

$arr = Get-Content -LiteralPath $target -Encoding UTF8

# 1) Trouver le début de la fonction Smoke-Tests pour limiter la zone de recherche
$smokeStart = -1
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*function\s+Smoke-Tests'){
    $smokeStart = $i
    break
  }
}
if($smokeStart -lt 0){ throw "Patch v4: function Smoke-Tests introuvable" }

# 2) Dans les ~120 lignes suivantes, chercher la ligne $restored = Join-Path $out "hello_smoke.txt"
$idx = -1
$limit = [Math]::Min($arr.Count-1, $smokeStart + 160)
for($i=$smokeStart; $i -le $limit; $i++){
  if($arr[$i] -match '^\s*\$restored\s*=\s*Join-Path\s+\$out\s+"hello_smoke\.txt"\s*$'){
    $idx = $i
    break
  }
}
if($idx -lt 0){
  throw "Patch v4: ligne `$restored = Join-Path `$out `"hello_smoke.txt`" introuvable entre $smokeStart et $limit"
}

Write-Host ("FOUND line {0}: {1}" -f $idx, $arr[$idx]) -ForegroundColor Yellow

# 3) Déterminer si la ligne suivante est le Test-Path attendu
$removeCount = 1
if(($idx + 1) -lt $arr.Count -and $arr[$idx + 1] -match 'Test-Path\s+-LiteralPath\s+\$restored'){
  $removeCount = 2
  Write-Host ("FOUND next line {0}: {1}" -f ($idx+1), $arr[$idx+1]) -ForegroundColor Yellow
}else{
  Write-Host "WARN: next line is not Test-Path check; will replace only the restored assignment line" -ForegroundColor DarkYellow
}

$replacement = @(
'  # Restore may recreate source subfolders; locate file anywhere under $out',
'  $found = Get-ChildItem -Path $out -Recurse -File -Filter "hello_smoke.txt" -ErrorAction SilentlyContinue | Select-Object -First 1',
'  if(-not $found){ throw "Smoke failed: restored file missing" }',
'  $restored = $found.FullName'
)

# 4) Construire le nouveau contenu
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

# 5) Auto-vérification stricte
$after = Get-Content -LiteralPath $target -Encoding UTF8
$ok = $false
for($i=0; $i -lt $after.Count; $i++){
  if($after[$i] -match 'Get-ChildItem\s+-Path\s+\$out\s+-Recurse' -and $after[$i] -match 'hello_smoke\.txt'){
    $ok = $true
    break
  }
}
if(-not $ok){
  throw "Patch v4 FAILED: replacement not found after write (file not modified as expected)"
}

Write-Host "OK: Smoke test restore path check updated (recursive search) [v4]" -ForegroundColor Green
