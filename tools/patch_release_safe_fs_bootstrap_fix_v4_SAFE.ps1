$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo" }

function _abp_parse_check {
  param([string]$Text,[string]$Label)
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseInput($Text,[ref]$null,[ref]$errors) | Out-Null
  if($errors -and $errors.Count -gt 0){
    $errors | ForEach-Object { Write-Host ("PARSE_ERROR("+$Label+"): " + $_.Message) }
    throw "FAIL-CLOSED: parse errors in $Label"
  }
}

# --- 1) release_build_and_backup.ps1 : enlever le dot-source en double (forme ". "$PSScriptRoot\safe_fs.ps1"")
$f1 = Join-Path $repoRoot "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $f1)){ throw "Missing: $f1" }
$t1 = Get-Content -LiteralPath $f1 -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($t1)){ throw "FAIL-CLOSED: empty file read: tools\release_build_and_backup.ps1" }

if($t1 -notlike "*SAFE_FS_BOOTSTRAP_FIX_V4*"){
  # retire uniquement la variante avec chemin en string (doublon)
  $t1b = [regex]::Replace($t1, '(?m)^\s*\.\s*"\$PSScriptRoot\\safe_fs\.ps1"\s*\r?\n', '')
  if($t1b -ne $t1){
    $t1 = "# SAFE_FS_BOOTSTRAP_FIX_V4`r`n" + $t1b
  } else {
    # pas de changement -> on marque quand même (idempotent) sans toucher au code
    $t1 = "# SAFE_FS_BOOTSTRAP_FIX_V4`r`n" + $t1
  }
  _abp_parse_check -Text $t1 -Label "release_build_and_backup.ps1"
  Set-Content -LiteralPath $f1 -Value $t1 -Encoding UTF8
  Write-Host 'Patched: tools\release_build_and_backup.ps1 (removed duplicate dot-source string path)'
} else {
  Write-Host "Already patched marker: tools\release_build_and_backup.ps1"
}

# --- 2) release_finalize_and_state.ps1 : remplacer le bloc SafeFS cassé en tête par un bootstrap propre
$f2 = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $f2)){ throw "Missing: $f2" }
$t2 = Get-Content -LiteralPath $f2 -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($t2)){ throw "FAIL-CLOSED: empty file read: tools\release_finalize_and_state.ps1" }

if($t2 -like "*SAFE_FS_BOOTSTRAP_V4*"){
  Write-Host "Already patched marker: tools\release_finalize_and_state.ps1"
  exit 0
}

# bloc propre à injecter
$boot = @(
  "# SAFE_FS_BOOTSTRAP_V4",
  "Set-StrictMode -Version Latest",
  '$ErrorActionPreference = "Stop"',
  '$safeFs = Join-Path $PSScriptRoot "safe_fs.ps1"',
  'if(Test-Path -LiteralPath $safeFs){ . $safeFs }',
  'if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){',
  '  throw "FAIL-CLOSED: Safe-GetChildItem introuvable (safe_fs.ps1 non chargé)."',
  '}',
  ""
) -join "`r`n"

# On supprime l'ancien bloc ABP_SAFEFS_FALLBACK_V3 (cassé) + ses dot-source redondants, puis on met $boot au début.
$patBroken = '(?is)^\s*(?:\r?\n)*#\s*=+\s*\r?\n#\s*ABP_SAFEFS_FALLBACK_V3.*?(?=^\s*#\s*detect repo root|\A$)'
if([regex]::IsMatch($t2, $patBroken)){
  $t2a = [regex]::Replace($t2, $patBroken, $boot, 1)
} else {
  # fallback: si le pattern ne matche pas, on met juste le bootstrap au tout début
  $t2a = $boot + $t2
}

# Nettoyage : retirer la variante ". "$PSScriptRoot\safe_fs.ps1"" si elle traîne encore
$t2a = [regex]::Replace($t2a, '(?m)^\s*\.\s*"\$PSScriptRoot\\safe_fs\.ps1"\s*\r?\n', '')

_abp_parse_check -Text $t2a -Label "release_finalize_and_state.ps1"
Set-Content -LiteralPath $f2 -Value $t2a -Encoding UTF8
Write-Host "Patched: tools\release_finalize_and_state.ps1 (SAFE_FS_BOOTSTRAP_V4 + removed broken fallback block)"
