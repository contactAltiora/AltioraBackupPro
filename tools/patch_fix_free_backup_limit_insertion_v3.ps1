$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_fix_free_backup_limit_insertion_v3: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_fix_free_backup_limit_insertion_v3: $m" }

$target = Join-Path $root "src\backup_core.py"
if(!(Test-Path $target)){ Fail "introuvable: $target" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw

# ------------------------------------------------------------
# (A) Retirer le bloc existant (marker ABP_FREE_BACKUP_LIMIT_V1)
# ------------------------------------------------------------
$rxRemove = New-Object System.Text.RegularExpressions.Regex(
  "(?s)\r?\n[ \t]*# ABP_FREE_BACKUP_LIMIT_V1:.*?\r?\n[ \t]*if EDITION == ""FREE"":.*?\r?\n[ \t]*return False\r?\n",
  [System.Text.RegularExpressions.RegexOptions]::None
)

$before = $raw
$raw = $rxRemove.Replace($raw, "`n", 1)

if($before -ne $raw){
  Write-Host "[PATCH] OK: bloc ABP_FREE_BACKUP_LIMIT_V1 supprimé (1 occurrence)"
} else {
  Write-Host "[PATCH] OK: aucun bloc ABP_FREE_BACKUP_LIMIT_V1 à supprimer (skip)"
}

# ------------------------------------------------------------
# (B) Vérifier la constante (doit exister après v2)
# ------------------------------------------------------------
if($raw -notmatch "(?m)^\s*FREE_BACKUP_LIMIT_BYTES\s*="){
  Fail "FREE_BACKUP_LIMIT_BYTES introuvable. Applique d'abord le patch v2 (ou re-run v2)."
}

# ------------------------------------------------------------
# (C) Ré-insérer au bon endroit: après la boucle total_size, AVANT le try: suivant
# ------------------------------------------------------------
if($raw -match "ABP_FREE_BACKUP_LIMIT_V1"){
  Fail "le marker ABP_FREE_BACKUP_LIMIT_V1 est encore présent après suppression (inattendu)"
}

$rxSpot = New-Object System.Text.RegularExpressions.Regex(
  "(?s)(?<loop>total_size\s*=\s*0\s*\r?\n\s*for\s+p\s+in\s+files_to_backup\s*:\s*\r?\n.*?total_size\s*\+=\s*int\(st\.st_size\).*?\r?\n\s*except\s+Exception\s*:\s*\r?\n\s*continue\s*\r?\n)(?<ws>\s*)(?<try>\s*try\s*:\s*\r?\n)",
  [System.Text.RegularExpressions.RegexOptions]::None
)

$m = $rxSpot.Match($raw)
if(!$m.Success){
  Fail "point d'insertion introuvable (pattern loop+try inattendu)."
}

$loop = $m.Groups["loop"].Value
$ws   = $m.Groups["ws"].Value
$try  = $m.Groups["try"].Value

# indentation du niveau 'total_size = 0'
$firstLine = ($loop -split "`r?`n")[0]
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
__INDENT__        print("\n❌ BACKUP BLOQUÉ — Altiora Backup Free (erreur taille)")
__INDENT__        print("👉 Passez à Altiora Backup Pro pour sauvegarder sans limite.")
__INDENT__        self.last_error_code = "FREE_LIMIT_BACKUP_ERROR"
__INDENT__        self.last_exit_code = 102
__INDENT__        return False

'@

$check = $checkTemplate.Replace("__INDENT__", $indent)

# reconstruire le segment (loop + check + ws + try)
$replacement = $loop + "`n" + $check + $ws + $try

$raw = $rxSpot.Replace($raw, [System.Text.RegularExpressions.MatchEvaluator]{
  param($mm) $replacement
}, 1)

if($raw -notmatch "ABP_FREE_BACKUP_LIMIT_V1"){
  Fail "insertion échouée: marker absent après remplacement"
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: règle FREE backup ré-insérée (avant try:)"
Write-Host "[PATCH] OK: src\backup_core.py écrit (UTF-8)"