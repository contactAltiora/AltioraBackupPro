$ErrorActionPreference = "Stop"

Write-Host "=== Robustness / edge cases ==="

$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Repo root introuvable" }
Set-Location $repoRoot
Write-Host "Repo root: $(Get-Location)"

$PY = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $PY)) { $PY = "python" }

if (-not (Test-Path ".\altiora.py")) { throw "altiora.py introuvable" }

$work = Join-Path $env:TEMP ("altiora_edge_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$out = Join-Path $work "out"
New-Item -ItemType Directory -Path $out | Out-Null

$plain = Join-Path $work "file.txt"
$bk    = Join-Path $work "backup.altb"
"SECRET DATA 123" | Set-Content -Encoding UTF8 $plain

$good = "GOODPASS-123!"
$bad  = "BADPASS-123!"

# 1) Backup ok
& $PY .\altiora.py backup $plain $bk -p $good | Out-Null
if ($LASTEXITCODE -ne 0) { throw "backup devrait réussir" }

# 2) Verify mauvais mdp -> doit échouer
& $PY .\altiora.py verify $bk -p $bad | Out-Null
if ($LASTEXITCODE -eq 0) { throw "verify ne doit PAS réussir avec mauvais mot de passe" }
Write-Host "✅ mauvais mot de passe rejeté"

# 3) Verify fichier inexistant -> doit échouer
$missing = Join-Path $work "missing.altb"
& $PY .\altiora.py verify $missing -p $good | Out-Null
if ($LASTEXITCODE -eq 0) { throw "verify ne doit PAS réussir sur fichier inexistant" }
Write-Host "✅ fichier inexistant géré"

# 4) Restore -> ok
& $PY .\altiora.py restore $bk $out -p $good --force | Out-Null
if ($LASTEXITCODE -ne 0) { throw "restore devrait réussir" }
Write-Host "✅ restore OK"

# 5) Appel incomplet -> doit échouer (backup sans args)
& $PY .\altiora.py backup -p $good 2>$null
if ($LASTEXITCODE -eq 0) { throw "backup sans args ne doit PAS réussir" }
Write-Host "✅ args manquants: échec attendu"

Write-Host "✅ EDGE CASES OK"
