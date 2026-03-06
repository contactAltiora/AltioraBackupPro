$ErrorActionPreference = "Stop"

$repoRoot = "C:\Dev\AltioraBackupPro"
$stateFile = Join-Path $repoRoot "_out\release_state.json"

Write-Host ""
Write-Host "=== ALTIORA BACKUP PRO - RELEASE MANAGER ==="
Write-Host ""

if (!(Test-Path $stateFile)) {
    throw "release_state.json introuvable"
}

$state = Get-Content $stateFile -Raw | ConvertFrom-Json

Write-Host "Projet :" $state.project
Write-Host "Organisation :" $state.organization
Write-Host "Auteur :" $state.author
Write-Host ""

$current = $state.releases | Where-Object { $_.version -eq $state.current_version }

if ($null -eq $current) {
    throw "Version courante introuvable dans releases"
}

Write-Host "Version courante :" $current.version
Write-Host "Date :" $current.date
Write-Host "Statut :" $current.status
Write-Host ""

Write-Host "=== VERIFICATION DES ARTEFACTS ==="
Write-Host ""

$artifacts = $current.artifacts

foreach ($key in $artifacts.PSObject.Properties.Name) {

    $relativePath = $artifacts.$key
    $fullPath = Join-Path $repoRoot $relativePath

    if (Test-Path $fullPath) {
        Write-Host "[OK] $key -> $relativePath"
    }
    else {
        Write-Host "[MANQUANT] $key -> $relativePath"
    }
}

Write-Host ""
Write-Host "=== VERIFICATION TERMINEE ==="