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
# 4) Fix EXISTING --version (do NOT add a new one)
#    If action='version' exists without version=..., add version=VERSION_STR
# ------------------------------------------------------------
$lines = $raw.Split("`n")
$fixed = $false

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]

  # any line that defines --version with action="version"
  if($ln -match "--version" -and $ln -match "action\s*=\s*['""]version['""]"){
    if($ln -match "version\s*="){
      Write-Host "[PATCH] OK: --version existant déjà correct (version=...)"
      $fixed = $true
      break
    }

    $idx = $ln.LastIndexOf(")")
    if($idx -gt 0){
      $before = $ln.Substring(0,$idx)
      $after  = $ln.Substring($idx)
      $lines[$i] = $before + ", version=VERSION_STR" + $after
      Write-Host "[PATCH] OK: --version existant réparé (version=VERSION_STR ajouté)"
      $fixed = $true
      break
    }
  }
}

if(-not $fixed){
  # Fallback: if no --version exists at all, add it once after parser creation close ")"
  Write-Host "[PATCH] WARN: aucun --version action='version' trouvé; insertion fallback"

  $raw = ($lines -join "`n")
  $mParser = [regex]::Match(
    $raw,
    "^(?<ind>\s*)parser\s*=\s*argparse\.ArgumentParser",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if(-not $mParser.Success){ throw "parser = argparse.ArgumentParser introuvable" }
  $indent = $mParser.Groups["ind"].Value

  $tail = $raw.Substring($mParser.Index)
  $mClose = [regex]::Match(
    $tail,
    "^(?<ind>\s*)\)\s*$",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if(-not $mClose.Success){ throw "Fermeture ')' du bloc ArgumentParser introuvable" }

  $closeAbs = $mParser.Index + $mClose.Index
  $eol = $raw.IndexOf("`n", $closeAbs)
  if($eol -lt 0){ $eol = $raw.Length } else { $eol = $eol + 1 }

  $add = @(
    $indent + "# BEGIN ABP_ADD_VERSION_ARG",
    $indent + "parser.add_argument(",
    $indent + "    ""--version"",",
    $indent + "    action=""version"",",
    $indent + "    version=VERSION_STR",
    $indent + ")",
    $indent + "# END ABP_ADD_VERSION_ARG",
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$eol) + $add + $raw.Substring($eol)
  $lines = $raw.Split("`n")
}

$raw = ($lines -join "`n")

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: reset+footer removed+--version fixed (no duplicate)"
