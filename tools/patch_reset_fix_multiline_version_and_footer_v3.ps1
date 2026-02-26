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
# 2) remove any previously inserted ABP_ADD_VERSION_ARG block (safety)
# ------------------------------------------------------------
$raw = [regex]::Replace(
  $raw,
  "(?s)^[ \t]*# BEGIN ABP_ADD_VERSION_ARG.*?^[ \t]*# END ABP_ADD_VERSION_ARG[ \t]*\n?",
  "",
  [System.Text.RegularExpressions.RegexOptions]::Multiline
)

# ------------------------------------------------------------
# 3) remove footer band lines (idempotent)
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
# 4) Ensure VERSION_STR exists (idempotent) after "import argparse"
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
# 5) Fix EXISTING --version action='version' (MULTILINE) by adding version=VERSION_STR
#    IMPORTANT: we do NOT add any new --version.
# ------------------------------------------------------------
# Match any add_argument(...) block (parser.add_argument or parent.add_argument etc.)
# that contains --version and action="version" but NOT already version=...
$pattern = "(?s)(?<head>\b\w+\.add_argument\()\s*(?<body>.*?--version.*?action\s*=\s*['""]version['""].*?)\)"
$matches = [regex]::Matches($raw, $pattern)

if($matches.Count -eq 0){
  throw "Aucun bloc add_argument(...) contenant --version + action='version' trouvé. (On n'ajoute pas de doublon.)"
}

$did = $false
foreach($m in $matches){
  $callText = $m.Value
  if($callText -match "version\s*="){
    Write-Host "[PATCH] OK: --version déjà correct (version=...)"
    $did = $true
    break
  }

  # Insert version=VERSION_STR just before the last ")"
  $idx = $callText.LastIndexOf(")")
  if($idx -lt 0){ continue }

  $patched = $callText.Substring(0,$idx) + ", version=VERSION_STR" + $callText.Substring($idx)

  # Replace only this occurrence (by index)
  $raw = $raw.Substring(0, $m.Index) + $patched + $raw.Substring($m.Index + $m.Length)

  Write-Host "[PATCH] OK: --version réparé (version=VERSION_STR ajouté) [multiline-safe]"
  $did = $true
  break
}

if(-not $did){
  throw "Impossible de réparer --version (cas inattendu)."
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: reset+footer removed+--version fixed (multiline, no duplicate)"
