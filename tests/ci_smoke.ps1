$ErrorActionPreference = "Stop"

Write-Host "=== CI smoke test (Windows) ==="
Write-Host "PWD: $(Get-Location)"

# Python dispo ?
python --version

# Dépendances (si requirements.txt existe)
if (Test-Path ".\requirements.txt") {
  python -m pip install --upgrade pip
  pip install -r requirements.txt
}

# Vérifier que altiora.py existe
if (-not (Test-Path ".\altiora.py")) { throw "altiora.py introuvable" }

# Smoke: help doit marcher
python .\altiora.py --help

# Mini test backup/verify/restore dans un dossier temporaire
$work = Join-Path $env:TEMP ("altiora_ci_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

$plain = Join-Path $work "file.txt"
$bk    = Join-Path $work "backup.altb"
$out   = Join-Path $work "out"

"SECRET DATA 123" | Set-Content -Encoding UTF8 $plain
New-Item -ItemType Directory -Path $out | Out-Null

$pwd = "Tr3sF0rt!P@ssw0rd#2025"

python .\altiora.py backup  $plain $bk  -p $pwd
python .\altiora.py verify  $bk   -p $pwd
python .\altiora.py restore $bk   $out  -p $pwd --force

$restored = Join-Path $out "file.txt"
if (-not (Test-Path $restored)) { throw "Fichier restauré introuvable" }

$c = Get-Content $restored -Raw
if ($c -notmatch "SECRET DATA 123") { throw "Contenu restauré différent" }

Write-Host "✅ CI smoke test OK"
