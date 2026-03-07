$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$altiora = Join-Path $repo "altiora.py"
$module  = Join-Path $repo "src\license_info.py"

if (!(Test-Path $altiora)) {
    throw "altiora.py introuvable"
}

Write-Host "PATCH: add license-info command v1"

$txt = Get-Content -LiteralPath $altiora -Encoding UTF8 -Raw

if ($txt -match 'add_parser\("license-info"' -or $txt -match 'args\.command\s*==\s*"license-info"') {
    throw "license-info semble deja present. Patch fail-closed."
}

$moduleContent = @'
import os

def show_license_info():
    edition = "FREE"
    status = "active"
    source = "env_free"
    restore_limit = "1 GB"

    if os.environ.get("ALTIORA_LICENSE_FILE"):
        edition = "PRO"
        source = "license_file"

    print("")
    print("=== LICENSE INFO ===")
    print("")
    print("Edition :", edition)
    print("License status :", status)
    print("License source :", source)
    print("Restore limit :", restore_limit)
    print("")
'@

Set-Content -LiteralPath $module -Value $moduleContent -Encoding UTF8
Write-Host "Module src/license_info.py ecrit"

$parserAnchor = '    subparsers.add_parser("system-info", help="Afficher les informations systeme", parents=[parent])'
if (-not $txt.Contains($parserAnchor)) {
    throw 'Ancrage parser system-info introuvable. Patch fail-closed.'
}

$parserInsert = @'
    subparsers.add_parser("system-info", help="Afficher les informations systeme", parents=[parent])
    subparsers.add_parser("license-info", help="Afficher les informations licence", parents=[parent])
'@

$txt = $txt.Replace($parserAnchor, $parserInsert)
Write-Host "Subparser license-info ajoute"

$mainAnchor = @'

    if args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()
        return 0

if __name__ == "__main__":
    raise SystemExit(main())
'@

if (-not $txt.Contains($mainAnchor)) {
    throw 'Ancrage bloc system-info introuvable. Patch fail-closed.'
}

$commandBlock = @'

    if args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()
        return 0

    if args.command == "license-info":
        from src.license_info import show_license_info
        show_license_info()
        return 0

if __name__ == "__main__":
    raise SystemExit(main())
'@

$txt = $txt.Replace($mainAnchor, $commandBlock)

Set-Content -LiteralPath $altiora -Value $txt -Encoding UTF8
Write-Host "Bloc license-info ajoute"

Write-Host "PATCH OK"