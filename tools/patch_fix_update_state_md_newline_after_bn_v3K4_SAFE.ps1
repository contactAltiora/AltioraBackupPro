$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\update_state_md.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($txt0)){ throw "FAIL-CLOSED: empty file read: $path" }

# Idempotent
if($txt0 -like "*ABP_UPDATE_STATE_FIX_BN_NEWLINE_V3K4*"){
  Write-Host "Already patched: ABP_UPDATE_STATE_FIX_BN_NEWLINE_V3K4. No change."
  exit 0
}

# Anchor: detect the broken token sequence
$patBroken = '(?s)\[IO\.Path\]::GetFileNameWithoutExtension\(\$lastZip\.Name\)\s*if\s*\('
if(-not [regex]::IsMatch($txt0, $patBroken)){
  throw "FAIL-CLOSED: broken '...Name)if(' sequence not found. Nothing to fix (or different layout)."
}

$txt1 = [regex]::Replace(
  $txt0,
  $patBroken,
  '[IO.Path]::GetFileNameWithoutExtension($lastZip.Name)' + "`r`n" + '# ABP_UPDATE_STATE_FIX_BN_NEWLINE_V3K4' + "`r`n" + 'if(',
  1
)

if($txt1 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt1 -Encoding UTF8
Write-Host "OK: patched -> tools\update_state_md.ps1 [ABP_UPDATE_STATE_FIX_BN_NEWLINE_V3K4]"
