$ErrorActionPreference = "Stop"

$repoRoot = "C:\Dev\AltioraBackupPro"
$bundleName = "AltioraBackupPro_ClientBundle_v1"

$bundleRoot = Join-Path $repoRoot "_out\client_bundles\$bundleName"
$zipPath = Join-Path $repoRoot "_out\client_bundles\$bundleName.zip"

Write-Host ""
Write-Host "=== ALTIORA BACKUP PRO - CLIENT BUNDLE BUILD ==="
Write-Host ""

# Nettoyage dossier bundle
if (Test-Path $bundleRoot) {
    Remove-Item $bundleRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $bundleRoot | Out-Null

# Copier EXE
$exe = Join-Path $repoRoot "dist\AltioraBackupPro.exe"

if (!(Test-Path $exe)) {
    throw "EXE introuvable : dist\AltioraBackupPro.exe"
}

Copy-Item $exe $bundleRoot -Force
Write-Host "EXE copie."

# Trouver dernier SHA256
$sha = Get-ChildItem "$repoRoot\_out\releases\*.sha256" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

Copy-Item $sha.FullName (Join-Path $bundleRoot "checksum.sha256") -Force
Write-Host "Checksum copie : $($sha.Name)"

# Trouver dernière signature
$sig = Get-ChildItem "$repoRoot\_out\releases\*.sig" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

Copy-Item $sig.FullName (Join-Path $bundleRoot "signature.sig") -Force
Write-Host "Signature copiee : $($sig.Name)"

# README
$readme = @"
ALTIORA BACKUP PRO - CLIENT BUNDLE V1

Contenu du dossier :
- AltioraBackupPro.exe
- README.txt
- LICENSE.txt
- restore_example.ps1
- checksum.sha256
- signature.sig

Usage :
1. Verifier checksum.sha256 et signature.sig
2. Conserver le bundle intact
3. Executer AltioraBackupPro.exe
4. Utiliser restore_example.ps1 comme modele

Produit distribue par Altiora Patrimoine.
Version : ClientBundle_v1
"@

Set-Content (Join-Path $bundleRoot "README.txt") $readme -Encoding UTF8

# LICENSE
$license = @"
ALTIORA BACKUP PRO - LICENSE NOTICE

Ce bundle est fourni pour evaluation ou usage autorise.

Redistribution interdite sans autorisation.
Licence commerciale definitive a venir.
"@

Set-Content (Join-Path $bundleRoot "LICENSE.txt") $license -Encoding UTF8

# restore example
$restore = @"
`$ErrorActionPreference = "Stop"

Write-Host "ALTIORA BACKUP PRO - RESTORE EXAMPLE"

# Exemple indicatif :
# .\AltioraBackupPro.exe restore --input "C:\Backups\archive.abp" --output "C:\RestoreTarget"
"@

Set-Content (Join-Path $bundleRoot "restore_example.ps1") $restore -Encoding UTF8

Write-Host "Fichiers textes generes."

# Creation ZIP
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Compress-Archive -Path "$bundleRoot\*" -DestinationPath $zipPath

Write-Host ""
Write-Host "ZIP cree : $zipPath"

# Sauvegarde F
if (Test-Path "F:\ABP_RELEASES") {
    Copy-Item $zipPath "F:\ABP_RELEASES\" -Force
    Write-Host "Copie vers F:\ABP_RELEASES"
}

# Sauvegarde H
if (Test-Path "H:\ABP_RELEASES") {
    Copy-Item $zipPath "H:\ABP_RELEASES\" -Force
    Write-Host "Copie vers H:\ABP_RELEASES"
}

Write-Host ""
Write-Host "=== BUILD CLIENT BUNDLE TERMINE ==="