$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n", "`n"

$beginMark = "# BEGIN ABP_GATE_SELFTEST_NONCE"
$endMark   = "# END ABP_GATE_SELFTEST_NONCE"
$needleRun = 'Write-Host "RUN SELFTEST: crypto nonce uniqueness"'
$needleOk  = 'Write-Host "SELFTEST OK"'

$posBegin = $raw.IndexOf($beginMark)
$posEnd   = $raw.IndexOf($endMark)

if($posBegin -lt 0 -or $posEnd -lt 0 -or $posBegin -ge $posEnd){
  throw "Bloc marqué BEGIN/END introuvable ou invalide"
}

# Position juste après la ligne END
$afterEndLine = $raw.IndexOf("`n", $posEnd)
if($afterEndLine -lt 0){ $afterEndLine = $posEnd + $endMark.Length } else { $afterEndLine = $afterEndLine + 1 }

# Chercher un RUN SELFTEST uniquement après le bloc marqué
$posRun2 = $raw.IndexOf($needleRun, $afterEndLine)
if($posRun2 -lt 0){
  Write-Host "[PATCH] OK: aucun legacy gate après le bloc marqué (rien à supprimer)"
  exit 0
}

# Déterminer le début du legacy block: début de ligne du RUN
$lineStart = $raw.LastIndexOf("`n", $posRun2)
if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

# Optionnel: si juste avant il y a un séparateur de tirets, on l'englobe (mais seulement si après END)
$sep = "# ------------------------------------------------------------"
$posSep = $raw.LastIndexOf($sep, $posRun2)
if($posSep -ge $afterEndLine){
  # prendre le début de ligne du séparateur
  $sepLineStart = $raw.LastIndexOf("`n", $posSep)
  if($sepLineStart -lt 0){ $sepLineStart = 0 } else { $sepLineStart = $sepLineStart + 1 }
  $blockStart = $sepLineStart
} else {
  $blockStart = $lineStart
}

# Fin du legacy block: fin de ligne après SELFTEST OK qui suit ce RUN
$posOk = $raw.IndexOf($needleOk, $posRun2)
if($posOk -lt 0){ throw "SELFTEST OK introuvable après le legacy RUN (après END)" }

$blockEnd = $raw.IndexOf("`n", $posOk)
if($blockEnd -lt 0){ $blockEnd = $posOk + $needleOk.Length } else { $blockEnd = $blockEnd + 1 }

# Sécurité absolue: ne rien supprimer avant END
if($blockStart -lt $afterEndLine){
  throw "Sécurité: tentative suppression avant fin du bloc marqué => abort"
}

$raw2 = $raw.Substring(0, $blockStart) + $raw.Substring($blockEnd)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: legacy gate selftest (après bloc marqué) supprimé"
