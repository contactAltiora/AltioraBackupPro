$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\update_state_md.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($txt0)){ throw "FAIL-CLOSED: empty file read: $path" }

if($txt0 -like "*ABP_UPDATE_STATE_USE_NAME_BN_V3K3MIN*"){
  Write-Host "Already patched: ABP_UPDATE_STATE_USE_NAME_BN_V3K3MIN. No change."
  exit 0
}

# Anchors
if($txt0 -notlike "*# extract version*"){ throw "FAIL-CLOSED: anchor not found: '# extract version'" }
if($txt0 -notlike "*throw ""Version parse error""*"){ throw "FAIL-CLOSED: anchor not found: 'Version parse error'" }
if($txt0 -notmatch '(?is)\$lastZip\.BaseName\s*-match\s*"\^AltioraBackupPro_'){ throw "FAIL-CLOSED: expected BaseName -match AltioraBackupPro_ not found." }

$txt = $txt0

# Replace only the match line + inject bn line above it, and relax regex for suffixes
# 1) inject $bn line just before the if(...)
$patInject = '(?m)^\s*#\s*extract\s+version\s*\r?\n'
if(-not [regex]::IsMatch($txt, $patInject)){ throw "FAIL-CLOSED: cannot locate '# extract version' line." }

$txt = [regex]::Replace($txt, $patInject, @"
# extract version
# ABP_UPDATE_STATE_USE_NAME_BN_V3K3MIN
`$bn = [IO.Path]::GetFileNameWithoutExtension(`$lastZip.Name)
"@, 1)

# 2) change if($lastZip.BaseName -match "STRICT") to if($bn -match "TOLERANT")
$patIf = '(?is)if\s*\(\s*\$lastZip\.BaseName\s*-match\s*"[^"]*"\s*\)'
if(-not [regex]::IsMatch($txt, $patIf)){ throw "FAIL-CLOSED: could not find BaseName -match if(...) to replace." }

$rx2 = '^AltioraBackupPro_(v\d+\.\d+\.\d+)(?:[A-Za-z0-9.+_-]+)?_release$'
$txt2 = [regex]::Replace($txt, $patIf, "if(`$bn -match `"$rx2`")", 1)

if($txt2 -eq $txt0){ throw "FAIL-CLOSED: no changes produced (unexpected)." }

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\update_state_md.ps1 [ABP_UPDATE_STATE_USE_NAME_BN_V3K3MIN]"
