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
# 4) Fix EXISTING --version action='version' (MULTILINE)
#    - We patch ONLY the call text itself (no trailing whitespace eaten)
#    - We do NOT add a new --version
# ------------------------------------------------------------
$callPattern = "(?s)\b\w+\.add_argument\(\s*.*?--version.*?action\s*=\s*['""]version['""].*?\)"
$m = [regex]::Match($raw, $callPattern)
if(-not $m.Success){
  throw "Aucun bloc add_argument(...) contenant --version + action='version' trouvé."
}

$call = $m.Value
if($call -match "(?m)^\s*version\s*="){
  Write-Host "[PATCH] OK: --version déjà correct (version=...)"
} else {
  # insert before the FINAL ')' of the call (and keep everything else untouched)
  $idx = $call.LastIndexOf(")")
  if($idx -lt 0){ throw "Bloc --version invalide: pas de ')'" }

  # Make it robust: if there's already a trailing comma/newline style, we insert ", version=..."
  $patched = $call.Substring(0,$idx) + ", version=VERSION_STR" + $call.Substring($idx)

  $raw = $raw.Substring(0, $m.Index) + $patched + $raw.Substring($m.Index + $m.Length)
  Write-Host "[PATCH] OK: --version réparé (version=VERSION_STR ajouté) [no-newline-break]"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: reset+footer removed+--version fixed (v6)"
