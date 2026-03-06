$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$altiora = Join-Path $repo "altiora.py"

if(!(Test-Path $altiora)){
    throw "altiora.py introuvable"
}

Write-Host "Patch system-info"

# créer module system_info
$module = Join-Path $repo "src\system_info.py"

$content = @'
import platform
import datetime
import os

def show_system_info():

    print("")
    print("=== ALTIORA BACKUP PRO ===")
    print("")

    version = "v1.0.17"
    build_date = "2026-03-06"

    print("Version :", version)
    print("Build date :", build_date)
    print("")

    print("=== SYSTEM ===")

    print("OS :", platform.system(), platform.release())
    print("Architecture :", platform.machine())
    print("Python runtime :", platform.python_version())

    print("")
    print("Current working directory :", os.getcwd())

    print("")
    print("System check completed.")
'@

Set-Content -Path $module -Value $content -Encoding UTF8

Write-Host "Module system_info créé"

# injecter commande dans altiora.py
$txt = Get-Content $altiora -Raw

if($txt -match "system-info"){
    Write-Host "Commande system-info déjà présente"
}
else{

$inject = @'

elif args.command == "system-info":
    from src.system_info import show_system_info
    show_system_info()

'@

$txt = $txt -replace "if __name__ == ""__main__"":", "$inject`nif __name__ == ""__main__"":"

Set-Content $altiora $txt -Encoding UTF8

Write-Host "Commande system-info injectée"
}

Write-Host "Patch terminé"