$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_verify_message_v3.py"

if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_verifyv3_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# 1) Isoler le bloc du handler verify (if/elif args.command == "verify": ... jusqu'au prochain elif/else)
pat_block = re.compile(
    r'^(?P<hindent>[ \t]*)(?P<head>(?:if|elif)\s+args\.command\s*==\s*[\'"]verify[\'"]\s*:\s*)\r?\n'
    r'(?P<body>(?:(?!^(?P=hindent)(?:elif|else)\b).*\r?\n)*)',
    re.M
)

m = pat_block.search(s)
if not m:
    raise SystemExit("ERROR: cannot find verify handler block")

hindent = m.group("hindent")
head   = m.group("head")
body   = m.group("body")

# 2) Remplacer SEULEMENT les 2 lignes dans le body
#    ok = core.verify(args.backup, args.password)
#    return 0 if ok else 1
pat_two_lines = re.compile(
    r'^(?P<indent>[ \t]*)ok\s*=\s*core\.verify\(\s*args\.backup\s*,\s*args\.password\s*\)\s*\r?\n'
    r'(?P=indent)return\s+0\s+if\s+ok\s+else\s+1\s*\r?\n',
    re.M
)

m2 = pat_two_lines.search(body)
if not m2:
    raise SystemExit("ERROR: cannot find the 2-line verify sequence inside verify handler")

indent = m2.group("indent")

replacement = (
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

body2 = pat_two_lines.sub(replacement, body, count=1)

# 3) Réassembler
new_block = f"{hindent}{head}\n{body2}"
s2 = s[:m.start()] + new_block + s[m.end():]

CLI.write_text(s2, encoding="utf-8")
print(f"OK: verify handler patched safely. Backup: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8
Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed" }
Write-Host "OK: py_compile altiora.py"
