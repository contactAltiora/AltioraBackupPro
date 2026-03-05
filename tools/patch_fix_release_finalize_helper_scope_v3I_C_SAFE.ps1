$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($txt0)){ throw "FAIL-CLOSED: empty file read: $path" }

# Idempotent
if($txt0 -like "*ABP_HELPER_SCOPE_V3I_C*"){
  Write-Host "Already patched: ABP_HELPER_SCOPE_V3I_C. No change."
  exit 0
}

$anchor = "ABP_USE_NAME_BASENAME_V3H"
$idx = $txt0.IndexOf($anchor, [System.StringComparison]::Ordinal)
if($idx -lt 0){
  throw "FAIL-CLOSED: anchor not found: $anchor (expected V3H already applied)"
}

# Build helper WITHOUT nested here-strings (important)
$helperLines = @(
  "# ABP_HELPER_SCOPE_V3I_C",
  "if(-not (Get-Command -Name ABP-GetVersionCore -ErrorAction SilentlyContinue)){",
  "  function ABP-GetVersionCore {",
  "    param([Parameter(Mandatory=`$true)][string]`$V)",
  "    `$v2 = `$V.Trim()",
  "    `$m = [regex]::Match(`$v2, '^(?<core>\d+\.\d+\.\d+)')",
  "    if(`$m.Success){ return `$m.Groups['core'].Value }",
  "    return `$v2",
  "  }",
  "}",
  ""
)
$helper = ($helperLines -join "`r`n") + "`r`n"

$txt1 = $txt0.Substring(0, $idx) + $helper + $txt0.Substring($idx)
if($txt1 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt1 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_HELPER_SCOPE_V3I_C]"
