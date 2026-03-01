$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$root = (Get-Location).Path
$target = Join-Path $root "altiora.py"

$goldRoot = "C:\Dev\GOLD_MASTER_AltioraBackupPro_v1.0.17"

if(!(Test-Path $goldRoot)){
    throw "GOLD MASTER dir introuvable"
}

$found = Get-ChildItem $goldRoot -Recurse -Filter altiora.py | Select-Object -First 1

if(!$found){
    throw "altiora.py non trouvé dans GOLD MASTER"
}

Copy-Item $found.FullName $target -Force

Write-Host "altiora.py restored from GOLD MASTER:"
Write-Host $found.FullName
