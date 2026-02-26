$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

function Remove-BlockByMarkers([string]$text, [string]$begin, [string]$end){
  $b = $text.IndexOf($begin)
  if($b -lt 0){ return $text }
  $e = $text.IndexOf($end, $b)
  if($e -lt 0){ throw "End marker introuvable pour bloc: $begin" }
  $after = $text.IndexOf("`n", $e)
  if($after -lt 0){ $after = $e + $end.Length } else { $after = $after + 1 }
  return ($text.Substring(0,$b) + $text.Substring($after))
}

# 0) Nettoyage des blocs injectés précédemment (idempotent)
$raw = Remove-BlockByMarkers $raw "# BEGIN ABP_QUIET_BOOT" "# END ABP_QUIET_BOOT"
$raw = Remove-BlockByMarkers $raw "# BEGIN ABP_VERSION_STR" "# END ABP_VERSION_STR"
$raw = Remove-BlockByMarkers $raw "# BEGIN ABP_INIT_GUARD_HELP_VERSION" "# END ABP_INIT_GUARD_HELP_VERSION"

# 0b) Retirer toute ligne "action='version'" / "action="version"" (on ne tente pas de réparer: on supprime)
$lines0 = $raw.Split("`n")
$lines1 = New-Object System.Collections.Generic.List[string]
foreach($ln in $lines0){
  if($ln -match "action\s*=\s*['""]version['""]"){ continue }
  $lines1.Add($ln)
}
$raw = ($lines1.ToArray() -join "`n")

# 1) Ajouter ABP_QUIET_BOOT (après import argparse si possible)
$qbBegin = "# BEGIN ABP_QUIET_BOOT"
$qbEnd   = "# END ABP_QUIET_BOOT"
$ins = $raw.IndexOf("import argparse")
$insertAt = 0
if($ins -ge 0){
  $le = $raw.IndexOf("`n",$ins)
  if($le -ge 0){ $insertAt = $le + 1 }
}
$qb = @(
  $qbBegin,
  "import sys as _sys",
  "ABP_QUIET_BOOT = any(a in _sys.argv[1:] for a in ('-h','--help','--version'))",
  $qbEnd,
  ""
) -join "`n"
$raw = $raw.Substring(0,$insertAt) + $qb + $raw.Substring($insertAt)

# 2) Ajouter ABP_VERSION_STR (avant création du parser)
$verBegin = "# BEGIN ABP_VERSION_STR"
$verEnd   = "# END ABP_VERSION_STR"
$needleParser = "parser = argparse.ArgumentParser"
$p = $raw.IndexOf($needleParser)
if($p -lt 0){ throw "Ligne parser = argparse.ArgumentParser introuvable" }

$ls = $raw.LastIndexOf("`n",$p)
if($ls -lt 0){ $ls = 0 } else { $ls = $ls + 1 }
$indent = ([regex]::Match($raw.Substring($ls, $p-$ls), "^\s*")).Value

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

# 3) Insérer parser.add_argument("--version"... ) APRÈS la fermeture du call ArgumentParser(...)
#    On calcule la parenthèse fermante correspondante pour ne jamais casser la syntaxe.
$p = $raw.IndexOf($needleParser)
if($p -lt 0){ throw "parser = argparse.ArgumentParser introuvable (après insertion version)" }

# trouver l'ouverture "(" du call
$open = $raw.IndexOf("(", $p)
if($open -lt 0){ throw "Parenthèse ouvrante du ArgumentParser(...) introuvable" }

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
if($close -lt 0){ throw "Parenthèse fermante du ArgumentParser(...) introuvable (depth != 0)" }

# insertion après la fin de ligne qui contient la parenthèse fermante
$eol = $raw.IndexOf("`n", $close)
if($eol -lt 0){ $eol = $close + 1 } else { $eol = $eol + 1 }

$addVer = @(
  $indent + "# BEGIN ABP_ADD_VERSION_ARG",
  $indent + "parser.add_argument(",
  $indent + "    ""--version"",",
  $indent + "    action=""version"",",
  $indent + "    version=__ABP_VERSION_STR",
  $indent + ")",
  $indent + "# END ABP_ADD_VERSION_ARG",
  ""
) -join "`n"

$raw = $raw.Substring(0,$eol) + $addVer + $raw.Substring($eol)

# 4) Guard init : wrap du bloc init (mêmes markers que précédemment, mais sans toucher au reste)
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
  throw "Impossible de localiser le bloc d'initialisation (markers introuvables)."
}

$lineStart = $raw.LastIndexOf("`n",$start)
if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

$initBlock = $raw.Substring($lineStart, $end - $lineStart)
$firstLineEnd = $initBlock.IndexOf("`n")
$firstLine = $initBlock
if($firstLineEnd -ge 0){ $firstLine = $initBlock.Substring(0,$firstLineEnd) }
$indent2 = ([regex]::Match($firstLine, "^\s*")).Value

$initLines = $initBlock.Split("`n")
$initIndented = ($initLines | ForEach-Object { $indent2 + "    " + $_ }) -join "`n"

$wrapper = @(
  $indent2 + "# BEGIN ABP_INIT_GUARD_HELP_VERSION",
  $indent2 + "if ABP_QUIET_BOOT:",
  $indent2 + "    core = None",
  $indent2 + "    backup_core_module = None",
  $indent2 + "else:",
  $initIndented,
  $indent2 + "# END ABP_INIT_GUARD_HELP_VERSION",
  ""
) -join "`n"

$raw = $raw.Substring(0,$lineStart) + $wrapper + $raw.Substring($end)

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: --version réparé (safe) + init silencieuse help/version + nettoyage v1"
