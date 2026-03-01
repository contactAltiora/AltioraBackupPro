$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

# ------------------------------------------------------------
# 0) RESET altiora.py via Git (source of truth)
# ------------------------------------------------------------
$git = (Get-Command git -ErrorAction SilentlyContinue)
if(-not $git){ throw "git introuvable dans PATH. Impossible de reset altiora.py automatiquement." }

$inside = & git rev-parse --is-inside-work-tree 2>$null
if($LASTEXITCODE -ne 0 -or $inside.Trim() -ne "true"){ throw "Repo git non détecté (rev-parse KO). Abort." }

& git checkout -- altiora.py
if($LASTEXITCODE -ne 0){ throw "git checkout -- altiora.py a échoué." }

Write-Host "[PATCH] OK: altiora.py reset depuis Git"

# ------------------------------------------------------------
# 1) Relire le fichier clean
# ------------------------------------------------------------
$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible après reset" }
$raw = $raw0 -replace "`r`n","`n"

# ------------------------------------------------------------
# 2) Supprimer footer band (idempotent)
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
$new = New-Object System.Collections.Generic.List[string]
foreach($ln in $lines){
  $hit = $false
  foreach($n in $needles){
    if($ln -like "*$n*"){ $hit = $true; break }
  }
  if(-not $hit){ $new.Add($ln) }
}
$raw = ($new.ToArray() -join "`n")
Write-Host "[PATCH] OK: footer band supprimé (si présent)"

# ------------------------------------------------------------
# 3) Inject ABP_QUIET_BOOT (après import argparse)
# ------------------------------------------------------------
function Insert-AfterFirstLineMatch([string]$text, [string]$pattern, [string]$block){
  $m = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if(-not $m.Success){ throw "Insert: pattern introuvable: $pattern" }
  $lineEnd = $text.IndexOf("`n", $m.Index)
  if($lineEnd -lt 0){ $lineEnd = $text.Length } else { $lineEnd++ }
  return $text.Substring(0,$lineEnd) + $block + $text.Substring($lineEnd)
}

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
  $raw = Insert-AfterFirstLineMatch $raw "^\s*import\s+argparse\s*$" ($qb + "`n")
  Write-Host "[PATCH] OK: ABP_QUIET_BOOT ajouté"
}

# ------------------------------------------------------------
# 4) Ajouter __ABP_VERSION_STR (avant création du parser)
#    On détecte "parser = argparse.ArgumentParser" en regex (espaces libres)
# ------------------------------------------------------------
$verBegin = "# BEGIN ABP_VERSION_STR"
$verEnd   = "# END ABP_VERSION_STR"
if($raw.IndexOf($verBegin) -lt 0){
  $mParser = [regex]::Match($raw, "^\s*parser\s*=\s*argparse\.ArgumentParser", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if(-not $mParser.Success){ throw "Ligne parser=.*argparse.ArgumentParser introuvable" }

  # insertion au début de la ligne parser=
  $ls = $raw.LastIndexOf("`n",$mParser.Index)
  if($ls -lt 0){ $ls = 0 } else { $ls = $ls + 1 }

  $indent = ([regex]::Match($raw.Substring($ls, $mParser.Index-$ls), "^\s*")).Value

  $ver = @(
    $indent + $verBegin,
    $indent + "try:",
    $indent + "    __ABP_VERSION_STR = f""Altiora Backup Pro v{__version__}""",
    $indent + "except Exception:",
    $indent + "    __ABP_VERSION_STR = ""Altiora Backup Pro""",
    $indent + $verEnd,
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$ls) + $ver + $raw.Substring($ls)
  Write-Host "[PATCH] OK: __ABP_VERSION_STR ajouté"
}

# ------------------------------------------------------------
# 5) Ajouter parser.add_argument(--version) après la fermeture du call ArgumentParser(...)
#    Scan parenthèses: on prend la "(" du ArgumentParser( et on trouve la fermeture correspondante
# ------------------------------------------------------------
$mParser2 = [regex]::Match($raw, "^\s*parser\s*=\s*argparse\.ArgumentParser", [System.Text.RegularExpressions.RegexOptions]::Multiline)
if(-not $mParser2.Success){ throw "parser=.*argparse.ArgumentParser introuvable (phase add --version)" }

$open = $raw.IndexOf("(", $mParser2.Index)
if($open -lt 0){ throw "Parenthèse ouvrante ArgumentParser( introuvable" }

$depth = 0
$close = -1
for($i=$open; $i -lt $raw.Length; $i++){
  $ch = $raw[$i]
  if($ch -eq "("){ $depth++ }
  elseif($ch -eq ")"){
    $depth--
    if($depth -eq 0){ $close = $i; break }
  }
}
if($close -lt 0){ throw "Parenthèse fermante ArgumentParser(...) introuvable" }

$eol = $raw.IndexOf("`n", $close)
if($eol -lt 0){ $eol = $close + 1 } else { $eol = $eol + 1 }

# indentation = celle de la ligne parser=
$ls2 = $raw.LastIndexOf("`n",$mParser2.Index)
if($ls2 -lt 0){ $ls2 = 0 } else { $ls2 = $ls2 + 1 }
$indent2 = ([regex]::Match($raw.Substring($ls2, $mParser2.Index-$ls2), "^\s*")).Value

$addBegin = "# BEGIN ABP_ADD_VERSION_ARG"
$addEnd   = "# END ABP_ADD_VERSION_ARG"
if($raw.IndexOf($addBegin) -lt 0){
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
  Write-Host "[PATCH] OK: --version ajouté (safe)"
}

# ------------------------------------------------------------
# 6) Guard init : sauter init BackupCore/DB/logs si help/version
# ------------------------------------------------------------
$guardBegin = "# BEGIN ABP_INIT_GUARD_HELP_VERSION"
$guardEnd   = "# END ABP_INIT_GUARD_HELP_VERSION"
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
    $indentG + $guardBegin,
    $indentG + "if ABP_QUIET_BOOT:",
    $indentG + "    core = None",
    $indentG + "    backup_core_module = None",
    $indentG + "else:",
    $initIndented,
    $indentG + $guardEnd,
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$lineStart) + $wrapper + $raw.Substring($end)
  Write-Host "[PATCH] OK: init guard help/version ajouté"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: altiora.py prêt (reset+footer removed+help/version quiet+--version ok)"
