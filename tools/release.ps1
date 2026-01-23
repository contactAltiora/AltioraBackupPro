param(
  [Parameter(Mandatory=$true)]
  [string]$Version,

  [string]$Repo = "contactAltiora/AltioraBackupPro",
  [string]$ExeName = "altiora",
  [string]$WorkDir = "C:\Dev\AltioraBackupPro",

  [switch]$SkipTag,
  [string]$Supersede = "",
  [switch]$NoBuild,
  [switch]$NoSbom,
  [switch]$NoHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Require-Cmd([string]$name) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    throw "Commande introuvable: $name. Installe/ajoute au PATH puis rÃ©essaie."
  }
}

Require-Cmd git
Require-Cmd gh
Require-Cmd py
Require-Cmd cyclonedx-py

# Normalise version -> vX.Y.Z
$tag = $Version.Trim()
if ($tag -notmatch '^v') { $tag = "v$tag" }

Write-Host "== Altiora release ==" -ForegroundColor Cyan
Write-Host "WorkDir : $WorkDir"
Write-Host "Tag     : $tag"
Write-Host "Repo    : $Repo"
Write-Host ""

if (-not (Test-Path $WorkDir)) { throw "WorkDir introuvable: $WorkDir" }
Set-Location $WorkDir

if (-not (Test-Path ".git")) { throw "Pas de .git ici. Lance depuis le repo: $WorkDir" }

Write-Host "[1/7] git status / sync" -ForegroundColor Yellow
$dirty = git status --porcelain
if ($dirty) { throw "Working tree non clean:`n$dirty`nCommit/stash avant de releaser." }

git fetch --all --prune | Out-Null
git pull --ff-only | Out-Null

$head = (git rev-parse --short HEAD).Trim()
Write-Host "HEAD: $head"

# Tag
if (-not $SkipTag) {
  Write-Host "[2/7] tag" -ForegroundColor Yellow
  $tagExists = $false
  git show-ref --tags $tag 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $tagExists = $true }
  if ($tagExists) { throw "Le tag $tag existe dÃ©jÃ . Choisis une autre version ou utilise -SkipTag." }

  git tag $tag
  git push origin $tag | Out-Null
  Write-Host "Tag pushed: $tag"
} else {
  Write-Host "[2/7] tag (skip)" -ForegroundColor DarkYellow
}

# Build
if (-not $NoBuild) {
  Write-Host "[3/7] build (PyInstaller)" -ForegroundColor Yellow
  Remove-Item -Recurse -Force .\build,.\dist -EA SilentlyContinue
  py -m PyInstaller .\altiora.py --onefile --name $ExeName --clean --noconfirm
} else {
  Write-Host "[3/7] build (skip)" -ForegroundColor DarkYellow
}

if (-not (Test-Path ".\dist\$ExeName.exe")) {
  throw "Build KO: .\dist\$ExeName.exe introuvable."
}

# Ensure dist exists
New-Item -ItemType Directory -Force -Path .\dist | Out-Null

# SHA256
if (-not $NoHash) {
  Write-Host "[4/7] sha256" -ForegroundColor Yellow
  Get-FileHash ".\dist\$ExeName.exe" -Algorithm SHA256 |
    Select-Object -ExpandProperty Hash |
    Out-File -Encoding ascii ".\dist\$ExeName.exe.sha256"
} else {
  Write-Host "[4/7] sha256 (skip)" -ForegroundColor DarkYellow
}

# SBOM (requirements)
if (-not $NoSbom) {
  Write-Host "[5/7] sbom (requirements)" -ForegroundColor Yellow
  if (-not (Test-Path ".\requirements.txt")) { throw "requirements.txt introuvable Ã  la racine." }
  cyclonedx-py requirements --output-reproducible --of json -o .\dist\sbom.cdx.json .\requirements.txt
  if (-not (Test-Path ".\dist\sbom.cdx.json")) { throw "SBOM KO: dist\sbom.cdx.json introuvable." }
} else {
  Write-Host "[5/7] sbom (skip)" -ForegroundColor DarkYellow
}

# Release assets
Write-Host "[6/7] GitHub release" -ForegroundColor Yellow
$assets = @(".\dist\$ExeName.exe")
if (-not $NoHash) { $assets += ".\dist\$ExeName.exe.sha256" }
if (-not $NoSbom) { $assets += ".\dist\sbom.cdx.json" }

# create or upload
$releaseExists = $false
try {
  gh release view $tag --repo $Repo *> $null
  if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
} catch { $releaseExists = $false }

if ($releaseExists) {
  Write-Host "Release $tag existe dÃ©jÃ  -> upload assets (clobber)" -ForegroundColor DarkYellow
  gh release upload $tag @($assets) --repo $Repo --clobber
} else {
  $title = "$tag - Release aligned with main HEAD"
  $notes = "Aligned with main HEAD ($head). Includes SHA256 + SBOM (project/requirements). PRO license verification via embedded Ed25519 public key."
  gh release create $tag @($assets) --repo $Repo --title $title --notes $notes
}

# Supersede (optionnel)
if ($Supersede) {
  Write-Host "[7/7] supersede $Supersede" -ForegroundColor Yellow
  gh release edit $Supersede --repo $Repo --notes "Superseded by $tag (aligned with main HEAD). Please use $tag."
} else {
  Write-Host "[7/7] supersede (skip)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "OK âœ… Release prÃªte: $tag  (HEAD=$head)" -ForegroundColor Green
gh release view $tag --repo $Repo --json tagName,assets -q "{tag:.tagName, assets:[.assets[].name]}"


