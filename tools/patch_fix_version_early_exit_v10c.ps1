$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "v10c: exécuter depuis $rootExpected (actuel: $root)"
}

$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "v10c: altiora.py introuvable: $target" }

function Fail($msg){ throw "v10c: $msg" }

Write-Host "[PATCH] v10c: reset altiora.py depuis Git..."
& git checkout -- altiora.py | Out-Null
if($LASTEXITCODE -ne 0){ Fail "git checkout a échoué (code $LASTEXITCODE)" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# --- Guardrails: VERSION_STR doit exister (créé par v10b) ---
if($raw -notmatch "(?m)^\s*VERSION_STR\s*="){
  Fail "VERSION_STR introuvable. Applique d'abord v10b."
}

# --- Insérer un early-exit NON-JSON pour --version/-V avant toute bannière/init ---
# On place juste après le bloc JSON early (après le SystemExit(0) du JSON),
# ou à défaut juste après ABP_JSON_MODE_EARLY block.
# Stratégie: ancre sur la ligne "import time" (qui est après ton JSON early dans l'extrait).
$anchor = "(?m)^\s*import\s+time\s*$"
$mA = [regex]::Match($raw, $anchor)
if(!$mA.Success){ Fail "ancre 'import time' introuvable (pattern inattendu)" }

$snippet = @(
  ""
  "# ABP_EARLY_VERSION_V10C: --version/-V without banner/init (non-JSON)"
  "if (('--version' in sys.argv) or ('-V' in sys.argv)) and ('--json' not in sys.argv):"
  "    sys.stdout.write(VERSION_STR + ""\n"")"
  "    raise SystemExit(0)"
  ""
) -join "`n"

# Idempotence: si déjà présent, ne rien faire
if($raw -match "ABP_EARLY_VERSION_V10C"){
  Write-Host "[PATCH] v10c: snippet déjà présent (ok)"
} else {
  $raw = $raw.Substring(0, $mA.Index) + $snippet + $raw.Substring($mA.Index)
  Write-Host "[PATCH] v10c: early-exit --version/-V ajouté"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] v10c: OK"