$ErrorActionPreference = "Stop"

$repoRoot = "C:\Dev\AltioraBackupPro"
$version = "v1.0.17"

$distRoot = Join-Path $repoRoot "_out\distribution\AltioraBackupPro_${version}_distribution"

Write-Host ""
Write-Host "=== BUILD DISTRIBUTION PACKAGE ==="
Write-Host ""

if (Test-Path $distRoot) {
    Remove-Item $distRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $distRoot | Out-Null

# Copier release
Copy-Item "$repoRoot\_out\releases\AltioraBackupPro_${version}_release.zip" $distRoot
Copy-Item "$repoRoot\_out\releases\AltioraBackupPro_${version}_release.sha256" $distRoot
Copy-Item "$repoRoot\_out\releases\AltioraBackupPro_${version}_release.zip.sig" $distRoot

Write-Host "Release copié."

# Copier bundle client
Copy-Item "$repoRoot\_out\client_bundles\AltioraBackupPro_ClientBundle_v1.zip" $distRoot

Write-Host "Client bundle copié."

# Copier master context
Copy-Item "$repoRoot\MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md" $distRoot

Write-Host "Master context copié."

# Créer manifeste
$manifest = @"
ALTIORA BACKUP PRO
OFFICIAL DISTRIBUTION PACKAGE

Version : $version
Auteur : Guy Mouyeme
Organisation : Altiora Patrimoine

Contenu :

- AltioraBackupPro_${version}_release.zip
- AltioraBackupPro_${version}_release.sha256
- AltioraBackupPro_${version}_release.zip.sig
- AltioraBackupPro_ClientBundle_v1.zip
- MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md
- DISTRIBUTION_MANIFEST.txt

Verification :

1. Verifier SHA256
2. Verifier signature
3. Verifier bundle client

Sauvegardes officielles :

F:\ABP_RELEASES
H:\ABP_RELEASES
"@

Set-Content (Join-Path $distRoot "DISTRIBUTION_MANIFEST.txt") $manifest -Encoding UTF8

Write-Host "Manifeste créé."

# Copie vers sauvegardes externes
if (Test-Path "F:\ABP_RELEASES") {
    Copy-Item $distRoot "F:\ABP_RELEASES\" -Recurse -Force
    Write-Host "Distribution copiée vers F:\ABP_RELEASES"
}

if (Test-Path "H:\ABP_RELEASES") {
    Copy-Item $distRoot "H:\ABP_RELEASES\" -Recurse -Force
    Write-Host "Distribution copiée vers H:\ABP_RELEASES"
}

Write-Host ""
Write-Host "=== DISTRIBUTION PACKAGE TERMINE ==="