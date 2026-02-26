$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

# 1) Si une ligne "= argparse.ArgumentParser(add_help=False)" existe sans variable, on la répare
$raw = [regex]::Replace(
  $raw,
  "(?m)^(?<ind>\s*)=\s*argparse\.ArgumentParser\(add_help=False\)\s*$",
  '${ind}parent = argparse.ArgumentParser(add_help=False)'
)

# 2) Trouver le 1er "parent.add_argument("
$mAdd = [regex]::Match($raw, "(?m)^(?<ind>\s*)parent\.add_argument\(", "Multiline")
if(-not $mAdd.Success){
  throw "Aucun 'parent.add_argument(' trouvé : impossible de fixer (structure différente)"
}

$indent = $mAdd.Groups["ind"].Value

# 3) Vérifier si "parent = argparse.ArgumentParser(add_help=False)" existe AVANT ce 1er add_argument
$before = $raw.Substring(0, $mAdd.Index)
$hasParentDef = [regex]::IsMatch($before, "(?m)^\s*parent\s*=\s*argparse\.ArgumentParser\(add_help=False\)\s*$")

if(-not $hasParentDef){
  # insérer juste avant la ligne parent.add_argument(
  $lineStart = $raw.LastIndexOf("`n", $mAdd.Index)
  if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

  $ins = $indent + "parent = argparse.ArgumentParser(add_help=False)`n"
  $raw = $raw.Substring(0,$lineStart) + $ins + $raw.Substring($lineStart)

  Write-Host "[PATCH] OK: parent=ArgumentParser(add_help=False) inséré avant le 1er parent.add_argument"
} else {
  Write-Host "[PATCH] OK: parent déjà défini avant parent.add_argument (rien à insérer)"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: fix parent not defined appliqué"
