$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$altiora = Join-Path $repo "altiora.py"
$module  = Join-Path $repo "src\system_info.py"

if (!(Test-Path $altiora)) {
    throw "altiora.py introuvable"
}

Write-Host "PATCH: fix system-info injection v2"

$txt = Get-Content -LiteralPath $altiora -Encoding UTF8 -Raw

# 1) Supprimer le bloc system-info mal place en fin de fichier
$badBlock = @'

elif args.command == "system-info":
    from src.system_info import show_system_info
    show_system_info()

if __name__ == "__main__":
'@

if ($txt.Contains($badBlock)) {
    $txt = $txt.Replace($badBlock, @'

if __name__ == "__main__":
'@)
    Write-Host "Bloc system-info incorrect supprime"
} else {
    Write-Host "Bloc system-info incorrect non trouve"
}

# 2) Reecrire system_info.py proprement
$moduleContent = @'
import platform
import os

def show_system_info():
    print("")
    print("=== ALTIORA BACKUP PRO ===")
    print("")
    print("Version :", "v1.0.17")
    print("Build date :", "2026-03-06")
    print("")
    print("=== SYSTEM ===")
    print("OS :", platform.system(), platform.release())
    print("Architecture :", platform.machine())
    print("Python runtime :", platform.python_version())
    print("")
    print("=== PATHS ===")
    print("Current working directory :", os.getcwd())
    print("")
    print("System check completed.")
'@

Set-Content -LiteralPath $module -Value $moduleContent -Encoding UTF8
Write-Host "Module system_info.py ecrit"

# 3) Ajouter le sous-parser argparse pour system-info si absent
if ($txt -match 'add_parser\("system-info"') {
    Write-Host "Sous-parser system-info deja present"
} else {
    $anchorParser = '    p_stats = sub.add_parser("stats", help="Statistiques globales")'
    if (-not $txt.Contains($anchorParser)) {
        throw 'Ancrage parser "p_stats" introuvable. Patch fail-closed.'
    }

    $parserInject = @'
    p_stats = sub.add_parser("stats", help="Statistiques globales")
    p_sysinfo = sub.add_parser("system-info", help="Informations systeme et environnement")
'@

    $txt = $txt.Replace($anchorParser, $parserInject)
    Write-Host "Sous-parser system-info ajoute"
}

# 4) Injecter le bloc system-info dans main(), juste avant if __name__ == "__main__":
if ($txt -match '^\s*if args\.command == "system-info":' -or $txt -match '^\s*elif args\.command == "system-info":') {
    Write-Host "Bloc system-info deja present dans main()"
} else {
    $anchorMain = @'

if __name__ == "__main__":
'@

    if (-not $txt.Contains($anchorMain)) {
        throw 'Ancrage final main() introuvable. Patch fail-closed.'
    }

    $mainInject = @'

    if args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()
        return 0

if __name__ == "__main__":
'@

    $txt = $txt.Replace($anchorMain, $mainInject)
    Write-Host "Bloc system-info injecte dans main()"
}

Set-Content -LiteralPath $altiora -Value $txt -Encoding UTF8
Write-Host "PATCH OK"