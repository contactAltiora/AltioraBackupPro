$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# Idempotent
if($txt0 -like "*ABP_USE_NAME_BASENAME_V3H*"){
  Write-Host "Already patched: ABP_USE_NAME_BASENAME_V3H. No change."
  exit 0
}

# Anchors
if($txt0 -notlike "*# extract version*"){ throw "FAIL-CLOSED: anchor not found: '# extract version'" }
if($txt0 -notlike "*throw ""Cannot parse version""*"){ throw "FAIL-CLOSED: anchor not found: 'Cannot parse version'" }
if($txt0 -notmatch '(?is)\$lastZip\.BaseName\s*-match'){ throw "FAIL-CLOSED: expected `$lastZip.BaseName -match not found" }

# Ensure helper exists
if($txt0 -notmatch '(?is)\bfunction\s+ABP-GetVersionCore\b'){
  throw "FAIL-CLOSED: helper ABP-GetVersionCore not found."
}

$txt = $txt0

# Capture the regex string literal used for -match, allowing it to be on the next line.
# We capture:
#   if($lastZip.BaseName -match
#   "REGEX"){
$patRx = '(?is)if\s*\(\s*\$lastZip\.BaseName\s*-match\s*(?:\r?\n\s*)?(?<q>[''"])(?<rx>[^''"]+)\k<q>\s*\)\s*\{'
$m = [regex]::Match($txt, $patRx)
if(-not $m.Success){
  throw "FAIL-CLOSED: could not capture the regex string used in the BaseName -match block (possibly different layout)."
}

$rx = $m.Groups["rx"].Value
$rx2 = $rx.Replace('\_', '_')  # fix invalid escape if present

# Now replace the whole extract-version block (from '# extract version' to closing else throw) with our bn-based logic.
$patBlock = '(?is)#\s*extract\s+version\s*\r?\n\s*if\s*\(\s*\$lastZip\.BaseName\s*-match\s*(?:\r?\n\s*)?[''"][^''"]+[''"]\s*\)\s*\{\s*\$version\s*=\s*\$Matches\[\s*1\s*\]\s*(?:\r?\n\s*#\s*ABP_PARSE_VERSION_SUFFIX_V3F[^\r\n]*)?\s*(?:\r?\n\s*\$version\s*=\s*"v"\s*\+\s*\(ABP-GetVersionCore[^\r\n]*\))?\s*\}\s*else\s*\{\s*throw\s*([''"])Cannot parse version\1\s*\}\s*'
$mb = [regex]::Match($txt, $patBlock)
if(-not $mb.Success){
  throw "FAIL-CLOSED: could not locate the full extract-version block to replace (layout differs)."
}

$replacement = @"
# extract version
# ABP_USE_NAME_BASENAME_V3H (use Name -> basename; avoid flaky .BaseName)
`$bn = [IO.Path]::GetFileNameWithoutExtension(`$lastZip.Name)
if(`$bn -match `"$rx2`"){
    `$version = `$Matches[1]
    `$version = "v" + (ABP-GetVersionCore (`$version.TrimStart("v")))
}else{
    throw "Cannot parse version"
}

"@

$txt2 = [regex]::Replace($txt, $patBlock, $replacement, 1)

if($txt2 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_USE_NAME_BASENAME_V3H]"
