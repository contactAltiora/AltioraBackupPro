$ErrorActionPreference = "Stop"

Write-Host "=== Security audit (deps + SAST + SBOM) ==="

# Repo root (robuste CI + console)
$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Impossible de détecter la racine git" }
Set-Location $repoRoot
Write-Host "Repo root: $(Get-Location)"

# Python venv si dispo
$PY = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $PY)) { $PY = "python" }

# Installer outils audit
& $PY -m pip install --upgrade pip | Out-Null
& $PY -m pip install -r .\requirements-audit.txt | Out-Null

# 1) Audit deps (requirements*.txt s’ils existent)
$reqFiles = @(
  ".\requirements.txt",
  ".\requirements-ci.txt",
  ".\requirements-build.txt",
  ".\requirements-audit.txt"
) | Where-Object { Test-Path $_ }

if ($reqFiles.Count -eq 0) { throw "Aucun requirements*.txt trouvé pour audit" }

foreach ($f in $reqFiles) {
  Write-Host "-> pip-audit on $f"
  & $PY -m pip_audit -r $f
  if ($LASTEXITCODE -ne 0) { throw "pip-audit a trouvé des vulnérabilités (fichier=$f)" }
}

# 2) SAST (Bandit) sur src + altiora.py
Write-Host "-> bandit (src + altiora.py)"
$targets = @()
if (Test-Path ".\src") { $targets += ".\src" }
if (Test-Path ".\altiora.py") { $targets += ".\altiora.py" }
if ($targets.Count -eq 0) { throw "Targets bandit introuvables (src/altiora.py)" }

& $PY -m bandit -r @($targets) -lll -ii -x ".\.venv,.\dist,.\build"
if ($LASTEXITCODE -ne 0) { throw "Bandit a trouvé des issues (SAST)" }

# 3) SBOM CycloneDX (pour la supply-chain)
Write-Host "-> SBOM CycloneDX"
& $PY -m cyclonedx_py environment --output-format json --output-file .\sbom.json
if ($LASTEXITCODE -ne 0) { throw "Échec génération SBOM" }

Write-Host "✅ Audit OK (deps + SAST + SBOM)"
