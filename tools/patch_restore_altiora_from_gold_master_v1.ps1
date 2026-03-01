$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$root = (Get-Location).Path

$target = Join-Path $root "altiora.py"

$gold = "C:\Dev\GOLD_MASTER_AltioraBackupPro_v1.0.17\altiora.py"

if(!(Test-Path $gold)){
    throw "GOLD MASTER introuvable: $gold"
}

Copy-Item $gold $target -Force

Write-Host "altiora.py restored from GOLD MASTER"
