$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "altiora.py vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

# -------------------------------------------------------------------
# 1) Ajouter ABP_QUIET_BOOT (idempotent)
# -------------------------------------------------------------------
$qbBegin = "# BEGIN ABP_QUIET_BOOT"
$qbEnd   = "# END ABP_QUIET_BOOT"

if($raw.IndexOf($qbBegin) -lt 0){
  # inject après "import argparse" si trouvé, sinon en haut du fichier
  $ins = $raw.IndexOf("import argparse")
  $insertAt = 0
  if($ins -ge 0){
    $le = $raw.IndexOf("`n",$ins)
    if($le -ge 0){ $insertAt = $le + 1 }
  }

  $block = @(
    $qbBegin,
    "import sys as _sys",
    "ABP_QUIET_BOOT = any(a in _sys.argv[1:] for a in ('-h','--help','--version'))",
    $qbEnd,
    ""
  ) -join "`n"

  $raw = $raw.Substring(0,$insertAt) + $block + $raw.Substring($insertAt)
}

# -------------------------------------------------------------------
# 2) Fix --version (action='version' doit avoir version=...)
# -------------------------------------------------------------------
# stratégie: trouver la ligne add_argument(... '--version' ...) et ajouter version=...
$lines = $raw.Split("`n")
$changedVersion = $false

# version string python: utiliser __version__ si existant, sinon 'unknown'
$verStr = 'Altiora Backup Pro v' + '${__version__}'  # string python; si __version__ absent => NameError ? donc on sécurise après.
# On injecte une variable sûre juste avant la création du parser.
$verVarBegin = "# BEGIN ABP_VERSION_STR"
$verVarEnd   = "# END ABP_VERSION_STR"

if($raw.IndexOf($verVarBegin) -lt 0){
  # insérer avant "parser = argparse.ArgumentParser(" si trouvé
  $needleParser = "parser = argparse.ArgumentParser"
  $p = $raw.IndexOf($needleParser)
  if($p -ge 0){
    $ls = $raw.LastIndexOf("`n",$p)
    if($ls -lt 0){ $ls = 0 } else { $ls = $ls + 1 }

    $indent = ""
    $pre = $raw.Substring($ls, $p - $ls)
    # récupérer indentation de la ligne parser= (espaces avant 'parser')
    $m = [regex]::Match($pre, "^\s*")
    if($m.Success){ $indent = $m.Value }

    $verBlock = @(
      $indent + $verVarBegin,
      $indent + "try:",
      $indent + "    __ABP_VERSION_STR = f""Altiora Backup Pro v{__version__}""",
      $indent + "except Exception:",
      $indent + "    __ABP_VERSION_STR = ""Altiora Backup Pro""",
      $indent + $verVarEnd,
      ""
    ) -join "`n"

    $raw = $raw.Substring(0,$ls) + $verBlock + $raw.Substring($ls)
    $lines = $raw.Split("`n")  # refresh
  }
}

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  if($ln -match "add_argument\((.*--version|.*'--version'|.*""--version"")"){
    if($ln -match "action\s*=\s*['""]version['""]" -and ($ln -notmatch "version\s*=")){
      # ajout version=__ABP_VERSION_STR avant la parenthèse fermante
      # (safe: on ajoute juste avant le dernier ')')
      $idx = $ln.LastIndexOf(")")
      if($idx -gt 0){
        $before = $ln.Substring(0,$idx)
        $after  = $ln.Substring($idx)
        $lines[$i] = $before + ", version=__ABP_VERSION_STR" + $after
        $changedVersion = $true
      }
    }
  }
}

$raw = ($lines -join "`n")

if(-not $changedVersion){
  # si aucune ligne trouvée/réparée, on ne fail pas: on laisse l'état actuel
  # mais on peut quand même sécuriser en ajoutant un --version simple au parent parser
  # (seulement si on voit déjà --verbose/--json, pour éviter de doubler)
  if($raw -notmatch "--version"){
    # insérer juste après la définition du parent parser si trouvée
    $needleParent = "parent = argparse.ArgumentParser"
    $p2 = $raw.IndexOf($needleParent)
    if($p2 -ge 0){
      $le2 = $raw.IndexOf("`n",$p2)
      if($le2 -ge 0){
        $indent = ""
        $line = $raw.Substring($p2, $le2 - $p2)
        $m2 = [regex]::Match($line, "^\s*")
        if($m2.Success){ $indent = $m2.Value }

        $ins2 = $le2 + 1
        $add = @(
          $indent + "parent.add_argument(",
          $indent + "    ""--version"",",
          $indent + "    action=""version"",",
          $indent + "    version=__ABP_VERSION_STR",
          $indent + ")",
          ""
        ) -join "`n"

        $raw = $raw.Substring(0,$ins2) + $add + $raw.Substring($ins2)
      }
    }
  }
}

# -------------------------------------------------------------------
# 3) Court-circuiter l'init BackupCore/DB/logs si help/version
#    On wrap le bloc qui commence par _safe_print("🚀 Initialisation du système...")
#    et se termine juste avant "parent = argparse.ArgumentParser(add_help=False)"
# -------------------------------------------------------------------
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

# Remonter au début de ligne du bloc init
$lineStart = $raw.LastIndexOf("`n",$start)
if($lineStart -lt 0){ $lineStart = 0 } else { $lineStart = $lineStart + 1 }

$initBlock = $raw.Substring($lineStart, $end - $lineStart)

# indent du bloc
$firstLineEnd = $initBlock.IndexOf("`n")
$firstLine = $initBlock
if($firstLineEnd -ge 0){ $firstLine = $initBlock.Substring(0,$firstLineEnd) }
$indent = ([regex]::Match($firstLine, "^\s*")).Value

# indenter le contenu existant sous le else:
$initLines = $initBlock.Split("`n")
$initIndented = ($initLines | ForEach-Object { $indent + "    " + $_ }) -join "`n"

$wrapper = @(
  $indent + "# BEGIN ABP_INIT_GUARD_HELP_VERSION",
  $indent + "if ABP_QUIET_BOOT:",
  $indent + "    core = None",
  $indent + "    backup_core_module = None",
  $indent + "else:",
  $initIndented,
  $indent + "# END ABP_INIT_GUARD_HELP_VERSION",
  ""
) -join "`n"

$raw2 = $raw.Substring(0,$lineStart) + $wrapper + $raw.Substring($end)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: --version fixé + init silencieuse pour help/version"
