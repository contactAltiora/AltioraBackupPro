$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)"
}

$root = (Get-Location).Path
$lockPath  = Join-Path $root "_out\baseline_lock.json"
$targetRel = "altiora.py"
$target    = Join-Path $root $targetRel

if(!(Test-Path $lockPath)){ throw "baseline_lock.json introuvable: $lockPath" }
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

if(-not (Get-Command git -ErrorAction SilentlyContinue)){ throw "git introuvable dans PATH" }

# 1) Restore altiora.py depuis Git
& git restore --source=HEAD -- $targetRel | Out-Null

# 2) Hash actuel
$sha = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash

# 3) Load lock, replace ONLY altiora.py
$raw  = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8
$lock = $raw | ConvertFrom-Json

if(-not $lock.files){ throw "baseline_lock.json: propriété 'files' introuvable" }
if(-not ($lock.files.PSObject.Properties.Name -contains $targetRel)){
  throw "baseline_lock.json: entrée manquante pour '$targetRel'"
}

$old = ($lock.files.PSObject.Properties | Where-Object { $_.Name -eq $targetRel }).Value
$lock.files.$targetRel = $sha

# 4) Write JSON as UTF-8 NO BOM + newline
$json = $lock | ConvertTo-Json -Depth 50
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($lockPath, $json + "`n", $utf8NoBom)

Write-Host "OK: baseline reconciled for altiora.py"
Write-Host "OLD=$old"
Write-Host "NEW=$sha"
