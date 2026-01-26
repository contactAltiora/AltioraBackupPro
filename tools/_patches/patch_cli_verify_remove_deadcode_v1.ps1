$ErrorActionPreference = "Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

$cli = Join-Path $root "altiora.py"
$py  = Join-Path $root "tools\patch_cli_verify_remove_deadcode_v1.py"
if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_verify_deadcode_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# On supprime l'ancien bloc verify résiduel: commence après "return 1" (nouveau handler)
# et va jusqu'à juste avant "if args.command == \"restore\":"
pat = re.compile(
    r'(?ms)'
    r'(^[ \t]*if args\.command == "verify":.*?^[ \t]*return 1[ \t]*\r?\n)'   # fin du nouveau handler
    r'(?:^[ \t]*if ok:.*?^[ \t]*return 1[ \t]*\r?\n)+'                      # ancien bloc(s) résiduel(s)
    r'(?=^[ \t]*if args\.command == "restore":)',                            # stop
    re.M
)

m = pat.search(s)
if not m:
    raise SystemExit("ERROR: dead verify block not found (maybe already cleaned)")

keep = m.group(1)
s2 = s[:m.start()] + keep + s[m.end():]

CLI.write_text(s2, encoding="utf-8")
print(f"OK: removed dead verify code. Backup: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8
py -X utf8 $py
py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed" }
Write-Host "OK: py_compile altiora.py (deadcode removed)"
