$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$alt  = Join-Path $root "altiora.py"

if(-not (Test-Path $alt)) { throw "ERROR: missing file: $alt" }

function WriteUtf8NoBom([string]$path, [string]$text){
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

# Read
$txt = Get-Content -Path $alt -Raw -Encoding UTF8

# Anchor: the fallback block (8 spaces indent) used when command not handled
$anchor = "`r`n        parser.print_help()`r`n        return 2`r`n"
$pos = $txt.IndexOf($anchor)
if($pos -lt 0){
  throw "ERROR: cannot find fallback help block in altiora.py (parser.print_help / return 2)."
}

# Guard: ensure masterkey branch exists (we insert just before fallback)
$mkAnchor = '        if args.command == "masterkey":'
if($txt.IndexOf($mkAnchor) -lt 0){
  throw "ERROR: cannot find masterkey dispatch anchor in altiora.py."
}

# Inject dispatch handlers before fallback
$inject = @"

        # ------------------------------------------------------------
        # DISPATCH: backup / restore / verify / list / stats
        # ------------------------------------------------------------
        elif args.command == "backup":
            # source/output/password already parsed by argparse
            no_compress = bool(getattr(args, "no_compress", False))
            iterations  = int(getattr(args, "iterations", 300_000))
            ok = core.backup(args.source, args.output, args.password, iterations=iterations, no_compress=no_compress)
            return 0 if ok else 1

        elif args.command == "restore":
            ok = core.restore(args.backup, args.output, args.password)
            return 0 if ok else 1

        elif args.command == "verify":
            ok = core.verify(args.backup, args.password)
            return 0 if ok else 1

        elif args.command == "list":
            items = core.list_backups() if hasattr(core, "list_backups") else []
            if isinstance(items, list):
                for it in items:
                    print(it)
            else:
                print(items)
            return 0

        elif args.command == "stats":
            s = core.stats() if hasattr(core, "stats") else None
            if s is None:
                print("No stats available.")
            else:
                print(s)
            return 0

"@

# Insert
$txt2 = $txt.Insert($pos, $inject)

# Write
WriteUtf8NoBom $alt $txt2
Write-Host "OK: altiora.py dispatch patched."

# Compile check
py -m py_compile $alt
Write-Host "OK: py_compile altiora.py"
