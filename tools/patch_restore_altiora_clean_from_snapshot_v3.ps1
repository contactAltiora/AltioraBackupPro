$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
 throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$snap=Join-Path $root "_out\snapshots_weekly"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip=Get-ChildItem $snap -Filter "*.zip" |
Sort-Object LastWriteTime -Descending |
Select-Object -First 1

$tmp=Join-Path $snap "_restore_tmp"

if(Test-Path $tmp){Remove-Item $tmp -Recurse -Force}

[System.IO.Compression.ZipFile]::ExtractToDirectory($zip.FullName,$tmp)

$src=Get-ChildItem $tmp -Recurse -Filter altiora.py |
Select-Object -First 1

Copy-Item $src.FullName (Join-Path $root "altiora.py") -Force

Remove-Item $tmp -Recurse -Force

Write-Host "altiora.py restored clean"
