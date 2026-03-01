$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_enforce_free_backup_limit_1gb_v1: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_enforce_free_backup_limit_1gb_v1: $m" }

$target = Join-Path $root "src\backup_core.py"
if(!(Test-Path $target)){ Fail "introuvable: $target" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# ------------------------------------------------------------
# (A) Ajouter la constante FREE_BACKUP_LIMIT_BYTES (idempotent)
# ------------------------------------------------------------
if($raw -notmatch "(?m)^\s*FREE_BACKUP_LIMIT_BYTES\s*="){

  # On l'insère juste après FREE_RESTORE_LIMIT_BYTES (ancre stable)
  $anchor = "(?m)^\s*FREE_RESTORE_LIMIT_BYTES\s*=\s*.*$"
  $mA = [regex]::Match($raw, $anchor)
  if(!$mA.Success){
    Fail "ancre FREE_RESTORE_LIMIT_BYTES introuvable (impossible d'insérer FREE_BACKUP_LIMIT_BYTES)"
  }

  $insert = @(
    ""
    "# FREE: limitation BACKUP (taille logique des données en clair)"
    "FREE_BACKUP_LIMIT_BYTES = 1024 * 1024 * 1024  # 1 GiB (Free backup limit)"
    ""
  ) -join "`n"

  $pos = $mA.Index + $mA.Length
  $raw = $raw.Substring(0, $pos) + $insert + $raw.Substring($pos)
  Write-Host "[PATCH] OK: FREE_BACKUP_LIMIT_BYTES ajouté"
} else {
  Write-Host "[PATCH] OK: FREE_BACKUP_LIMIT_BYTES déjà présent (skip)"
}

# ------------------------------------------------------------
# (B) Appliquer la règle dans le flux BACKUP (idempotent)
# ------------------------------------------------------------
# On cherche l'endroit juste après la boucle de calcul total_size / manifest,
# via un pattern précis: "total_size = 0" puis "for p in files_to_backup:"
# puis "total_size +=".
# Ensuite on insère un bloc de check immédiatement après la boucle,
# AVANT la construction de l'archive/chiffrement.
#
# Idempotence: si le marker est déjà là, skip.
if($raw -match "ABP_FREE_BACKUP_LIMIT_V1"){
  Write-Host "[PATCH] OK: règle FREE backup déjà présente (skip)"
} else {

  $rx = New-Object System.Text.RegularExpressions.Regex(
    "(?s)(?<block>total_size\s*=\s*0\s*\r?\n\s*for\s+p\s+in\s+files_to_backup\s*:\s*\r?\n.*?total_size\s*\+=\s*int\(st\.st_size\).*?\r?\n\s*except\s+Exception\s*:\s*\r?\n\s*continue\s*\r?\n)",
    [System.Text.RegularExpressions.RegexOptions]::None
  )

  $mB = $rx.Match($raw)
  if(!$mB.Success){
    Fail "bloc calcul total_size introuvable (pattern inattendu)."
  }

  $block = $mB.Groups["block"].Value

  # Trouver l'indentation du niveau courant (celle de 'total_size = 0')
  $firstLine = ($block -split "`r?`n")[0]
  $indent = ([regex]::Match($firstLine, "^\s*")).Value

  $check = @(
    ""
    ($indent + "# ABP_FREE_BACKUP_LIMIT_V1: block backup > 1GiB in FREE (logical/plain size)")
    ($indent + "if EDITION == ""FREE"":")
    ($indent + "    try:")
    ($indent + "        if int(total_size) > int(FREE_BACKUP_LIMIT_BYTES):")
    ($indent + "            total_gb = float(total_size) / (1024.0 * 1024.0 * 1024.0)")
    ($indent + "            limit_gb = float(FREE_BACKUP_LIMIT_BYTES) / (1024.0 * 1024.0 * 1024.0)")
    ($indent + "            print(""\n❌ BACKUP BLOQUÉ — Altiora Backup Free"")")
    ($indent + "            print(f""   Taille à sauvegarder : {total_gb:.2f} Go"")")
    ($indent + "            print(f""   Limite Free          : {limit_gb:.2f} Go\n"")")
    ($indent + "            print(""👉 Passez à Altiora Backup Pro pour sauvegarder sans limite."")")
    ($indent + "            self.last_error_code = ""FREE_LIMIT_BACKUP""")
    ($indent + "            self.last_exit_code = 102")
    ($indent + "            return False")
    ($indent + "    except Exception:")
    ($indent + "        # en cas d'erreur de calcul, on bloque en FREE par sécurité")
    ($indent + "        print(""\n❌ BACKUP BLOQUÉ — Altiora Backup Free (erreur taille)"")")
    ($indent + "        print(""👉 Passez à Altiora Backup Pro pour sauvegarder sans limite."")")
    ($indent + "        self.last_error_code = ""FREE_LIMIT_BACKUP_ERROR""")
    ($indent + "        self.last_exit_code = 102")
    ($indent + "        return False")
    ""
  ) -join "`n"

  # Insérer juste après le bloc de calcul (après le "continue" final de la boucle)
  $insertPos = $mB.Index + $mB.Length
  $raw = $raw.Substring(0, $insertPos) + $check + $raw.Substring($insertPos)

  Write-Host "[PATCH] OK: règle FREE backup (1GiB) insérée après calcul total_size"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: src\backup_core.py écrit (UTF-8)"