$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "v10c2: exécuter depuis $rootExpected (actuel: $root)"
}

$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "v10c2: altiora.py introuvable: $target" }

function Fail($msg){ throw "v10c2: $msg" }

Write-Host "[PATCH] v10c2: reset altiora.py depuis Git..."
& git checkout -- altiora.py | Out-Null
if($LASTEXITCODE -ne 0){ Fail "git checkout a échoué (code $LASTEXITCODE)" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# --- Déduire la version courante (prend la 1ère occurrence "Altiora Backup Pro vX.Y.Z") ---
$rxV = [regex]'Altiora Backup Pro v\d+\.\d+\.\d+'
$mV  = $rxV.Match($raw)
if(!$mV.Success){ Fail "impossible de déduire 'Altiora Backup Pro vX.Y.Z' dans altiora.py" }
$verStr = $mV.Value

# --- Injecter VERSION_STR juste AVANT ABP_JSON_MODE_EARLY (idempotent) ---
if($raw -notmatch "(?m)^\s*VERSION_STR\s*="){
  $anchor = "(?m)^\s*ABP_JSON_MODE_EARLY\s*="
  $mA = [regex]::Match($raw, $anchor)
  if(!$mA.Success){ Fail "ancre ABP_JSON_MODE_EARLY introuvable pour insérer VERSION_STR" }

  $insert = @(
    ""
    "# Altiora Backup Pro - single source of truth for CLI version"
    "VERSION_STR = ""$verStr"""
    ""
  ) -join "`n"

  $raw = $raw.Substring(0, $mA.Index) + $insert + $raw.Substring($mA.Index)
  Write-Host "[PATCH] v10c2: VERSION_STR ajouté ($verStr)"
} else {
  Write-Host "[PATCH] v10c2: VERSION_STR déjà présent (ok)"
}

# --- Patch JSON early: remplacer la version hardcodée par VERSION_STR (idempotent) ---
# cible: sys.stdout.write('{"ok": true, "version": "Altiora Backup Pro v1.0.12"}\n')
$raw = [regex]::Replace(
  $raw,
  "(?m)^(?<indent>\s*)sys\.stdout\.write\('{\\""ok\\"":\s*true,\s*\\""version\\"":\s*\\""Altiora Backup Pro v\d+\.\d+\.\d+\\""}\\n'\)\s*$",
  '${indent}sys.stdout.write(''{"ok": true, "version": "'' + VERSION_STR + ''"}\n'')',
  1
)

if($raw -match "(?m)^\s*sys\.stdout\.write\('{\\""ok\\"":\s*true,\s*\\""version\\"":\s*\\""Altiora Backup Pro v\d+\.\d+\.\d+\\""}\\n'\)\s*$"){
  Fail "JSON early encore hardcodé après patch (pattern inattendu)."
}
Write-Host "[PATCH] v10c2: JSON early OK"

# --- Patch argparse: ajouter -V et version=VERSION_STR (format multi-ligne connu) ---
$lines = $raw -split "`n"
$changedV = $false
$changedAlias = $false

for($i=0; $i -lt $lines.Length; $i++){
  if(($i+3) -lt $lines.Length){
    if($lines[$i] -match "^\s*parent\.add_argument\(\s*$" -and
       $lines[$i+1] -match '^\s*["'']--version["'']\s*,\s*$' -and
       $lines[$i+2] -match '^\s*action\s*=\s*["'']version["'']\s*,\s*$' -and
       $lines[$i+3] -match '^\s*version\s*=\s*["'']Altiora Backup Pro v\d+\.\d+\.\d+["'']\s*$'
    ){
      $lines[$i+1] = ($lines[$i+1] -replace '(["'']--version["''])\s*,\s*$', '$1, "-V",')
      $changedAlias = $true

      $indent = ([regex]::Match($lines[$i+3], '^\s*')).Value
      $lines[$i+3] = $indent + "version=VERSION_STR"
      $changedV = $true
      break
    }
  }
}
if(!$changedAlias -or !$changedV){
  Fail "bloc argparse parent.add_argument(--version...) non trouvé au format attendu."
}
Write-Host "[PATCH] v10c2: argparse --version OK (VERSION_STR + -V)"

$raw = ($lines -join "`n")

# --- Early-exit non-JSON pour --version/-V avant bannière/init ---
# On place juste avant "import time" (position stable dans ton fichier)
if($raw -match "ABP_EARLY_VERSION_V10C2"){
  Write-Host "[PATCH] v10c2: early-exit déjà présent (ok)"
} else {
  $anchor2 = "(?m)^\s*import\s+time\s*$"
  $mT = [regex]::Match($raw, $anchor2)
  if(!$mT.Success){ Fail "ancre 'import time' introuvable pour insérer early-exit" }

  $snippet = @(
    ""
    "# ABP_EARLY_VERSION_V10C2: --version/-V without banner/init (non-JSON)"
    "if (('--version' in sys.argv) or ('-V' in sys.argv)) and ('--json' not in sys.argv):"
    "    sys.stdout.write(VERSION_STR + ""\n"")"
    "    raise SystemExit(0)"
    ""
  ) -join "`n"

  $raw = $raw.Substring(0, $mT.Index) + $snippet + $raw.Substring($mT.Index)
  Write-Host "[PATCH] v10c2: early-exit --version/-V ajouté"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] v10c2: OK"