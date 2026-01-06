$ErrorActionPreference = "Stop"

Write-Host "=== Security tamper test (AAD / integrity) ==="

# --- Auto-detect repo root (console + CI) ---
$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Impossible de détecter la racine git (repoRoot vide)" }
Set-Location $repoRoot
Write-Host "Repo root: $(Get-Location)"

# Python du venv si dispo, sinon python système
$PY = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $PY)) { $PY = "python" }

# Pré-requis
if (-not (Test-Path ".\altiora.py")) { throw "altiora.py introuvable (lance ce script depuis la racine du repo)" }

# Workspace
$work = Join-Path $env:TEMP ("altiora_sec_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

$plain = Join-Path $work "file.txt"
$bk    = Join-Path $work "backup.altb"
$out   = Join-Path $work "out"
New-Item -ItemType Directory -Path $out | Out-Null

"SECRET DATA 123" | Set-Content -Encoding UTF8 $plain
$pwd = "Tr3sF0rt!P@ssw0rd#2025"

# 1) backup OK
& $PY .\altiora.py backup $plain $bk -p $pwd | Out-Null
if ($LASTEXITCODE -ne 0) { throw "backup a échoué (exitcode=$LASTEXITCODE)" }

# 2) verify OK (avant tamper)
& $PY .\altiora.py verify $bk -p $pwd | Out-Null
if ($LASTEXITCODE -ne 0) { throw "verify a échoué avant tamper (exitcode=$LASTEXITCODE)" }

# 3) tamper: flip 1 byte au milieu
[byte[]]$bytes = [System.IO.File]::ReadAllBytes($bk)
if ($bytes.Length -lt 200) { throw "Backup trop petit pour test tamper (len=$($bytes.Length))" }

$idx = [int]([Math]::Floor($bytes.Length / 2))
$bytes[$idx] = $bytes[$idx] -bxor 0x01
[System.IO.File]::WriteAllBytes($bk, $bytes)

# 4) verify doit échouer
& $PY .\altiora.py verify $bk -p $pwd | Out-Null
if ($LASTEXITCODE -eq 0) { throw "❌ ECHEC: verify a réussi alors que le fichier a été modifié" }

Write-Host "✅ Tamper detected: verify failed as expected"
