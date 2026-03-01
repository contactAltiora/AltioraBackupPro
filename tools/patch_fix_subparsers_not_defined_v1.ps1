$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

# 1) Trouver le 1er "subparsers.add_parser("
$mUse = [regex]::Match($raw, "(?m)^(?<ind>\s*)subparsers\.add_parser\(", "Multiline")
if(-not $mUse.Success){
  throw "Aucun 'subparsers.add_parser(' trouvé : structure différente"
}

$indent = $mUse.Groups["ind"].Value

# 2) Vérifier si subparsers est défini AVANT
$before = $raw.Substring(0, $mUse.Index)
$hasDef = [regex]::IsMatch(
  $before,
  "(?m)^\s*subparsers\s*=\s*parser\.add_subparsers\(",
  "Multiline"
)

if(-not $hasDef){
  # insérer juste avant la ligne d'usage
  $lineStart = $raw.LastIndexOf("`n", $mUse.Index)
  if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

  # définition minimaliste (compatible)
  $ins = @(
    $indent + "subparsers = parser.add_subparsers(dest=""command"")",
    $indent + "try:",
    $indent + "    subparsers.required = True",
    $indent + "except Exception:",
    $indent + "    pass",
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$lineStart) + $ins + $raw.Substring($lineStart)
  Write-Host "[PATCH] OK: subparsers défini avant le 1er subparsers.add_parser"
} else {
  Write-Host "[PATCH] OK: subparsers déjà défini avant usage (rien à insérer)"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: fix subparsers not defined appliqué"
