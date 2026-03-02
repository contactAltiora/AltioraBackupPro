$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\patch_runner.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "patch_runner.ps1 introuvable: $target" }

$txt = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

if($txt -match "ABP_STATE_GUARD_V6C2"){
  Write-Host "STATE guard already present (V6C2). No change."
  exit 0
}

# Anchors
$anchorPre  = '$abp_cmd = @"'
$anchorPost = 'Write-Host "PATCH OK: $p"'

$idxPre  = $txt.IndexOf($anchorPre,  [System.StringComparison]::Ordinal)
if($idxPre -lt 0){ throw "FAIL-CLOSED: anchor PRE introuvable: $anchorPre" }

$idxPost = $txt.IndexOf($anchorPost, [System.StringComparison]::Ordinal)
if($idxPost -lt 0){ throw "FAIL-CLOSED: anchor POST introuvable: $anchorPost" }
if($idxPost -le $idxPre){ throw "FAIL-CLOSED: anchor POST trouvé avant PRE (runner inattendu)" }

# IMPORTANT: single quotes => NO expansion during patch creation
$preBlock = @(
  '# ABP_STATE_GUARD_V6C2 (PRE)',
  '$__abp_state_md      = Join-Path $root "STATE.md"',
  '$__abp_state_sig     = Join-Path $root "STATE.md.sig"',
  '$__abp_state_sha256  = Join-Path $root "STATE.md.sha256"',
  'if(!(Test-Path -LiteralPath $__abp_state_md)){ throw "FAIL-CLOSED: STATE.md introuvable" }',
  'if(!(Test-Path -LiteralPath $__abp_state_sig)){ throw "FAIL-CLOSED: STATE.md.sig introuvable" }',
  'if(!(Test-Path -LiteralPath $__abp_state_sha256)){ throw "FAIL-CLOSED: STATE.md.sha256 introuvable" }',
  '$__abp_h_md     = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_md).Hash',
  '$__abp_h_sig    = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_sig).Hash',
  '$__abp_h_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_sha256).Hash',
  ''
) -join "`r`n"

$postBlock = @(
  '# ABP_STATE_GUARD_V6C2 (POST)',
  'if(!(Test-Path -LiteralPath $__abp_state_md)){ throw "FAIL-CLOSED: STATE.md supprimé par patch" }',
  'if(!(Test-Path -LiteralPath $__abp_state_sig)){ throw "FAIL-CLOSED: STATE.md.sig supprimé par patch" }',
  'if(!(Test-Path -LiteralPath $__abp_state_sha256)){ throw "FAIL-CLOSED: STATE.md.sha256 supprimé par patch" }',
  '$__abp_h2_md     = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_md).Hash',
  '$__abp_h2_sig    = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_sig).Hash',
  '$__abp_h2_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $__abp_state_sha256).Hash',
  'if($__abp_h_md -ne $__abp_h2_md){ throw "FAIL-CLOSED: modification non autorisée de STATE.md détectée" }',
  'if($__abp_h_sig -ne $__abp_h2_sig){ throw "FAIL-CLOSED: modification non autorisée de STATE.md.sig détectée" }',
  'if($__abp_h_sha256 -ne $__abp_h2_sha256){ throw "FAIL-CLOSED: modification non autorisée de STATE.md.sha256 détectée" }',
  ''
) -join "`r`n"

# Insert PRE just before $abp_cmd = @"
$txt2 = $txt.Substring(0, $idxPre) + $preBlock + $txt.Substring($idxPre)

# Recompute POST after PRE insertion
$idxPost2 = $txt2.IndexOf($anchorPost, [System.StringComparison]::Ordinal)
if($idxPost2 -lt 0){ throw "FAIL-CLOSED: anchor POST introuvable après insertion PRE" }

# Insert POST just after the PATCH OK line
$eol = $txt2.IndexOf("`n", $idxPost2)
if($eol -lt 0){ $eol = $txt2.Length } else { $eol = $eol + 1 }
$txt3 = $txt2.Substring(0, $eol) + $postBlock + $txt2.Substring($eol)

# Parse validation (fail-closed)
$toks = $null
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($txt3, [ref]$toks, [ref]$errs)
if($errs -and $errs.Count -gt 0){
  throw ("FAIL-CLOSED: patch_runner.ps1 parse check failed after patch: " + $errs[0].Message)
}

Set-Content -LiteralPath $target -Value $txt3 -Encoding UTF8
Write-Host "OK: STATE guard V6C2 injected into tools\patch_runner.ps1"
