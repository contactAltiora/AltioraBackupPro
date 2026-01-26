$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_verify_message_v1.py"

if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

# On cible le bloc "ok = core.verify(args.backup, args.password)" dans main()
needle = r"ok\s*=\s*core\.verify\(\s*args\.backup\s*,\s*args\.password\s*\)"
m = re.search(needle, s)
if not m:
    raise SystemExit("ERROR: cannot find core.verify(args.backup, args.password) in altiora.py")

# On remplace UNE occurrence par une version détaillée + messages propres
replacement = """# verify (détaillé, messages propres)
        try:
            ok, reason = core.verify_backup_detailed(args.backup, args.password)
        except Exception:
            ok = core.verify(args.backup, args.password)
            reason = None

        if ok:
            print("✅ Vérification OK")
            return 0

        if reason == "BAD_PASSWORD":
            print("❌ Mot de passe incorrect.")
            return 1

        print("❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).")
        return 1"""

# Important: préserver l'indentation du fichier
# On récupère l'indentation de la ligne trouvée
line_start = s.rfind("\n", 0, m.start()) + 1
indent = re.match(r"[ \t]*", s[line_start:m.start()]).group(0)
replacement_indented = "\n".join(indent + ln if ln.strip() else ln for ln in replacement.splitlines())

s2 = s[:m.start()] + replacement_indented + s[m.end():]
CLI.write_text(s2, encoding="utf-8")
print("OK: patched altiora.py verify -> clean messages + exit codes")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8

Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
Write-Host "OK: py_compile altiora.py"
