from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_verifyhandler_v5c_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# 1) trouver le bloc verify
start_pat = re.compile(r'^(?P<indent>[ \t]*)if\s+args\.command\s*==\s*"verify"\s*:\s*$', re.M)
m1 = start_pat.search(s)
if not m1:
    raise SystemExit('ERROR: cannot find: if args.command == "verify":')

indent = m1.group("indent")

# 2) borne de fin = prochain bloc restore
end_pat = re.compile(rf'^{re.escape(indent)}if\s+args\.command\s*==\s*"restore"\s*:\s*$', re.M)
m2 = end_pat.search(s, m1.end())
if not m2:
    raise SystemExit('ERROR: cannot find next block: if args.command == "restore":')

# 3) nouveau handler verify
# NOTE: on veut écrire littéralement {args.backup} dans altiora.py => on échappe {{ }}
body = (
    f'{indent}if args.command == "verify":\n'
    f'{indent}    if not args.json:\n'
    f'{indent}        _safe_print(f"➔ Verify : {{args.backup}}")\n'
    f'{indent}        vprint(f"   Backup abs: {{os.path.abspath(args.backup)}}")\n'
    f'{indent}\n'
    f'{indent}    # verify (détaillé, messages propres)\n'
    f'{indent}    try:\n'
    f'{indent}        ok, reason = core.verify_backup_detailed(args.backup, args.password)\n'
    f'{indent}    except Exception:\n'
    f'{indent}        ok = core.verify(args.backup, args.password)\n'
    f'{indent}        reason = None\n'
    f'{indent}\n'
    f'{indent}    if args.json:\n'
    f'{indent}        _emit_json({{"ok": bool(ok), "command": "verify", "backup": args.backup, "reason": reason}})\n'
    f'{indent}        return 0 if ok else 1\n'
    f'{indent}\n'
    f'{indent}    if ok:\n'
    f'{indent}        _safe_print("✅ Vérification OK")\n'
    f'{indent}        return 0\n'
    f'{indent}\n'
    f'{indent}    if reason == "BAD_PASSWORD":\n'
    f'{indent}        _safe_print("❌ Mot de passe incorrect.")\n'
    f'{indent}        return 1\n'
    f'{indent}\n'
    f'{indent}    _safe_print("❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).")\n'
    f'{indent}    return 1\n'
)

s2 = s[:m1.start()] + body + s[m2.start():]
CLI.write_text(s2, encoding="utf-8")

print(f"OK: verify handler replaced (v5c). Backup: {bak}")
