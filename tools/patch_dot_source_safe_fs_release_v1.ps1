$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$tools = Join-Path (Get-Location).Path "tools"
if(!(Test-Path -LiteralPath $tools)){ throw "tools introuvable: $tools" }

$targets = @(
  (Join-Path $tools "release_build_and_backup.ps1"),
  (Join-Path $tools "release_finalize_and_state.ps1")
)

foreach($t in $targets){
  if(!(Test-Path -LiteralPath $t)){ throw "cible introuvable: $t" }

  $raw = Get-Content -LiteralPath $t -Raw -Encoding UTF8

  # Si Safe-GetChildItem n'est pas utilisé, on ne touche pas
  if($raw -notmatch '\bSafe-GetChildItem\b'){ continue }

  # Si déjà dot-sourcé, on ne touche pas
  if($raw -match '(?m)^\s*\.\s*\(Join-Path\s+\$PSScriptRoot\s+"safe_fs\.ps1"\)\s*$'){
    continue
  }

  $lines = Get-Content -LiteralPath $t -Encoding UTF8

  # Insertion après la 1re ligne $ErrorActionPreference (ou tout en haut sinon)
  $insert = '. (Join-Path $PSScriptRoot "safe_fs.ps1")'
  $done = $false
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i] -match '^\s*\$ErrorActionPreference\s*=\s*".*"\s*$'){
      $before = @()
      if($i -ge 0){ $before = $lines[0..$i] }
      $after = @()
      if($i+1 -le $lines.Count-1){ $after = $lines[($i+1)..($lines.Count-1)] }
      $lines = @($before + @($insert) + $after)
      $done = $true
      break
    }
  }
  if(-not $done){
    $lines = @($insert) + $lines
  }

  Set-Content -LiteralPath $t -Value $lines -Encoding UTF8
}

# Self-check : vérifier que la ligne est présente
foreach($t in $targets){
  if(!(Test-Path -LiteralPath $t)){ continue }
  $raw2 = Get-Content -LiteralPath $t -Raw -Encoding UTF8
  if($raw2 -match '\bSafe-GetChildItem\b'){
    if($raw2 -notmatch '(?m)^\s*\.\s*\(Join-Path\s+\$PSScriptRoot\s+"safe_fs\.ps1"\)\s*$'){
      throw "Patch FAILED: safe_fs.ps1 non dot-source dans: $t"
    }
  }
}

Write-Host "OK: safe_fs.ps1 dot-source dans scripts release" -ForegroundColor Green
