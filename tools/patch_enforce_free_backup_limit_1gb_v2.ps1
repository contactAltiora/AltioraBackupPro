$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_enforce_free_backup_limit_1gb_v2: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_enforce_free_backup_limit_1gb_v2: $m" }

$target = Join-Path $root "src\backup_core.py"
if(!(Test-Path $target)){ Fail "introuvable: $target" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# ------------------------------------------------------------
# (A) Ajouter la constante FREE_BACKUP_LIMIT_BYTES (idempotent)
# ------------------------------------------------------------
if($raw -notmatch "(?m)^\s*FREE_BACKUP_LIMIT_BYTES\s*="){

  $anchor = "(?m)^\s*FREE_RESTORE_LIMIT_BYTES\s*=\s*.*$"
  $mA = [regex]::Match($raw, $anchor)
  if(!$mA.Success){
    Fail "ancre FREE_RESTORE_LIMIT_BYTES introuvable (impossible d'insérer FREE_BACKUP_LIMIT_BYTES)"
  }

  $insert = @"
# FREE: limitation BACKUP (taille logique des données en clair)
FREE_BACKUP_LIMIT_BYTES = 1024 * 1024 * 1024  # 1 GiB (Free backup limit)

"@

  $pos = $mA.Index + $mA.Length
  $raw = $raw.Substring(0, $pos) + "`n" + $insert + $raw.Substring($pos)
  Write-Host "[PATCH] OK: FREE_BACKUP_LIMIT_BYTES ajouté"
} else {
  Write-Host "[PATCH] OK: FREE_BACKUP_LIMIT_BYTES déjà présent (skip)"
}

# ------------------------------------------------------------
# (B) Appliquer la règle dans le flux BACKUP (idempotent)
# ------------------------------------------------------------
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
  $firstLine = ($block -split "`r?`n")[0]
  $indent = ([regex]::Match($firstLine, "^\s*")).Value

  $checkTemplate = @'
__INDENT__# ABP_FREE_BACKUP_LIMIT_V1: block backup > 1GiB in FREE (logical/plain size)
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
__INDENT__        # en cas d'erreur de calcul, on bloque en FREE par sécurité
__INDENT__        print("\n❌ BACKUP BLOQUÉ — Altiora Backup Free (erreur taille)")
__INDENT__        print("👉 Passez à Altiora Backup Pro pour sauvegarder sans limite.")
__INDENT__        self.last_error_code = "FREE_LIMIT_BACKUP_ERROR"
__INDENT__        self.last_exit_code = 102
__INDENT__        return False

'@

  $check = $checkTemplate.Replace("__INDENT__", $indent)

  $insertPos = $mB.Index + $mB.Length
  $raw = $raw.Substring(0, $insertPos) + "`n" + $check + $raw.Substring($insertPos)

  Write-Host "[PATCH] OK: règle FREE backup (1GiB) insérée après calcul total_size"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: src\backup_core.py écrit (UTF-8)"