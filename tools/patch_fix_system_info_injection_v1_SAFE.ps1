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

Write-Host "PATCH: fix system-info injection"

# 1) Recharger altiora.py
$txt = Get-Content -LiteralPath $altiora -Encoding UTF8 -Raw

# 2) Supprimer une éventuelle mauvaise injection déjà présente
$badPattern = [regex]::Escape(@'

elif args.command == "system-info":
    from src.system_info import show_system_info
    show_system_info()

'@)

$txt2 = [regex]::Replace($txt, $badPattern, "", 1)

if ($txt2 -ne $txt) {
    Write-Host "Ancienne injection incorrecte supprimee"
    $txt = $txt2
} else {
    Write-Host "Aucune ancienne injection incorrecte a supprimer"
}

# 3) Verifier que la commande n'existe pas deja
if ($txt -match 'args\.command\s*==\s*"system-info"') {
    throw "system-info semble deja present ailleurs dans altiora.py; verification manuelle du patch requise"
}

# 4) Creer / reecrire le module src/system_info.py
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

# 5) Injecter au bon endroit :
#    juste avant le bloc final "else:" qui gere les commandes inconnues
$anchor = @'
    else:
        parser.error(f"unknown command: {args.command}")
'@

if ($txt -notmatch [regex]::Escape($anchor.Trim())) {
    throw "Bloc d'ancrage introuvable dans altiora.py. Patch fail-closed."
}

$inject = @'
    elif args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()

'@

$txt3 = $txt -replace [regex]::Escape($anchor), ($inject + $anchor)

if ($txt3 -eq $txt) {
    throw "Injection system-info non appliquee"
}

Set-Content -LiteralPath $altiora -Value $txt3 -Encoding UTF8
Write-Host "Injection system-info appliquee au bon endroit"

Write-Host "PATCH OK"