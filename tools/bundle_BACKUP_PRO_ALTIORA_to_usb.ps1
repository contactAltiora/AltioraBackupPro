$ErrorActionPreference="Stop"

$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "BUNDLE-USB: $m" }

$bundleScript = Join-Path $root "tools\bundle_BACKUP_PRO_ALTIORA.ps1"
if(!(Test-Path $bundleScript)){
  Fail "Script bundle introuvable: $bundleScript"
}

Write-Host "[BUNDLE-USB] GÃ©nÃ©ration bundle..."
& $bundleScript

$receipt = Join-Path $root "_out\bundle_receipt_BACKUP_PRO_ALTIORA.txt"
if(!(Test-Path $receipt)){
  Fail "Receipt introuvable aprÃ¨s gÃ©nÃ©ration: $receipt"
}

$bundleZip = (Get-Content -LiteralPath $receipt -Encoding UTF8 -Raw).Trim()
if([string]::IsNullOrWhiteSpace($bundleZip)){
  Fail "Receipt vide: $receipt"
}
if(!(Test-Path $bundleZip)){
  Fail "ZIP indiquÃ© par receipt introuvable: $bundleZip"
}

$bundleName = Split-Path $bundleZip -Leaf
Write-Host "[BUNDLE-USB] Bundle (receipt): $bundleZip"

$localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $bundleZip).Hash
$localSize = (Get-Item -LiteralPath $bundleZip).Length
Write-Host "[BUNDLE-USB] Local size: $localSize bytes"
Write-Host "[BUNDLE-USB] Local sha256: $localHash"

$drives = @("F:","H:")
$copied = 0

foreach($d in $drives){
  if(!(Test-Path "$d\")){
    Write-Host "[BUNDLE-USB] Drive absent: $d (skip)"
    continue
  }

  $destDir = Join-Path $d "ABP_RELEASES"
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null

  $destZip = Join-Path $destDir $bundleName

  Write-Host "[BUNDLE-USB] Copy -> $destZip"
  Copy-Item -LiteralPath $bundleZip -Destination $destZip -Force

  $destSize = (Get-Item -LiteralPath $destZip).Length
  if($destSize -ne $localSize){
    Fail "Taille diffÃ©rente sur $d : local=$localSize vs dest=$destSize"
  }

  $destHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destZip).Hash
  if($destHash -ne $localHash){
    Fail "SHA256 diffÃ©rent sur $d : local=$localHash vs dest=$destHash"
  }

  $shaPath = Join-Path $destDir ([IO.Path]::GetFileNameWithoutExtension($bundleName) + ".sha256")
  Set-Content -LiteralPath $shaPath -Value ($localHash + "  " + $bundleName) -Encoding ASCII

  Write-Host "[BUNDLE-USB] OK: $d"
  $copied++
}

if($copied -eq 0){
  Fail "Aucun disque cible trouvÃ© (F: et H: absents)."
}

Write-Host "============================================================"
Write-Host "âœ… DONE: bundle copiÃ© et vÃ©rifiÃ© sur $copied drive(s)"
Write-Host "============================================================"
