$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\patch_runner.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "patch_runner.ps1 introuvable: $target" }

$src = Get-Content -LiteralPath $target -Encoding UTF8

$preStartMarker = '# ABP_STATE_GUARD_V6B (PRE)'
$preEndMarker   = '# ABP_STATE_GUARD_V6C2 (PRE)'  # stop just BEFORE this line
$postStartMarker= '# ABP_STATE_GUARD_V6B (POST)'

# quick idempotence: if no V6B markers, do nothing
if(($src -notcontains $preStartMarker) -and ($src -notcontains $postStartMarker)){
  Write-Host "V6B markers not found. No change."
  exit 0
}

# --- remove V6B PRE block: from V6B(PRE) inclusive to line just before V6C2(PRE) ---
$idxPreStart = [Array]::IndexOf($src, $preStartMarker)
if($idxPreStart -lt 0){ throw "FAIL-CLOSED: V6B PRE marker introuvable." }

$idxV6c2Pre = [Array]::IndexOf($src, $preEndMarker)
if($idxV6c2Pre -lt 0){ throw "FAIL-CLOSED: V6C2 PRE marker introuvable (refuse to edit)." }

if($idxV6c2Pre -le $idxPreStart){
  throw "FAIL-CLOSED: ordre inattendu (V6C2 PRE avant V6B PRE)."
}

# Keep: [0..preStart-1] + [v6c2Pre..end]
$out = @()
if($idxPreStart -gt 0){ $out += $src[0..($idxPreStart-1)] }
$out += $src[$idxV6c2Pre..($src.Count-1)]

# --- remove V6B POST block: from V6B(POST) inclusive to its closing brace line '}' ---
$idxPostStart = [Array]::IndexOf($out, $postStartMarker)
if($idxPostStart -ge 0){
  # find first line AFTER marker that is exactly "}" (trimmed)
  $idxClose = -1
  for($i=$idxPostStart; $i -lt $out.Count; $i++){
    if($out[$i].Trim() -eq '}'){ $idxClose = $i; break }
  }
  if($idxClose -lt 0){ throw "FAIL-CLOSED: fin du bloc V6B POST introuvable (missing closing brace)." }

  # remove [postStart..close] inclusive
  $out2 = @()
  if($idxPostStart -gt 0){ $out2 += $out[0..($idxPostStart-1)] }
  if($idxClose -lt ($out.Count-1)){ $out2 += $out[($idxClose+1)..($out.Count-1)] }
  $out = $out2
} else {
  # if PRE existed but POST missing, refuse (inconsistent)
  if($src -contains $postStartMarker){
    throw "FAIL-CLOSED: V6B POST attendu mais introuvable après retrait PRE."
  }
  Write-Host "V6B POST marker not found (already removed)."
}

# sanity: V6C2 must still be present
if($out -notcontains $preEndMarker){
  throw "FAIL-CLOSED: V6C2 PRE marker a disparu (refuse to write)."
}

# parse-check
$txt = ($out -join "`r`n") + "`r`n"
$toks = $null
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($txt, [ref]$toks, [ref]$errs)
if($errs -and $errs.Count -gt 0){
  throw ("FAIL-CLOSED: patch_runner.ps1 parse check failed after edit: " + $errs[0].Message)
}

Set-Content -LiteralPath $target -Value $txt -Encoding UTF8

# verify markers
$v = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if($v -match 'ABP_STATE_GUARD_V6B'){
  throw "FAIL-CLOSED: V6B marker still present after write."
}
if($v -notmatch 'ABP_STATE_GUARD_V6C2'){
  throw "FAIL-CLOSED: V6C2 marker missing after write."
}

Write-Host "OK: Removed V6B guards; kept V6C2."
