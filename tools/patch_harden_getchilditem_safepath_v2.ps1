$ErrorActionPreference="Stop"
. "$PSScriptRoot\safe_fs.ps1"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root  = (Get-Location).Path
$tools = Join-Path $root "tools"
if(!(Test-Path -LiteralPath $tools)){ throw "tools/ introuvable: $tools" }

# Ensure helper exists
$safeFs = Join-Path $tools "safe_fs.ps1"
if(!(Test-Path -LiteralPath $safeFs)){ throw "safe_fs.ps1 introuvable: $safeFs (exécute patch v1 d'abord)" }

function Ensure-DotSourceSafeFs([string[]]$lines){
  $needle = '. "$PSScriptRoot\safe_fs.ps1"'
  foreach($l in $lines){ if($l.Trim() -eq $needle){ return ,$lines } }

  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false

  for($i=0; $i -lt $lines.Count; $i++){
    [void]$out.Add($lines[$i])

    if(-not $inserted -and $lines[$i] -match '^\s*\$ErrorActionPreference\s*=\s*"?Stop"?\s*$'){
      [void]$out.Add($needle)
      [void]$out.Add('')
      $inserted = $true
    }
  }

  if(-not $inserted){
    # prepend fallback
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($needle)
    [void]$out2.Add('')
    foreach($l in $out){ [void]$out2.Add($l) }
    return ,$out2.ToArray()
  }

  return ,$out.ToArray()
}

function Rewrite-GetChildItem([string]$line){
  $l = $line

  # Only rewrite if line starts with Get-ChildItem (after spaces)
  if($l -notmatch '^\s*Get-ChildItem\b'){ return $l }

  # Already safe?
  if($l -match '^\s*Safe-GetChildItem\b'){ return $l }

  # Case 1: Get-ChildItem -LiteralPath ...
  if($l -match '^\s*Get-ChildItem\s+-LiteralPath\b'){
    return ($l -replace '^\s*Get-ChildItem\b', 'Safe-GetChildItem')
  }

  # Case 2: Get-ChildItem -Path ...
  if($l -match '^\s*Get-ChildItem\s+-Path\b'){
    return ($l -replace '^\s*Get-ChildItem\b', 'Safe-GetChildItem')
  }

  # Case 3: Get-ChildItem "C:\..." or ".\..." (quoted)
  if($l -match '^\s*Get-ChildItem\s+"[^"]+"'){
    return ($l -replace '^\s*Get-ChildItem\s+("([^"]+)")\s*', 'Safe-GetChildItem -LiteralPath $1 ')
  }

  # Case 4: Get-ChildItem $var ...
  if($l -match '^\s*Get-ChildItem\s+\$[A-Za-z_][A-Za-z0-9_]*\b'){
    return ($l -replace '^\s*Get-ChildItem\s+(\$[A-Za-z_][A-Za-z0-9_]*)\b', 'Safe-GetChildItem -LiteralPath $1')
  }

  # Case 5: Get-ChildItem .\tools -File -Filter ...
  if($l -match '^\s*Get-ChildItem\s+\.\S+'){
    return ($l -replace '^\s*Get-ChildItem\s+(\.\S+)\b', 'Safe-GetChildItem -LiteralPath $1')
  }

  # Otherwise leave untouched
  return $l
}

function Harden-File([string]$path){
  $before = Get-Content -LiteralPath $path -Encoding UTF8
  $arr = $before

  $arr = Ensure-DotSourceSafeFs -lines $arr

  $out = New-Object System.Collections.Generic.List[string]
  foreach($line in $arr){
    [void]$out.Add((Rewrite-GetChildItem -line $line))
  }

  Set-Content -LiteralPath $path -Value $out -Encoding UTF8

  # Self-check: dot-source present
  $after = Get-Content -LiteralPath $path -Encoding UTF8
  $hasDot = $false
  foreach($l in $after){
    if($l.Trim() -eq '. "$PSScriptRoot\safe_fs.ps1"'){ $hasDot = $true; break }
  }
  if(-not $hasDot){ throw "Patch failed: dot-source missing in $path" }

  Write-Host "OK hardened: $path" -ForegroundColor Green
}

# Targets: only the scripts you listed (plus release_finalize/snapshot if present)
$targets = New-Object System.Collections.Generic.List[string]

$targets.Add((Join-Path $tools "release_build_and_backup.ps1"))

$maybe = @(
  "release_finalize_and_state.ps1",
  "diag_bundle_zip.ps1",
  "harden_repo_v1.ps1",
  "bundle_BACKUP_PRO_ALTIORA.ps1",
  "bundle_client_v1_0_16.ps1",
  "bundle_client_v1_0_17.ps1",
  "patch_add_diag_bundle_zip_v1.ps1",
  "patch_bundle_zip_diagnostic_zipfile_v4.ps1",
  "patch_clean_bundle_v1.ps1",
  "patch_harden_getchilditem_safepath_v1.ps1"
)

foreach($name in $maybe){
  $p = Join-Path $tools $name
  if(Test-Path -LiteralPath $p){ $targets.Add($p) }
}

Safe-GetChildItem -LiteralPath $tools -File -Filter "snapshot*.ps1" -OnError SilentlyContinue | ForEach-Object {
  $targets.Add($_.FullName)
}

# Dedupe
$uniq = @{}
$finalTargets = @()
foreach($t in $targets){
  if($t -and (Test-Path -LiteralPath $t) -and (-not $uniq.ContainsKey($t))){
    $uniq[$t] = $true
    $finalTargets += $t
  }
}

if($finalTargets.Count -eq 0){ throw "Aucun script cible trouvé" }

foreach($t in $finalTargets){ Harden-File -path $t }

Write-Host "OK: v2 hardening complete (safe_fs dot-source + Get-ChildItem -> Safe-GetChildItem)" -ForegroundColor Green
