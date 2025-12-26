# ============================
# ALTIORA BACKUP PRO - STABILITY TEST (CLEAN)
# ============================
$ErrorActionPreference = "Stop"

function Assert-True($Cond, $Msg) {
  if (-not $Cond) { throw "[ECHEC] $Msg" }
  Write-Host "[OK] $Msg"
}

# Python runner (non-interactif + exitcode fiable)
function Run-Py($Title, [string[]]$PyArgs, [int]$ExpectedExitCode = 0) {
  Write-Host ""
  Write-Host "============================"
  Write-Host $Title
  Write-Host "============================"

  # évite l'interactif si PyArgs est vide
  if ($null -eq $PyArgs -or $PyArgs.Count -eq 0) {
    $PyArgs = @("--version")
  }

  # IMPORTANT : reset exitcode avant appel externe
  $global:LASTEXITCODE = 0

  # exécute python + conserve stdout/stderr dans la console
  & $script:PyExe @PyArgs 2>&1 | ForEach-Object { $_ | Write-Host }

  $code = $global:LASTEXITCODE
  Write-Host ("ExitCode: {0}" -f $code)

  if ($code -ne $ExpectedExitCode) {
    throw ("[ECHEC] {0} (attendu={1} / obtenu={2})" -f $Title, $ExpectedExitCode, $code)
  }

  Write-Host ("[OK] {0}" -f $Title)
  return $code
}

# PowerShell runner (ne dépend pas de $LASTEXITCODE d'une commande précédente)
function Run-PS($Title, [scriptblock]$Block) {
  Write-Host ""
  Write-Host "============================"
  Write-Host $Title
  Write-Host "============================"

  $global:LASTEXITCODE = 0
  & $Block

  Write-Host "ExitCode: 0"
  Write-Host ("[OK] {0}" -f $Title)
  $global:LASTEXITCODE = 0
}

# --- Config ---
$Root = "C:\Users\guymo"
Set-Location $Root

$Altiora = Join-Path $Root "altiora.py"
Assert-True (Test-Path $Altiora) ("altiora.py présent: {0}" -f $Altiora)
Write-Host ("CWD={0}" -f (Get-Location).Path)

# Nettoyage __pycache__
Get-ChildItem $Root -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[OK] __pycache__ nettoyés"

# Python EXE réel (évite python.exe WindowsApps)
$script:PyExe = "C:\Users\guymo\AppData\Local\Programs\Python\Python311\python.exe"
Assert-True (Test-Path $script:PyExe) ("Python réel détecté: {0}" -f $script:PyExe)

# --- Variables test ---
$PasswordGood = "Tr3sF0rt!P@ssw0rd#2025"
$PasswordBad  = "MAUVAIS_MDP"

$PlainFile     = Join-Path $Root "fichier_sensible.txt"
$BackupReal    = Join-Path $Root "backup_reel.altb"
$BackupCorrupt = Join-Path $Root "backup_corrompu.altb"
$RestoreDir    = Join-Path $Root "restored"

# --- Preflight ---
Run-Py "Preflight: Python version" @("--version") 0
Run-Py "Preflight: import src.backup_core (chemin)" @("-c", "import os; import src.backup_core as m; print('CWD=',os.getcwd()); print('backup_core=',m.__file__)") 0
Run-Py "Preflight: CLI --help (attendu 0)" @($Altiora, "--help") 0
Run-Py "Preflight: CLI --help + --json (attendu 0)" @($Altiora, "--help", "--json") 0

# --- Stability: help x5 ---
for ($i=1; $i -le 5; $i++) {
  Run-Py ("Stability #{0}/5: CLI --help" -f $i) @($Altiora, "--help") 0
}

# --- Prep ---
Run-PS "Prep: fichiers + clean" {
  "SECRET DATA 123" | Set-Content -Encoding UTF8 $PlainFile
  Remove-Item $BackupReal -ErrorAction SilentlyContinue
  Remove-Item $BackupCorrupt -ErrorAction SilentlyContinue
  Remove-Item $RestoreDir -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path $RestoreDir | Out-Null
}

# --- Backup / Verify / Corrupt / Verify / Restore ---
Run-Py "BACKUP (attendu 0)" @($Altiora, "backup", $PlainFile, $BackupReal, "-p", $PasswordGood) 0
Assert-True (Test-Path $BackupReal) "backup_reel.altb créé"

Run-Py "VERIFY OK (attendu 0)" @($Altiora, "verify", $BackupReal, "-p", $PasswordGood) 0
Run-Py "VERIFY KO mauvais mdp (attendu 1)" @($Altiora, "verify", $BackupReal, "-p", $PasswordBad) 1

Run-PS "CORRUPTION: duplication + flip 1 byte" {
  Copy-Item $BackupReal $BackupCorrupt -Force
  $fs = [System.IO.File]::Open($BackupCorrupt, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
  try {
    $pos = [Math]::Max(0, $fs.Length - 17)
    $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
    $b = $fs.ReadByte()
    $fs.Seek($pos, [System.IO.SeekOrigin]::Begin) | Out-Null
    $fs.WriteByte($b -bxor 0xFF)
  } finally {
    $fs.Close()
  }
  Assert-True (Test-Path $BackupCorrupt) "backup_corrompu.altb créé"
}

Run-Py "VERIFY KO corrompu (attendu 1)" @($Altiora, "verify", $BackupCorrupt, "-p", $PasswordGood) 1
Run-Py "RESTORE OK (attendu 0)" @($Altiora, "restore", $BackupReal, $RestoreDir, "-p", $PasswordGood, "--force") 0

Run-PS "Check contenu restauré" {
  $restoredFile = Join-Path $RestoreDir "fichier_sensible.txt"
  Assert-True (Test-Path $restoredFile) ("Fichier restauré présent: {0}" -f $restoredFile)
  $content = Get-Content $restoredFile -Raw
  Write-Host ("Contenu restauré: {0}" -f $content)
  Assert-True ($content -match "SECRET DATA 123") "Contenu restauré identique"
}

Write-Host ""
Write-Host "✅✅✅ STABILITY OK — intégrité + répétitions + backup/verify/restore ✅✅✅"
