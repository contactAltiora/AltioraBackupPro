# Altiora Backup Pro — automatic STATE generator
# No parameters required

$ErrorActionPreference = "Stop"

# detect repo root (parent of tools folder)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

$releasesDir = Join-Path $repoRoot "_out\releases"

if(-not (Test-Path $releasesDir)){
    throw "Releases directory not found: $releasesDir"
}

# find latest release zip
$lastZip = Get-ChildItem $releasesDir -Filter "AltioraBackupPro_v*_release.zip" |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1

if(-not $lastZip){
    throw "No release zip found"
}
# extract version
# ABP_UPDATE_STATE_USE_NAME_BN_V3K3MIN
$bn = [IO.Path]::GetFileNameWithoutExtension($lastZip.Name)
# ABP_UPDATE_STATE_FIX_BN_NEWLINE_V3K4
if($bn -match "^AltioraBackupPro_(v\d+\.\d+\.\d+)(?:[A-Za-z0-9.+_-]+)?_release$"){
    $version = $Matches[1]
}else{
    throw "Version parse error"
}

# compute SHA256
$sha = (Get-FileHash $lastZip.FullName -Algorithm SHA256).Hash.ToUpper()

# backup dirs
$backupDirs = @("F:\ABP_RELEASES","H:\ABP_RELEASES")

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$state = @"
# Altiora Backup Pro — STATE

Date: $date
Status: STABLE

Version: $version

Release ZIP:
$($lastZip.FullName)

SHA256:
$sha

Repo:
$repoRoot

Releases:
$releasesDir

External backups:
$($backupDirs -join "`n")

END OF STATE
"@

$statePath = Join-Path $repoRoot "STATE.md"

# encoding compatibility PS5.1 / PS7+
if ($PSVersionTable.PSVersion.Major -ge 6)
{
    # PowerShell 7+
    $state | Set-Content $statePath -Encoding utf8NoBOM
}
else
{
    # Windows PowerShell 5.1 fallback
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($statePath, $state, $utf8)
}
# generate SHA256 for STATE.md
$stateHash = (Get-FileHash $statePath -Algorithm SHA256).Hash.ToUpper()
$hashFile = "$statePath.sha256"

$stateHash | Set-Content $hashFile -Encoding ASCII
# copy to external drives
foreach($d in $backupDirs){
    if(Test-Path $d){
        Copy-Item $statePath "$d\STATE.md" -Force
Copy-Item $hashFile "$d\STATE.md.sha256" -Force
    }
}

Write-Host ""
Write-Host "STATE.md updated automatically"
Write-Host "Version:" $version
Write-Host "File:" $statePath
Write-Host "STATE SHA256:" $stateHash

