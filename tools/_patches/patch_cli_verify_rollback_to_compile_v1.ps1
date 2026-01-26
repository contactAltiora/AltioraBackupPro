$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$cli  = Join-Path $root "altiora.py"
$py   = Join-Path $root "tools\patch_cli_verify_rollback_to_compile_v1.py"
if(-not (Test-Path $cli)) { throw "ERROR: missing file: $cli" }

$pyText = @'
from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_rollback_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# 1) Supprime le bloc injecté s'il existe
#    (commence par "# verify (détaillé, messages propres)" et va jusqu'au prochain "return 1")
pat_injected = re.compile(
    r'^[ \t]*# verify \(détaillé, messages propres\)\r?\n'
    r'(?:^[ \t]*.*\r?\n)*?'
    r'^[ \t]*return 1\r?\n',
    re.M
)
s2, n = pat_injected.subn("", s)

# 2) Re-remplace le handler verify vers une forme simple si on trouve core.verify_backup_detailed
#    On cible le "ok, reason = core.verify_backup_detailed(...)" si présent (au cas où)
pat_detail_line = re.compile(r'^[ \t]*ok,\s*reason\s*=\s*core\.verify_backup_detailed\(.*\)\r?\n', re.M)
s2 = pat_detail_line.sub("        ok = core.verify(args.backup, args.password)\n", s2)

# 3) Si la ligne "return 0 if ok else 1" existe mais provoque l'IndentationError,
#    on la remplace par un return plus simple (même indentation)
pat_ret = re.compile(r'^([ \t]*)return\s+0\s+if\s+ok\s+else\s+1\s*\r?\n', re.M)
s2 = pat_ret.sub(lambda m: f"{m.group(1)}return 0 if ok else 1\n", s2)

CLI.write_text(s2, encoding="utf-8")
print(f"OK: rollback applied (removed_injected_blocks={n}). Backup: {bak}")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8
Set-Location $root
py -X utf8 $py

py -m py_compile .\altiora.py
if($LASTEXITCODE -ne 0){ throw "ERROR: py_compile altiora.py failed (still broken)" }
Write-Host "OK: py_compile altiora.py"
