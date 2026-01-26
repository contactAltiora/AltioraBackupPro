$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_verify_message_v2.py"
if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_verifyv2_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

pat = re.compile(
    r'^(?P<hindent>[ \t]*)(?P<head>(?:if|elif)\s+args\.command\s*==\s*[\'"]verify[\'"]\s*:\s*)\r?\n'
    r'(?P<bindent>[ \t]+)(?P<body>(?:.*\r?\n)*?)(?=^(?P=hindent)(?:elif|else|return|print|if)\b|^\S|\Z)',
    re.M
)

m = pat.search(s)
if not m:
    raise SystemExit("ERROR: cannot find a handler block: if/elif args.command == 'verify'")

hindent = m.group("hindent")
bindent = m.group("bindent")

new_body = (
    f"{bindent}# verify (détaillé, messages propres)\n"
    f"{bindent}try:\n"
    f"{bindent}    ok, reason = core.verify_backup_detailed(args.backup, args.password)\n"
    f"{bindent}except Exception:\n"
    f"{bindent}    ok = core.verify(args.backup, args.password)\n"
    f"{bindent}    reason = None\n"
    f"{bindent}\n"
    f"{bindent}if ok:\n"
    f"{bindent}    print(\"✅ Vérification OK\")\n"
    f"{bindent}    return 0\n"
    f"{bindent}\n"
    f"{bindent}if reason == \"BAD_PASSWORD\":\n"
    f"{bindent}    print(\"❌ Mot de passe incorrect.\")\n"
    f"{bindent}    return 1\n"
    f"{bindent}\n"
    f"{bindent}print(\"❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).\")\n"
    f"{bindent}return 1\n"
)

s2 = s[:m.start()] + f"{hindent}{m.group('head')}\n" + new_body + s[m.end():]
CLI.write_text(s2, encoding="utf-8")
print(f"OK: verify handler replaced. Backup: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8
Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed" }
Write-Host "OK: py_compile altiora.py"
