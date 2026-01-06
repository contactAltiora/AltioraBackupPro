$ErrorActionPreference = "Stop"

Write-Host "=== Security audit (Windows) ==="
$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Impossible de détecter la racine git." }
Set-Location $repoRoot
Write-Host "Repo root: $(Get-Location)"

# Python du venv si dispo, sinon python système
$PY = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $PY)) { $PY = "python" }
& $PY --version

# Installer/mettre à jour pip + outils audit
& $PY -m pip install --upgrade pip | Out-Null
& $PY -m pip install pip-audit | Out-Null

# Audit des dépendances (requirements*.txt si présents)
$reqs = @(
  ".\requirements.txt",
  ".\requirements-ci.txt",
  ".\requirements-build.txt"
) | Where-Object { Test-Path $_ }

if ($reqs.Count -eq 0) {
  Write-Host "ℹ️ Aucun requirements*.txt trouvé pour audit."
} else {
  foreach ($r in $reqs) {
    Write-Host "`n--- pip-audit: $r ---"
    & $PY -m pip_audit -r $r
    if ($LASTEXITCODE -ne 0) { throw "pip-audit a détecté des vulnérabilités (fichier: $r)." }
  }
}

Write-Host "`n✅ Security audit OK (pip-audit)"
