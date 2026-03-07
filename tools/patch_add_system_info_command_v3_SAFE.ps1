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

Write-Host "PATCH: add system-info command v3"

$txt = Get-Content -LiteralPath $altiora -Encoding UTF8 -Raw

# 1) Guard: aucune trace existante
if ($txt -match 'add_parser\("system-info"' -or $txt -match 'args\.command\s*==\s*"system-info"') {
    throw "system-info semble deja present. Patch fail-closed."
}

# 2) Ecrire le module
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
Write-Host "Module src/system_info.py ecrit"

# 3) Ajouter le subparser juste apres stats
$parserAnchor = '    subparsers.add_parser("stats", help="Afficher les statistiques", parents=[parent])'
if (-not $txt.Contains($parserAnchor)) {
    throw 'Ancrage parser stats introuvable. Patch fail-closed.'
}

$parserInsert = @'
    subparsers.add_parser("stats", help="Afficher les statistiques", parents=[parent])
    subparsers.add_parser("system-info", help="Afficher les informations systeme", parents=[parent])
'@

$txt = $txt.Replace($parserAnchor, $parserInsert)
Write-Host "Subparser system-info ajoute"

# 4) Injecter le bloc de commande juste avant if __name__ == "__main__"
$mainAnchor = @'

if __name__ == "__main__":
    raise SystemExit(main())
'@

if (-not $txt.Contains($mainAnchor)) {
    throw 'Ancrage final main introuvable. Patch fail-closed.'
}

$commandBlock = @'

    if args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()
        return 0

if __name__ == "__main__":
    raise SystemExit(main())
'@

$txt = $txt.Replace($mainAnchor, $commandBlock)
Write-Host "Bloc args.command == system-info ajoute"

Set-Content -LiteralPath $altiora -Value $txt -Encoding UTF8
Write-Host "PATCH OK"