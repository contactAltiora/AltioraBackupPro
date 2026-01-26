$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$txt  = Get-Content $path -Raw -Encoding UTF8

if($txt -notmatch "masterkey"){
  $txt = $txt -replace "(subparsers\s*=\s*parser\.add_subparsers[^\n]*\n)", "`$1`n        # masterkey`n        p_mk = subparsers.add_parser(`"masterkey`", help=`"Gerer la Master Key`")`n        mk_sub = p_mk.add_subparsers(dest=`"mk_command`", help=`"Actions Master Key`")`n`n        mk_sub.add_parser(`"status`", help=`"Verifier si la Master Key est initialisee`")`n        mk_init = mk_sub.add_parser(`"init`", help=`"Initialiser la Master Key (creer master_key.json)`")`n        mk_init.add_argument(`"-p`", `"--password`", required=True, help=`"Mot de passe Master Key`")`n        mk_rot = mk_sub.add_parser(`"rotate`", help=`"Changer le mot de passe (re-chiffre la master key)`")`n        mk_rot.add_argument(`"--old`", required=True, help=`"Ancien mot de passe`")`n        mk_rot.add_argument(`"--new`", required=True, help=`"Nouveau mot de passe`")`n"
}

# Injection dispatch dans run()
if($txt -notmatch 'args\.command\s*==\s*"masterkey"'){
  $txt = $txt -replace "(\s*# Dispatch\s*\n)", "`$1"
  $txt = $txt -replace "(if args\.command == `"backup`":\s*\n\s*return int\(self\.core\.backup[^\n]*\)\s*\n)", @"
$1
        if args.command == "masterkey":
            from src.master_key import MasterKeyManager, MasterKeyError
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

"@
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($path, $txt, $utf8NoBom)
Write-Host "OK: masterkey CLI ajouté dans backup_cli.py"
