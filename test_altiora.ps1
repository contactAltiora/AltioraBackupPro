# ============================
# ALTIORA BACKUP PRO - TEST SUITE (ROBUSTE) — Windows "py" launcher
# ============================
$ErrorActionPreference = "Stop"

function Run-Py([string]$Title, [string[]]$PyArgs, [int]$ExpectedExitCode = -1) {
  Write-Host ""
  Write-Host "============================"
  Write-Host $Title
  Write-Host "============================"

  # IMPORTANT: on envoie toute la sortie vers l'écran,
  # sinon PowerShell "capture" et le retour devient System.Object[]
  & py -3 @PyArgs 2>&1 | Out-Host

  $code = $LASTEXITCODE
  Write-Host ("ExitCode: {0}" -f $code)

  if ($ExpectedExitCode -ge 0 -and $code -ne $ExpectedExitCode) {
    throw ("[ECHEC] {0} (attendu={1} / obtenu={2})" -f $Title, $ExpectedExitCode, $code)
  } else {
    Write-Host ("[OK] {0}" -f $Title)
  }

  return [int]$code
}

# --- Config ---
$Root = "C:\Users\guymo"
Set-Location $Root

$Altiora = Join-Path $Root "altiora.py"
$PasswordGood = "Tr3sF0rt!P@ssw0rd#2025"
$PasswordBad  = "MAUVAIS_MDP"

$PlainFile = Join-Path $Root "fichier_sensible.txt"
$BackupReal = Join-Path $Root "backup_reel.altb"
$BackupCorrupt = Join-Path $Root "backup_corrompu.altb"
$RestoreDir = Join-Path $Root "restored"

if (!(Test-Path $Altiora)) { throw "altiora.py introuvable: $Altiora" }

Write-Host "CWD=$((Get-Location).Path)"

# 1) Nettoyage __pycache__
Get-ChildItem $Root -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 2) Preflight: chemin réel de src.backup_core
Run-Py "Preflight: import src.backup_core" @("-c", "import os; import src.backup_core as m; print('CWD=',os.getcwd()); print('backup_core=',m.__file__)") 0

# 3) --help doit renvoyer 0
Run-Py "CLI --help (attendu 0)" @($Altiora, "--help") 0

# 4) Préparation fichiers
"SECRET DATA 123" | Set-Content -Encoding UTF8 $PlainFile
Remove-Item $BackupReal -ErrorAction SilentlyContinue
Remove-Item $BackupCorrupt -ErrorAction SilentlyContinue
Remove-Item $RestoreDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $RestoreDir | Out-Null

# 5) Backup (0)
Run-Py "BACKUP (attendu 0)" @($Altiora, "backup", $PlainFile, $BackupReal, "-p", $PasswordGood) 0
if (!(Test-Path $BackupReal)) { throw "[ECHEC] backup_reel.altb non créé" }

# 6) Verify OK (0)
Run-Py "VERIFY OK (attendu 0)" @($Altiora, "verify", $BackupReal, "-p", $PasswordGood) 0

# 7) Verify KO mauvais mdp (1)
Run-Py "VERIFY KO mauvais mdp (attendu 1)" @($Altiora, "verify", $BackupReal, "-p", $PasswordBad) 1

# 8) Corruption (flip 1 byte)
Copy-Item $BackupReal $BackupCorrupt -Force
$fs = [System.IO.File]::Open($BackupCorrupt, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
try {
  $pos = [Math]::Max(0, $fs.Length - 17)
  $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
  $b = $fs.ReadByte()
  $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
  $fs.WriteByte($b -bxor 0xFF)
} finally { $fs.Close() }

# 9) Verify KO corrompu (1)
Run-Py "VERIFY KO corrompu (attendu 1)" @($Altiora, "verify", $BackupCorrupt, "-p", $PasswordGood) 1

# 10) Restore OK (0)
Run-Py "RESTORE OK (attendu 0)" @($Altiora, "restore", $BackupReal, $RestoreDir, "-p", $PasswordGood, "--force") 0

# 11) Vérifier contenu restauré
$restoredFile = Join-Path $RestoreDir "fichier_sensible.txt"
if (!(Test-Path $restoredFile)) { throw "[ECHEC] Fichier restauré introuvable: $restoredFile" }
$content = Get-Content $restoredFile -Raw
Write-Host ("Contenu restauré: {0}" -f $content)
if ($content -notmatch "SECRET DATA 123") { throw "[ECHEC] Contenu restauré différent" }

Write-Host ""
Write-Host "✅✅✅ TESTS OK — backup/verify/restore + codes retour cohérents ✅✅✅"
