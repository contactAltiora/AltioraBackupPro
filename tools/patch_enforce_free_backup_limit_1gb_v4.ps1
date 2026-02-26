$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_enforce_free_backup_limit_1gb_v4: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_enforce_free_backup_limit_1gb_v4: $m" }

$target = Join-Path $root "src\backup_core.py"
if(!(Test-Path $target)){ Fail "introuvable: $target" }

Write-Host "[PATCH] v4: reset src\backup_core.py depuis Git..."
& git checkout -- $target | Out-Null
if($LASTEXITCODE -ne 0){ Fail "git checkout a échoué (code $LASTEXITCODE)" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# ------------------------------------------------------------
# (A) Constante FREE_BACKUP_LIMIT_BYTES (idempotent)
# ------------------------------------------------------------
if($raw -notmatch "(?m)^\s*FREE_BACKUP_LIMIT_BYTES\s*="){

  $anchor = "(?m)^\s*FREE_RESTORE_LIMIT_BYTES\s*=\s*.*$"
  $mA = [regex]::Match($raw, $anchor)
  if(!$mA.Success){
    Fail "ancre FREE_RESTORE_LIMIT_BYTES introuvable (impossible d'insérer FREE_BACKUP_LIMIT_BYTES)"
  }

  $insert = @"
# FREE: limitation BACKUP (taille logique en clair)
FREE_BACKUP_LIMIT_BYTES = 1024 * 1024 * 1024  # 1 GiB (Free backup limit)

"@

  $pos = $mA.Index + $mA.Length
  $raw = $raw.Substring(0, $pos) + "`n" + $insert + $raw.Substring($pos)
  Write-Host "[PATCH] v4: OK FREE_BACKUP_LIMIT_BYTES ajouté"
} else {
  Write-Host "[PATCH] v4: OK FREE_BACKUP_LIMIT_BYTES déjà présent (skip)"
}

# ------------------------------------------------------------
# (B) Enforce limit: insertion juste AVANT la création tmp_archive
#     => évite totalement les zones try/except imbriquées
# ------------------------------------------------------------
if($raw -match "ABP_FREE_BACKUP_LIMIT_V4"){
  Write-Host "[PATCH] v4: règle déjà présente (skip)"
} else {

  # 1) trouver un "tmp_archive =" (variante: "tmp_archive =" ou "tmp_archive=")
  $rxTmp = [regex]::Match($raw, "(?m)^(?<indent>\s*)tmp_archive\s*=\s*.+$")
  if(!$rxTmp.Success){
    Fail "ligne tmp_archive = ... introuvable (pattern inattendu)."
  }

  $indent = $rxTmp.Groups["indent"].Value
  $idx    = $rxTmp.Index

  # garde-fou: on exige que total_size existe quelque part avant tmp_archive
  $pre = $raw.Substring(0, $idx)
  if($pre -notmatch "(?s)\btotal_size\s*="){
    Fail "total_size introuvable avant tmp_archive (inattendu)."
  }

  $block = @'
__INDENT__# ABP_FREE_BACKUP_LIMIT_V4: block backup > 1GiB in FREE (logical/plain size)
__INDENT__if EDITION == "FREE":
__INDENT__    try:
__INDENT__        if int(total_size) > int(FREE_BACKUP_LIMIT_BYTES):
__INDENT__            total_gb = float(total_size) / (1024.0 * 1024.0 * 1024.0)
__INDENT__            limit_gb = float(FREE_BACKUP_LIMIT_BYTES) / (1024.0 * 1024.0 * 1024.0)
__INDENT__            print("\n❌ BACKUP BLOQUÉ — Altiora Backup Free")
__INDENT__            print(f"   Taille à sauvegarder : {total_gb:.2f} Go")
__INDENT__            print(f"   Limite Free          : {limit_gb:.2f} Go\n")
__INDENT__            print("👉 Passez à Altiora Backup Pro pour sauvegarder sans limite.")
__INDENT__            self.last_error_code = "FREE_LIMIT_BACKUP"
__INDENT__            self.last_exit_code = 102
__INDENT__            return False
__INDENT__    except Exception:
__INDENT__        print("\n❌ BACKUP BLOQUÉ — Altiora Backup Free (erreur taille)")
__INDENT__        print("👉 Passez à Altiora Backup Pro pour sauvegarder sans limite.")
__INDENT__        self.last_error_code = "FREE_LIMIT_BACKUP_ERROR"
__INDENT__        self.last_exit_code = 102
__INDENT__        return False

'@

  $block = $block.Replace("__INDENT__", $indent)

  # insertion avant la ligne tmp_archive
  $raw = $raw.Substring(0, $idx) + $block + $raw.Substring($idx)

  if($raw -notmatch "ABP_FREE_BACKUP_LIMIT_V4"){
    Fail "insertion échouée (marker absent après insertion)."
  }

  Write-Host "[PATCH] v4: OK règle FREE backup insérée avant tmp_archive"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] v4: OK src\backup_core.py écrit (UTF-8)"