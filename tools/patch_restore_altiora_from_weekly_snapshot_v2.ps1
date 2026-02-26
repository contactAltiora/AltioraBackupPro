$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"

$snapDir = Join-Path $root "_out\snapshots_weekly"

if(!(Test-Path -LiteralPath $snapDir)){
  throw "snapshots_weekly introuvable: $snapDir"
}

$zip = Get-ChildItem -LiteralPath $snapDir -Filter "AltioraBackupPro_WEEKLY_*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if(!$zip){
  throw "Aucun snapshot weekly trouvé"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$tmpDir = Join-Path $snapDir "_extract_altiora_tmp"

if(Test-Path $tmpDir){
  Remove-Item $tmpDir -Recurse -Force
}

New-Item -ItemType Directory -Path $tmpDir | Out-Null

[System.IO.Compression.ZipFile]::ExtractToDirectory(
  $zip.FullName,
  $tmpDir
)

$found = Get-ChildItem $tmpDir -Recurse -Filter altiora.py | Select-Object -First 1

if(!$found){
  throw "altiora.py introuvable dans snapshot"
}

Copy-Item $found.FullName $target -Force

Remove-Item $tmpDir -Recurse -Force

Write-Host "altiora.py restauré depuis:"
Write-Host $zip.FullName
