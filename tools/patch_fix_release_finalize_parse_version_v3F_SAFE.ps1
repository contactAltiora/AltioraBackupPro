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

# Idempotent
if($txt0 -like "*ABP_PARSE_VERSION_SUFFIX_V3F*"){
  Write-Host "Already patched: ABP_PARSE_VERSION_SUFFIX_V3F. No change."
  exit 0
}

# Ensure helper exists (expected already)
if($txt0 -notmatch '(?is)\bfunction\s+ABP-GetVersionCore\b'){
  throw "FAIL-CLOSED: helper ABP-GetVersionCore not found."
}

$txt = $txt0

# 1) Broaden regex to accept suffixes:
#    ^AltioraBackupPro_(vX.Y.Z)_release$  -> ^AltioraBackupPro_(vX.Y.Z)(suffix)?_release$
$old = '^AltioraBackupPro_(v\d+\.\d+\.\d+)_release$'
$new = '^AltioraBackupPro_(v\d+\.\d+\.\d+)(?:[A-Za-z0-9\.\+\-\_]+)?_release$'
if($txt -notlike "*$old*"){ throw "FAIL-CLOSED: expected old version regex not found: $old" }
$txt = $txt.Replace($old, $new)

# 2) Insert normalize line right after: $version = $Matches[1]
#    Match any whitespace (tabs/spaces) and preserve indentation.
$patAssign = '(?m)^(?<indent>[ \t]*)\$version[ \t]*=[ \t]*\$Matches\[[ \t]*1[ \t]*\][ \t]*\r?$'
$m = [regex]::Match($txt, $patAssign)
if(-not $m.Success){
  throw "FAIL-CLOSED: assignment '$version = $Matches[1]' not found (whitespace-insensitive)."
}
$indent = $m.Groups["indent"].Value

$insert = $m.Value + "`r`n" +
          "${indent}# ABP_PARSE_VERSION_SUFFIX_V3F normalize suffix -> core (keep leading v)`r`n" +
          "${indent}`$version = ""v"" + (ABP-GetVersionCore (`$version.TrimStart(""v"")))" + "`r`n"

# Replace only first occurrence
$txt2 = [regex]::Replace($txt, $patAssign, [System.Text.RegularExpressions.MatchEvaluator]{
  param($mm)
  return $insert
}, 1)

if($txt2 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_PARSE_VERSION_SUFFIX_V3F]"
