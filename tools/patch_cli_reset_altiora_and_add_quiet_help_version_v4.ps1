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
# helpers
# ------------------------------------------------------------
function Insert-AfterRegexFirst([string]$text, [string]$pattern, [string]$block){
  $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if(-not $m.Success){ throw "Insert: pattern introuvable: $pattern" }
  $lineEnd = $text.IndexOf("`n", $m.Index)
  if($lineEnd -lt 0){ $lineEnd = $text.Length } else { $lineEnd++ }
  return $text.Substring(0,$lineEnd) + $block + $text.Substring($lineEnd)
}

function Remove-LinesContainingAny([string]$text, [string[]]$needles){
  $lines = $text.Split("`n")
  $out = New-Object System.Collections.Generic.List[string]
  foreach($ln in $lines){
    $hit = $false
    foreach($n in $needles){
      if($ln -like "*$n*"){ $hit = $true; break }
    }
    if(-not $hit){ $out.Add($ln) }
  }
  return ($out.ToArray() -join "`n")
}

# ------------------------------------------------------------
# 1) read + normalize newlines
# ------------------------------------------------------------
$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible après reset" }
$raw = $raw0 -replace "`r`n","`n"

# ------------------------------------------------------------
# 2) remove footer band (idempotent)
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
$raw = Remove-LinesContainingAny $raw $needles
Write-Host "[PATCH] OK: footer band supprimé (si présent)"

# ------------------------------------------------------------
# 3) inject ABP_QUIET_BOOT after import argparse
# ------------------------------------------------------------
$qbBegin = "# BEGIN ABP_QUIET_BOOT"
$qbEnd   = "# END ABP_QUIET_BOOT"
if($raw.IndexOf($qbBegin) -lt 0){
  $qb = @(
    $qbBegin,
    "import sys as _sys",
    "ABP_QUIET_BOOT = any(a in _sys.argv[1:] for a in ('-h','--help','--version'))",
    $qbEnd,
    ""
  ) -join "`n"
  $raw = Insert-AfterRegexFirst $raw "^\s*import\s+argparse\s*$" ($qb + "`n")
  Write-Host "[PATCH] OK: ABP_QUIET_BOOT ajouté"
}

# ------------------------------------------------------------
# 4) add __ABP_VERSION_STR before parser creation (regex capture indent)
# ------------------------------------------------------------
$verBegin = "# BEGIN ABP_VERSION_STR"
$verEnd   = "# END ABP_VERSION_STR"
if($raw.IndexOf($verBegin) -lt 0){
  $mParser = [regex]::Match(
    $raw,
    "^(?<ind>\s*)parser\s*=\s*argparse\.ArgumentParser",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if(-not $mParser.Success){ throw "parser = argparse.ArgumentParser introuvable (regex)" }

  $indent = $mParser.Groups["ind"].Value

  $ver = @(
    $indent + $verBegin,
    $indent + "try:",
    $indent + "    __ABP_VERSION_STR = f""Altiora Backup Pro v{__version__}""",
    $indent + "except Exception:",
    $indent + "    __ABP_VERSION_STR = ""Altiora Backup Pro""",
    $indent + $verEnd,
    ""
  ) -join "`n"

  # insert at beginning of parser line
  $raw = $raw.Substring(0, $mParser.Index) + $ver + $raw.Substring($mParser.Index)
  Write-Host "[PATCH] OK: __ABP_VERSION_STR ajouté"
}

# ------------------------------------------------------------
# 5) add --version argument (if absent) right after the line that closes ArgumentParser(...)
#    We find first line " ) " after parser=... (multiline), then insert.
# ------------------------------------------------------------
$addBegin = "# BEGIN ABP_ADD_VERSION_ARG"
$addEnd   = "# END ABP_ADD_VERSION_ARG"
if($raw.IndexOf($addBegin) -lt 0){
  $mParser2 = [regex]::Match(
    $raw,
    "^(?<ind>\s*)parser\s*=\s*argparse\.ArgumentParser",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if(-not $mParser2.Success){ throw "parser = argparse.ArgumentParser introuvable (phase --version)" }
  $indent2 = $mParser2.Groups["ind"].Value

  $tail = $raw.Substring($mParser2.Index)
  $mCloseLine = [regex]::Match(
    $tail,
    "^(?<ind>\s*)\)\s*$",
    [System.Text.RegularExpressions.RegexOptions]::Multiline
  )
  if(-not $mCloseLine.Success){ throw "Ligne de fermeture ')' introuvable après parser=..." }

  $closeLineAbs = $mParser2.Index + $mCloseLine.Index
  $eol = $raw.IndexOf("`n", $closeLineAbs)
  if($eol -lt 0){ $eol = $raw.Length } else { $eol = $eol + 1 }

  $add = @(
    $indent2 + $addBegin,
    $indent2 + "parser.add_argument(",
    $indent2 + "    ""--version"",",
    $indent2 + "    action=""version"",",
    $indent2 + "    version=__ABP_VERSION_STR",
    $indent2 + ")",
    $indent2 + $addEnd,
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$eol) + $add + $raw.Substring($eol)
  Write-Host "[PATCH] OK: --version ajouté"
}

# ------------------------------------------------------------
# 6) guard init: skip BackupCore/DB/logs on help/version
# ------------------------------------------------------------
$guardBegin = "# BEGIN ABP_INIT_GUARD_HELP_VERSION"
if($raw.IndexOf($guardBegin) -lt 0){
  $startNeedles = @(
    '_safe_print("🚀 Initialisation du système...")',
    "_safe_print('🚀 Initialisation du système...')"
  )
  $endNeedle = "parent = argparse.ArgumentParser(add_help=False)"

  $start = -1
  foreach($sn in $startNeedles){
    $pos = $raw.IndexOf($sn)
    if($pos -ge 0){ $start = $pos; break }
  }
  $end = $raw.IndexOf($endNeedle)
  if($start -lt 0 -or $end -lt 0 -or $end -le $start){
    throw "Impossible de localiser le bloc init (markers introuvables)."
  }

  $lineStart = $raw.LastIndexOf("`n",$start)
  if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

  $initBlock = $raw.Substring($lineStart, $end - $lineStart)
  $firstLineEnd = $initBlock.IndexOf("`n")
  $firstLine = $initBlock
  if($firstLineEnd -ge 0){ $firstLine = $initBlock.Substring(0,$firstLineEnd) }
  $indentG = ([regex]::Match($firstLine, "^\s*")).Value

  $initLines = $initBlock.Split("`n")
  $initIndented = ($initLines | ForEach-Object { $indentG + "    " + $_ }) -join "`n"

  $wrapper = @(
    $indentG + "# BEGIN ABP_INIT_GUARD_HELP_VERSION",
    $indentG + "if ABP_QUIET_BOOT:",
    $indentG + "    core = None",
    $indentG + "    backup_core_module = None",
    $indentG + "else:",
    $initIndented,
    $indentG + "# END ABP_INIT_GUARD_HELP_VERSION",
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$lineStart) + $wrapper + $raw.Substring($end)
  Write-Host "[PATCH] OK: init guard help/version ajouté"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: altiora.py prêt (reset+footer removed+quiet help/version+--version)"
