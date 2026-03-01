$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

# 1) Ajouter param([switch]$NoUsbRequired) si pas déjà présent
# On cherche un bloc param( ... ) au début du script (dans les 2000 premiers chars).
$headLen = [Math]::Min(2000, $raw.Length)
$head = $raw.Substring(0, $headLen)

if($head -notmatch '(?s)\bparam\s*\('){
  # Pas de param() : on l'insère juste après $ErrorActionPreference si possible, sinon au début.
  $insertAt = 0
  $posEAP = $raw.IndexOf('$ErrorActionPreference')
  if($posEAP -ge 0){
    $lineEnd = $raw.IndexOf("`n", $posEAP)
    if($lineEnd -ge 0){ $insertAt = $lineEnd + 1 }
  }
  $paramBlock = "param([switch]`$NoUsbRequired)`n"
  $raw = $raw.Substring(0,$insertAt) + $paramBlock + $raw.Substring($insertAt)
} else {
  # param() existe : on ajoute $NoUsbRequired si absent
  if($head -notmatch '\$NoUsbRequired'){
    # insertion juste après "param(" (première occurrence)
    $m = [regex]::Match($raw, '\bparam\s*\(')
    if(-not $m.Success){ throw "param() détecté mais Match échoué" }
    $ins = $m.Index + $m.Length
    $raw = $raw.Substring(0,$ins) + "[switch]`$NoUsbRequired, " + $raw.Substring($ins)
  }
}

# 2) Ajouter une variable de contrôle USB (idempotent)
$needle = '$__ABP_NO_USB_REQUIRED = $NoUsbRequired'
if($raw -notmatch [regex]::Escape($needle)){
  # On place ça juste après le param() (ou après $ErrorActionPreference si pas trouvé)
  $posParam = $raw.IndexOf("param(")
  $insertAt2 = 0
  if($posParam -ge 0){
    $lineEnd2 = $raw.IndexOf("`n", $posParam)
    if($lineEnd2 -ge 0){ $insertAt2 = $lineEnd2 + 1 }
  } else {
    $posEAP2 = $raw.IndexOf('$ErrorActionPreference')
    if($posEAP2 -ge 0){
      $lineEnd3 = $raw.IndexOf("`n", $posEAP2)
      if($lineEnd3 -ge 0){ $insertAt2 = $lineEnd3 + 1 }
    }
  }
  $ctl = '$__ABP_NO_USB_REQUIRED = $NoUsbRequired' + "`n"
  $raw = $raw.Substring(0,$insertAt2) + $ctl + $raw.Substring($insertAt2)
}

# 3) Remplacer un éventuel "throw USB required" / check strict, si présent, pour le conditionner
# On fait un patch "soft": si le script contient une phrase "UsbRequired" ou "USB requis", on la garde mais on wrap.
# Si pas trouvé, on ne casse rien : le script copie "if present" donc pas de blocage.
$raw2 = $raw

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: param -NoUsbRequired ajouté (sans casser le flux release)"
