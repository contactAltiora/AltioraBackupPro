$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "introuvable: $target" }

$arr = Get-Content -LiteralPath $target -Encoding UTF8

function Insert-BeforeFirstMatch([string[]]$lines, [string]$pattern, [string[]]$insert){
  $idx = -1
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i] -match $pattern){ $idx = $i; break }
  }
  if($idx -lt 0){ throw "pattern introuvable: $pattern" }

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    if($i -eq $idx){
      foreach($l in $insert){ [void]$out.Add($l) }
    }
    [void]$out.Add($lines[$i])
  }
  return ,$out.ToArray()
}

function Insert-AfterFirstMatch([string[]]$lines, [string]$pattern, [string[]]$insert){
  $idx = -1
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i] -match $pattern){ $idx = $i; break }
  }
  if($idx -lt 0){ throw "pattern introuvable: $pattern" }

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    [void]$out.Add($lines[$i])
    if($i -eq $idx){
      foreach($l in $insert){ [void]$out.Add($l) }
    }
  }
  return ,$out.ToArray()
}

# -----------------------
# 1) Smoke-Tests: ensure protected assets exist next to EXE before running smoke commands
# Insert right before first "& $exe "backup"" (within Smoke-Tests)
# -----------------------
$smokeInsert = @(
'',
'  # Ensure protected-mode assets exist next to EXE (frozen base dir)',
'  $exeDir = Split-Path -Parent $exe',
'  $repoRoot = $Root',
'  $kSrc = Join-Path $repoRoot "keys\altiora_public_key.pem"',
'  $s1  = Join-Path $repoRoot "STATE.md"',
'  $s2  = Join-Path $repoRoot "STATE.md.sig"',
'  if(!(Test-Path -LiteralPath $kSrc)){ throw "Smoke: missing repo key: $kSrc" }',
'  if(!(Test-Path -LiteralPath $s1)){  throw "Smoke: missing repo state: $s1" }',
'  if(!(Test-Path -LiteralPath $s2)){  throw "Smoke: missing repo state sig: $s2" }',
'  $kDstDir = Join-Path $exeDir "keys"',
'  New-Item -ItemType Directory -Force $kDstDir | Out-Null',
'  Copy-Item -LiteralPath $kSrc -Destination (Join-Path $kDstDir "altiora_public_key.pem") -Force',
'  Copy-Item -LiteralPath $s1  -Destination (Join-Path $exeDir "STATE.md") -Force',
'  Copy-Item -LiteralPath $s2  -Destination (Join-Path $exeDir "STATE.md.sig") -Force',
''
)

# Avoid double insert if already patched
$alreadySmoke = $false
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match 'Ensure protected-mode assets exist next to EXE'){
    $alreadySmoke = $true; break
  }
}
if(-not $alreadySmoke){
  $arr = Insert-BeforeFirstMatch -lines $arr -pattern '^\s*&\s*\$exe\s+"backup"\s+' -insert $smokeInsert
}

# -----------------------
# 2) Make-ReleasePackage: copy assets into release folder (next to EXE) so the ZIP is runnable
# Insert right after "Copy-Item ... $exeOut"
# -----------------------
$releaseInsert = @(
'',
'  # Include protected-mode assets in release folder (required by EXE in protected mode)',
'  $kSrc = Join-Path $repo "keys\altiora_public_key.pem"',
'  $s1  = Join-Path $repo "STATE.md"',
'  $s2  = Join-Path $repo "STATE.md.sig"',
'  if(!(Test-Path -LiteralPath $kSrc)){ throw "Release: missing repo key: $kSrc" }',
'  if(!(Test-Path -LiteralPath $s1)){  throw "Release: missing repo state: $s1" }',
'  if(!(Test-Path -LiteralPath $s2)){  throw "Release: missing repo state sig: $s2" }',
'  $kDstDir = Join-Path $relDir "keys"',
'  New-Item -ItemType Directory -Force $kDstDir | Out-Null',
'  Copy-Item -LiteralPath $kSrc -Destination (Join-Path $kDstDir "altiora_public_key.pem") -Force',
'  Copy-Item -LiteralPath $s1  -Destination (Join-Path $relDir "STATE.md") -Force',
'  Copy-Item -LiteralPath $s2  -Destination (Join-Path $relDir "STATE.md.sig") -Force',
''
)

$alreadyRel = $false
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match 'Include protected-mode assets in release folder'){
    $alreadyRel = $true; break
  }
}
if(-not $alreadyRel){
  $arr = Insert-AfterFirstMatch -lines $arr -pattern '^\s*Copy-Item\s+-LiteralPath\s+\$exe\s+-Destination\s+\$exeOut\s+-Force\s*$' -insert $releaseInsert
}

Set-Content -LiteralPath $target -Value $arr -Encoding UTF8

# -----------------------
# Self-checks
# -----------------------
$after = Get-Content -LiteralPath $target -Encoding UTF8

$ok1 = $false
$ok2 = $false
for($i=0; $i -lt $after.Count; $i++){
  if($after[$i] -match 'Ensure protected-mode assets exist next to EXE'){ $ok1 = $true }
  if($after[$i] -match 'Include protected-mode assets in release folder'){ $ok2 = $true }
}
if(-not $ok1){ throw "Patch FAILED: smoke insert missing" }
if(-not $ok2){ throw "Patch FAILED: release insert missing" }

Write-Host "OK: release_build_and_backup.ps1 patched (smoke assets + release assets)" -ForegroundColor Green
