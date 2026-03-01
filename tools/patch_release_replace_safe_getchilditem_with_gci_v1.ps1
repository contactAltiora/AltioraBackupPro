$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repo  = (Get-Location).Path
$tools = Join-Path $repo "tools"
if(!(Test-Path -LiteralPath $tools)){ throw "tools introuvable: $tools" }

$targets = @(
  (Join-Path $tools "release_build_and_backup.ps1"),
  (Join-Path $tools "release_finalize_and_state.ps1")
)

foreach($t in $targets){
  if(!(Test-Path -LiteralPath $t)){ throw "cible introuvable: $t" }

  $raw = Get-Content -LiteralPath $t -Raw -Encoding UTF8

  # Si le script ne contient pas Safe-GetChildItem, on ne touche pas
  if($raw -notmatch '\bSafe-GetChildItem\b'){ continue }

  $new = $raw

  # 1) Safe-GetChildItem -> Get-ChildItem
  $new = $new -replace '\bSafe-GetChildItem\b', 'Get-ChildItem'

  # 2) -OnError -> -ErrorAction (Get-ChildItem n'a pas -OnError)
  $new = $new -replace '(\s)-OnError(\s+)', '$1-ErrorAction$2'

  if($new -ne $raw){
    Set-Content -LiteralPath $t -Value $new -Encoding UTF8
  }
}

# Self-check : plus aucun Safe-GetChildItem dans ces scripts
foreach($t in $targets){
  $raw2 = Get-Content -LiteralPath $t -Raw -Encoding UTF8
  if($raw2 -match '\bSafe-GetChildItem\b'){
    throw "Patch FAILED: Safe-GetChildItem encore présent dans: $t"
  }
}

Write-Host "OK: release scripts converted to Get-ChildItem (no Safe-GetChildItem dependency)" -ForegroundColor Green
