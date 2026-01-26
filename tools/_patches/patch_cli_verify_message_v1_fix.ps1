$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_verify_message_v1_fix.py"

if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re
import shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

# Backup sécurité
bak = CLI.with_suffix(".py.bak_verifyfix_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# Pattern: depuis "ok = core.verify(...)" jusqu'à "return 0 if ok else 1" (inclus)
pat = re.compile(
    r'^(?P<indent>[ \t]*)ok\s*=\s*core\.verify\(\s*args\.backup\s*,\s*args\.password\s*\)\s*\r?\n'
    r'(?:(?P=indent).*\r?\n)*?'
    r'(?P=indent)return\s+0\s+if\s+ok\s+else\s+1\s*\r?\n',
    re.M
)

m = pat.search(s)
if not m:
    raise SystemExit("ERROR: cannot find the verify block (ok = core.verify ... return 0 if ok else 1)")

indent = m.group("indent")

new_block = (
    f"{indent}# verify (détaillé, messages propres)\n"
    f"{indent}try:\n"
    f"{indent}    ok, reason = core.verify_backup_detailed(args.backup, args.password)\n"
    f"{indent}except Exception:\n"
    f"{indent}    ok = core.verify(args.backup, args.password)\n"
    f"{indent}    reason = None\n"
    f"{indent}\n"
    f"{indent}if ok:\n"
    f"{indent}    print(\"✅ Vérification OK\")\n"
    f"{indent}    return 0\n"
    f"{indent}\n"
    f"{indent}if reason == \"BAD_PASSWORD\":\n"
    f"{indent}    print(\"❌ Mot de passe incorrect.\")\n"
    f"{indent}    return 1\n"
    f"{indent}\n"
    f"{indent}print(\"❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).\")\n"
    f"{indent}return 1\n"
)

s2 = s[:m.start()] + new_block + s[m.end():]
CLI.write_text(s2, encoding="utf-8")
print(f"OK: verify block replaced cleanly. Backup saved: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8

Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed" }
Write-Host "OK: py_compile altiora.py"
