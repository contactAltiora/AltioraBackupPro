$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# Idempotent
if($txt0 -like "*ABP_USE_NAME_BASENAME_V3G*"){
  Write-Host "Already patched: ABP_USE_NAME_BASENAME_V3G. No change."
  exit 0
}

# Anchors
if($txt0 -notlike "*# extract version*"){ throw "FAIL-CLOSED: anchor not found: '# extract version'" }
if($txt0 -notlike "*Cannot parse version*"){ throw "FAIL-CLOSED: anchor not found: 'Cannot parse version'" }

# We expect the current if uses $lastZip.BaseName -match "...AltioraBackupPro_..."
$patIf = '(?is)#\s*extract\s+version\s*\r?\n\s*if\s*\(\s*\$lastZip\.BaseName\s*-match\s*([''"])(?<rx>[^''"]*AltioraBackupPro_[^''"]*)\1\s*\)\s*\{\s*(?<body>.*?)\s*\}\s*else\s*\{\s*throw\s*([''"])Cannot parse version\4\s*\}'
$m = [regex]::Match($txt0, $patIf)
if(-not $m.Success){
  throw "FAIL-CLOSED: could not locate the extract-version if-block using `$lastZip.BaseName -match ..."
}

$rx = $m.Groups["rx"].Value

# Fix invalid \_ escapes in regex (safe)
$rx2 = $rx.Replace('\_', '_')

# Replacement block: compute $bn from Name and match on it
$replacement = @"
# extract version
# ABP_USE_NAME_BASENAME_V3G (use Name -> basename; avoid flaky .BaseName)
`$bn = [IO.Path]::GetFileNameWithoutExtension(`$lastZip.Name)
if(`$bn -match `"$rx2`"){
    `$version = `$Matches[1]
    # keep any existing normalize marker if present further down; normalize here is safe too
    `$version = "v" + (ABP-GetVersionCore (`$version.TrimStart("v")))
}else{
    throw "Cannot parse version"
}
"@

$txt1 = [regex]::Replace($txt0, $patIf, [System.Text.RegularExpressions.MatchEvaluator]{ param($mm) $replacement }, 1)

if($txt1 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt1 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_USE_NAME_BASENAME_V3G]"
