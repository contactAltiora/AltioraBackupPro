$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($txt0)){ throw "FAIL-CLOSED: empty file read: $path" }

# Idempotent
if($txt0 -like "*ABP_FIX_COMMENT_SPLIT_V3J*"){
  Write-Host "Already patched: ABP_FIX_COMMENT_SPLIT_V3J. No change."
  exit 0
}

# Must have our helper marker (we only fix this specific known breakage)
if($txt0 -notlike "*ABP_HELPER_SCOPE_V3I_C*"){
  throw "FAIL-CLOSED: expected ABP_HELPER_SCOPE_V3I_C marker not found (not the expected state)."
}

# We expect a broken line that starts with ABP_USE_NAME_BASENAME_V3H without a leading '#'
$broken = [regex]::Match($txt0, '(?m)^\s*ABP_USE_NAME_BASENAME_V3H.*$')
if(-not $broken.Success){
  throw "FAIL-CLOSED: no broken 'ABP_USE_NAME_BASENAME_V3H' line found. Nothing to fix."
}

$txt1 = [regex]::Replace(
  $txt0,
  '(?m)^(\s*)ABP_USE_NAME_BASENAME_V3H',
  '$1# ABP_USE_NAME_BASENAME_V3H'
)

if($txt1 -eq $txt0){ throw "FAIL-CLOSED: replacement produced no changes (unexpected)." }

# Add marker near the helper marker (safe, simple)
$txt2 = [regex]::Replace(
  $txt1,
  '(?m)^(.*ABP_HELPER_SCOPE_V3I_C.*)$',
  '$1' + "`r`n" + '# ABP_FIX_COMMENT_SPLIT_V3J',
  1
)

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_FIX_COMMENT_SPLIT_V3J]"
