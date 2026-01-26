$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_dispatch_cmdfix_v4.py"
if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_cmdfixv4_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# Anchor: juste après parse_args()
anchor = re.search(r'^\s*args\s*=\s*parser\.parse_args\(\)\s*$', s, flags=re.M)
if not anchor:
    raise SystemExit("ERROR: cannot find 'args = parser.parse_args()'")

insert_at = anchor.end()

injection = r'''
# --- cmd dispatch hardening (v4) ---
cmd = getattr(args, "command", None)
if cmd is None:
    for _k in ("cmd", "subcommand", "action"):
        cmd = getattr(args, _k, None)
        if cmd is not None:
            break
# argparse pattern: set_defaults(func=...)
func = getattr(args, "func", None)
# -----------------------------------
'''

# Injecter seulement si pas déjà présent
if "cmd dispatch hardening (v4)" in s:
    raise SystemExit("ERROR: cmdfix v4 already applied")

s2 = s[:insert_at] + "\n" + injection + "\n" + s[insert_at:]
CLI.write_text(s2, encoding="utf-8")
print(f"OK: injected cmd dispatch hardening v4. Backup: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8
Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed" }
Write-Host "OK: py_compile altiora.py"
