$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# Anchors (fail-closed)
if($txt0 -notlike "*# extract version*"){ throw "FAIL-CLOSED: anchor not found: '# extract version'" }
if($txt0 -notlike "*throw ""Cannot parse version""*"){ throw "FAIL-CLOSED: anchor not found: 'Cannot parse version'" }
if($txt0 -notlike "*if(`$lastZip.BaseName -match*AltioraBackupPro_*_release*"){ throw "FAIL-CLOSED: expected version extraction if-block not found (lastZip.BaseName -match)" }

# Idempotent
if($txt0 -like "*ABP_PARSE_VERSION_SUFFIX_V3E*"){
  Write-Host "Already patched: ABP_PARSE_VERSION_SUFFIX_V3E. No change."
  exit 0
}

# Ensure helper exists (your file already has it, but fail-closed if missing)
if($txt0 -notmatch '(?is)\bfunction\s+ABP-GetVersionCore\b'){
  throw "FAIL-CLOSED: helper ABP-GetVersionCore not found. Expected it to exist already."
}

$txt = $txt0

# Replace the exact regex: (v\d+\.\d+\.\d+)  -> (v\d+\.\d+\.\d+)[A-Za-z0-9.+_-]*
$old = '^AltioraBackupPro_(v\d+\.\d+\.\d+)_release$'
$new = '^AltioraBackupPro_(v\d+\.\d+\.\d+)(?:[A-Za-z0-9\.\+\-\_]+)?_release$'

if($txt -notlike "*$old*"){ throw "FAIL-CLOSED: expected old version regex not found: $old" }

$txt = $txt.Replace($old, $new)

# After extracting $version = $Matches[1], normalize to core and keep leading v
# Insert right after the assignment line.
$assignLine = '    $version = $Matches[1]'
if($txt -notlike "*$assignLine*"){ throw "FAIL-CLOSED: expected assignment line not found: $assignLine" }

$needle = $assignLine + "`r`n"
$insert = $needle + '    # ABP_PARSE_VERSION_SUFFIX_V3E normalize suffix -> core (keep leading v)' + "`r`n" +
                  '    $version = "v" + (ABP-GetVersionCore ($version.TrimStart("v")))' + "`r`n"

# Insert once (idempotence guaranteed by marker check above)
$idx = $txt.IndexOf($needle, [System.StringComparison]::Ordinal)
if($idx -lt 0){ throw "FAIL-CLOSED: could not locate insertion point after version assignment." }

$txt = $txt.Substring(0, $idx) + $insert + $txt.Substring($idx + $needle.Length)

if($txt -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_PARSE_VERSION_SUFFIX_V3E]"
