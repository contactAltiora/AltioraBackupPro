$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n", "`n"

$needleRun = 'Write-Host "RUN SELFTEST: crypto nonce uniqueness"'
$needleOk  = 'Write-Host "SELFTEST OK"'
$beginMark = "# BEGIN ABP_GATE_SELFTEST_NONCE"
$endMark   = "# END ABP_GATE_SELFTEST_NONCE"

# Find first and second occurrences of RUN SELFTEST
$first = $raw.IndexOf($needleRun)
if($first -lt 0){ throw "RUN SELFTEST introuvable (needleRun)" }

$second = $raw.IndexOf($needleRun, $first + 1)
if($second -lt 0){
  Write-Host "[PATCH] OK: aucun legacy gate détecté (un seul RUN SELFTEST)"
  exit 0
}

# Ensure second occurrence is not inside the marked block
$posBegin = $raw.IndexOf($beginMark)
$posEnd   = $raw.IndexOf($endMark)
if($posBegin -ge 0 -and $posEnd -ge 0 -and $posBegin -lt $posEnd){
  if($second -ge $posBegin -and $second -le $posEnd){
    throw "Le 2e RUN SELFTEST est dans le bloc marqué => incohérence"
  }
}

# Determine block start: nearest '# ------------------------------------------------------------' before second (within 2000 chars)
$searchStart = [Math]::Max(0, $second - 2000)
$chunk = $raw.Substring($searchStart, $second - $searchStart)
$rel = $chunk.LastIndexOf("# ------------------------------------------------------------")
if($rel -ge 0){
  $blockStart = $searchStart + $rel
} else {
  $blockStart = $second
}

# Determine block end: after the next 'SELFTEST OK' following second
$posOk = $raw.IndexOf($needleOk, $second)
if($posOk -lt 0){ throw "SELFTEST OK introuvable après le 2e RUN SELFTEST" }

# remove through end-of-line after SELFTEST OK
$lineEnd = $raw.IndexOf("`n", $posOk)
if($lineEnd -lt 0){ $blockEnd = $posOk + $needleOk.Length } else { $blockEnd = $lineEnd + 1 }

# Extra safety: do not delete the marked block
if($posBegin -ge 0 -and $blockStart -ge $posBegin -and $blockStart -le ($posEnd + 200)){
  throw "Le blockStart tombe dans la zone du bloc marqué => abort"
}

$raw2 = $raw.Substring(0, $blockStart) + $raw.Substring($blockEnd)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: legacy gate selftest (non marqué) supprimé"
