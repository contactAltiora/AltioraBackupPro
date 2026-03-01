$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

# ------------------------------------------------------------
# 0) RESET altiora.py via Git (source of truth)
# ------------------------------------------------------------
if(-not (Get-Command git -ErrorAction SilentlyContinue)){ throw "git introuvable dans PATH" }
$inside = & git rev-parse --is-inside-work-tree 2>$null
if($LASTEXITCODE -ne 0 -or $inside.Trim() -ne "true"){ throw "Repo git non détecté (rev-parse KO)" }

& git checkout -- altiora.py
if($LASTEXITCODE -ne 0){ throw "git checkout -- altiora.py a échoué" }
Write-Host "[PATCH] OK: altiora.py reset depuis Git"

# ------------------------------------------------------------
# 1) read + normalize newlines
# ------------------------------------------------------------
$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible après reset" }
$raw = $raw0 -replace "`r`n","`n"

# ------------------------------------------------------------
# 2) remove footer band lines (idempotent)
# ------------------------------------------------------------
$needles = @(
  "support@altiora-backup.com",
  "📞 Support:",
  "💰 Prix:",
  "Prix:",
  "⚖️ Garantie 30 jours",
  "Garantie 30 jours",
  "🚀 Altiora Backup Pro v1.0",
  "Altiora Backup Pro v1.0"
)

$lines = $raw.Split("`n")
$out = New-Object System.Collections.Generic.List[string]
foreach($ln in $lines){
  $hit = $false
  foreach($n in $needles){
    if($ln -like "*$n*"){ $hit = $true; break }
  }
  if(-not $hit){ $out.Add($ln) }
}
$raw = ($out.ToArray() -join "`n")
Write-Host "[PATCH] OK: footer band supprimé (si présent)"

# ------------------------------------------------------------
# 3) Ensure VERSION_STR exists (idempotent) after "import argparse"
# ------------------------------------------------------------
function Insert-AfterRegexFirst([string]$text, [string]$pattern, [string]$block){
  $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if(-not $m.Success){ throw "Insert: pattern introuvable: $pattern" }
  $lineEnd = $text.IndexOf("`n", $m.Index)
  if($lineEnd -lt 0){ $lineEnd = $text.Length } else { $lineEnd++ }
  return $text.Substring(0,$lineEnd) + $block + $text.Substring($lineEnd)
}

$verBegin = "# BEGIN ABP_VERSION_STR"
$verEnd   = "# END ABP_VERSION_STR"
if($raw.IndexOf($verBegin) -lt 0){
  $block = @(
    $verBegin,
    "try:",
    "    VERSION_STR = f""Altiora Backup Pro v{__version__}""",
    "except Exception:",
    "    VERSION_STR = ""Altiora Backup Pro""",
    $verEnd,
    ""
  ) -join "`n"
  $raw = Insert-AfterRegexFirst $raw "^\s*import\s+argparse\s*$" ($block + "`n")
  Write-Host "[PATCH] OK: VERSION_STR ajouté"
}

# ------------------------------------------------------------
# 4) Fix EXISTING --version add_argument using BALANCED parentheses
# ------------------------------------------------------------
$idxVer = $raw.IndexOf("--version")
if($idxVer -lt 0){ throw "--version introuvable dans altiora.py (après reset)" }

# find nearest 'add_argument(' before --version
$idxAdd = $raw.LastIndexOf("add_argument(", $idxVer)
if($idxAdd -lt 0){ throw "add_argument( introuvable avant --version" }

# find opening paren of that add_argument call
$idxOpen = $raw.IndexOf("(", $idxAdd)
if($idxOpen -lt 0){ throw "Parenthèse ouvrante '(' introuvable pour add_argument" }

# walk forward and find matching closing paren
$depth = 0
$idxClose = -1
for($i=$idxOpen; $i -lt $raw.Length; $i++){
  $ch = $raw[$i]
  if($ch -eq '('){ $depth++ }
  elseif($ch -eq ')'){
    $depth--
    if($depth -eq 0){
      $idxClose = $i
      break
    }
  }
}
if($idxClose -lt 0){ throw "Impossible de trouver la parenthèse fermante de l'appel add_argument(--version)" }

$callText = $raw.Substring($idxAdd, ($idxClose - $idxAdd + 1))

if($callText -match "(?m)^\s*version\s*=" -or $callText -match "\bversion\s*="){
  Write-Host "[PATCH] OK: --version déjà correct (version=...)"
} else {
  # indentation of closing paren line
  $lineStart = $raw.LastIndexOf("`n", $idxClose)
  if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }
  $closeLine = $raw.Substring($lineStart, ($idxClose - $lineStart + 1))
  $indentClose = ([regex]::Match($closeLine, "^\s*")).Value
  $indentArg = $indentClose + "    "

  $insertion = "`n" + $indentArg + "version=VERSION_STR," + "`n" + $indentClose
  $raw = $raw.Substring(0, $idxClose) + $insertion + $raw.Substring($idxClose)

  Write-Host "[PATCH] OK: --version réparé (balanced-parens, newline-safe)"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: reset+footer removed+--version fixed (v7 balanced)"
