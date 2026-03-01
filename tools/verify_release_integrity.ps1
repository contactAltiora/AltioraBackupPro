param(
    [string]$RepoRoot = "C:\Dev\AltioraBackupPro"
)

$publicKey = Join-Path $RepoRoot "keys\altiora_public_key.pem"
$releases  = Join-Path $RepoRoot "_out\snapshots_weekly"

$latest = Get-ChildItem $releases -Filter "*.zip" |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1

if(-not $latest){
    Write-Host "No snapshot found"
    exit 1
}

Write-Host "Checking:" $latest.FullName

py "$RepoRoot\tools\verify_signature.py" `
   $publicKey `
   $latest.FullName