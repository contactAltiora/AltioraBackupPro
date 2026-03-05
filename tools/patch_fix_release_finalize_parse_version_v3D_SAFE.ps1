$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

# --- repo root (fail-closed)
$repo = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repo)){ throw "FAIL-CLOSED: not a git repo (run from C:\Dev\AltioraBackupPro)" }
Set-Location $repo

$path = Join-Path $repo "tools\release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# FAIL-CLOSED anchors we expect in your file
if($txt0 -notlike "*throw ""Cannot parse version""*"){ throw "FAIL-CLOSED: anchor not found: 'Cannot parse version'" }

# Idempotent
if($txt0 -like "*ABP_PARSE_VERSION_SUFFIX_V3D*"){
  Write-Host "Already patched: ABP_PARSE_VERSION_SUFFIX_V3D. No change."
  exit 0
}

$txt = $txt0

# Replace the specific extraction that sets $version from $Matches[1] then throws.
# We target a broad but safe pattern: any block that assigns `$version = $Matches[1]` and has `throw "Cannot parse version"` nearby.
$pat = '(?is)(?<pre>^\s*#\s*extract\s+version\s*\r?\n)?(?<blk>(?:.|\r|\n){0,400}?\$version\s*=\s*\$Matches\[\s*1\s*\](?:.|\r|\n){0,400}?throw\s*([''"])Cannot parse version\3(?:.|\r|\n){0,200}?)'

$m = [regex]::Match($txt, $pat)
if(-not $m.Success){
  throw "FAIL-CLOSED: could not locate extract/throw region. Please inspect around the line that throws 'Cannot parse version'."
}

$replacement = @"
# ABP_PARSE_VERSION_SUFFIX_V3D
# Accept suffixes but extract core X.Y.Z into `$version.
# Example accepted: 1.0.17p1, 1.0.17-rc1, 1.0.17+build.5  -> core = 1.0.17
# NOTE: we rely on the same source string previously used for -match (kept earlier in script).
if(`$VersionString -match '(?<core>\d+\.\d+\.\d+)(?:[A-Za-z0-9\.\+\-\_]+)?'){
  `$version = `$Matches['core']
} else {
  throw "Cannot parse version"
}
"@

# IMPORTANT: We need a stable source variable name.
# Many scripts already have something like $VersionString, $verLine, etc.
# We'll fail-closed if $VersionString isn't present.
if($txt -notmatch '(?is)\$VersionString\b'){
  throw "FAIL-CLOSED: expected `$VersionString variable not found. Adjust patch to your script's actual variable name used for version extraction."
}

$txt2 = [regex]::Replace($txt, $pat, $replacement, 1)

if($txt2 -eq $txt){
  throw "FAIL-CLOSED: no change after replacement (unexpected)."
}

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\release_finalize_and_state.ps1 [ABP_PARSE_VERSION_SUFFIX_V3D]"
