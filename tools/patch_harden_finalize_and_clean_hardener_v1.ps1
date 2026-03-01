$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$tools = Join-Path $root "tools"

# ---------- 1) Harden release_finalize_and_state.ps1 ----------
$finalize = Join-Path $tools "release_finalize_and_state.ps1"
if(!(Test-Path -LiteralPath $finalize)){ throw "introuvable: $finalize" }

$arr = Get-Content -LiteralPath $finalize -Encoding UTF8

# Ensure dot-source safe_fs exists (should already, but keep safe)
$needle = '. "$PSScriptRoot\safe_fs.ps1"'
$hasDot = $false
foreach($l in $arr){ if($l.Trim() -eq $needle){ $hasDot = $true; break } }
if(-not $hasDot){
  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  for($i=0; $i -lt $arr.Count; $i++){
    [void]$out.Add($arr[$i])
    if(-not $inserted -and $arr[$i] -match '^\s*\$ErrorActionPreference\s*=\s*"?Stop"?\s*$'){
      [void]$out.Add($needle)
      [void]$out.Add('')
      $inserted = $true
    }
  }
  if(-not $inserted){
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($needle)
    [void]$out2.Add('')
    foreach($l in $out){ [void]$out2.Add($l) }
    $arr = $out2.ToArray()
  } else {
    $arr = $out.ToArray()
  }
}

# Replace the specific Get-ChildItem line for lastZip detection
$replaced = $false
for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*\$lastZip\s*=\s*Get-ChildItem\s+\$releasesDir\s+-Filter\s+"AltioraBackupPro_v\*_release\.zip"\s+\|\s*$'){
    $arr[$i] = '  $lastZip = Safe-GetChildItem -LiteralPath $releasesDir -Filter "AltioraBackupPro_v*_release.zip" -File -OnError Stop |'
    $replaced = $true
    break
  }
}
if(-not $replaced){
  throw "Patch v1: pattern lastZip introuvable dans release_finalize_and_state.ps1"
}

Set-Content -LiteralPath $finalize -Value $arr -Encoding UTF8


# ---------- 2) Clean patch_harden_getchilditem_safepath_v2.ps1 (optional but makes scans clean) ----------
$hardV2 = Join-Path $tools "patch_harden_getchilditem_safepath_v2.ps1"
if(Test-Path -LiteralPath $hardV2){
  $h = Get-Content -LiteralPath $hardV2 -Encoding UTF8

  # Ensure dot-source safe_fs exists (should already)
  $hasDot2 = $false
  foreach($l in $h){ if($l.Trim() -eq $needle){ $hasDot2 = $true; break } }
  if(-not $hasDot2){
    $out = New-Object System.Collections.Generic.List[string]
    $inserted = $false
    for($i=0; $i -lt $h.Count; $i++){
      [void]$out.Add($h[$i])
      if(-not $inserted -and $h[$i] -match '^\s*\$ErrorActionPreference\s*=\s*"?Stop"?\s*$'){
        [void]$out.Add($needle)
        [void]$out.Add('')
        $inserted = $true
      }
    }
    $h = $out.ToArray()
  }

  # Replace any Get-ChildItem -LiteralPath $tools ... with Safe-GetChildItem (keeps behavior, adds SafePath guard)
  for($i=0; $i -lt $h.Count; $i++){
    if($h[$i] -match '^\s*Get-ChildItem\s+-LiteralPath\s+\$tools\b'){
      $h[$i] = $h[$i] -replace '^\s*Get-ChildItem\b', 'Safe-GetChildItem'
    }
  }

  Set-Content -LiteralPath $hardV2 -Value $h -Encoding UTF8
}

Write-Host "OK: finalize hardened + hardener v2 cleaned" -ForegroundColor Green
