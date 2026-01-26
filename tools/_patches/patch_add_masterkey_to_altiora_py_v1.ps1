$path = "C:\Dev\AltioraBackupPro\altiora.py"
$txt  = Get-Content $path -Raw -Encoding UTF8

# 1) Ajoute le subparser "masterkey" dans la zone où sont déclarées les commandes
# On cible le motif 'subparsers = parser.add_subparsers(' si présent, sinon on ne fait rien.
if($txt -match "subparsers\s*=\s*parser\.add_subparsers"){
  if($txt -notmatch 'add_parser\("masterkey"'){
    $txt = $txt -replace '(subparsers\s*=\s*parser\.add_subparsers[^\n]*\n)',
@"
`$1
    # masterkey
    p_mk = subparsers.add_parser("masterkey", help="Gerer la Master Key")
    mk_sub = p_mk.add_subparsers(dest="mk_command", help="Actions Master Key")

    mk_sub.add_parser("status", help="Verifier si la Master Key est initialisee")
    mk_init = mk_sub.add_parser("init", help="Initialiser la Master Key (creer master_key.json)")
    mk_init.add_argument("-p", "--password", required=True, help="Mot de passe Master Key")

    mk_rot = mk_sub.add_parser("rotate", help="Changer le mot de passe (re-chiffre la master key)")
    mk_rot.add_argument("--old", required=True, help="Ancien mot de passe")
    mk_rot.add_argument("--new", required=True, help="Nouveau mot de passe")
"@
  }
} else {
  throw "ERROR: impossible de trouver 'subparsers = parser.add_subparsers(...)' dans altiora.py"
}

# 2) Ajoute le dispatch masterkey : on cherche un endroit sûr avant la fin du handler des commandes.
if($txt -notmatch 'args\.command\s*==\s*"masterkey"'){
  # On injecte juste avant le fallback / help final (on cherche 'parser.print_help()' de fin si présent)
  if($txt -match "parser\.print_help\(\)"){
    $txt = $txt -replace '(parser\.print_help\(\)\s*\n\s*return\s+\d+\s*\n)',
@"
        if args.command == "masterkey":
            # Import local pour eviter de charger si non utilise
            try:
                from src.master_key import MasterKeyManager, MasterKeyError
            except Exception:
                # fallback si src n'est pas resolu comme package
                from master_key import MasterKeyManager, MasterKeyError  # type: ignore

            mgr = MasterKeyManager()

            if getattr(args, "mk_command", None) == "status":
                print("OK" if mgr.exists() else "NOT_INITIALIZED")
                return 0

            if args.mk_command == "init":
                try:
                    p = mgr.init(args.password)
                    print(str(p))
                    return 0
                except MasterKeyError as e:
                    print(f"ERROR: {e}")
                    return 2

            if args.mk_command == "rotate":
                try:
                    mgr.rotate(args.old, args.new)
                    print("OK")
                    return 0
                except MasterKeyError as e:
                    print(f"ERROR: {e}")
                    return 2

            parser.print_help()
            return 2

$1
"@
  } else {
    throw "ERROR: impossible de trouver un point d'injection (parser.print_help) dans altiora.py"
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $txt, $utf8NoBom)
Write-Host "OK: masterkey ajoute dans altiora.py"
