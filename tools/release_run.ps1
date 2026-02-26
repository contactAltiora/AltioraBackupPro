# tools\release_run.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if([string]::IsNullOrWhiteSpace($env:ABP_SELFTEST_PASSWORD)){
  $env:ABP_SELFTEST_PASSWORD = ([guid]::NewGuid().ToString("N") + "!" + [guid]::NewGuid().ToString("N"))
  Write-Host "ABP_SELFTEST_PASSWORD generated for this session."
}

& (Join-Path $repoRoot "tools\release_build_and_backup.ps1")