from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_verifyv6_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# 1) Isoler le bloc verify existant (de if verify à juste avant if restore)
start_pat = re.compile(r'^(?P<indent>[ \t]*)if\s+args\.command\s*==\s*"verify"\s*:\s*$', re.M)
m1 = start_pat.search(s)
if not m1:
    raise SystemExit('ERROR: cannot find: if args.command == "verify":')

indent = m1.group("indent")

end_pat = re.compile(rf'^{re.escape(indent)}if\s+args\.command\s*==\s*"restore"\s*:\s*$', re.M)
m2 = end_pat.search(s, m1.end())
if not m2:
    raise SystemExit('ERROR: cannot find next block: if args.command == "restore":')

verify_block = s[m1.start():m2.start()]

# 2) Dans ce bloc, on remplace la séquence:
#    try: ok = _call_verify(...) ... et le return final, par une version détaillée + messages propres
pat_call = re.compile(
    r'^[ \t]*try:\s*\r?\n'
    r'(?:^[ \t]*.*\r?\n)*?'
    r'^[ \t]*ok\s*=\s*_call_verify\(\s*core\s*,\s*args\.backup\s*,\s*args\.password\s*\)\s*\r?\n'
    r'(?:^[ \t]*.*\r?\n)*?'
    r'^[ \t]*return\s+0\s+if\s+ok\s+else\s+1\s*\r?\n',
    re.M
)

mcall = pat_call.search(verify_block)
if not mcall:
    # fallback: on cible juste la ligne ok = _call_verify(...) puis on injecte une fin propre
    line_pat = re.compile(r'^(?P<i>[ \t]*)ok\s*=\s*_call_verify\(\s*core\s*,\s*args\.backup\s*,\s*args\.password\s*\)\s*$', re.M)
    ml = line_pat.search(verify_block)
    if not ml:
        raise SystemExit("ERROR: cannot find _call_verify(...) inside verify handler (unexpected CLI layout)")

    i2 = ml.group("i")
    replacement = (
        f"{i2}# verify (détaillé, messages propres)\n"
        f"{i2}try:\n"
        f"{i2}    ok, reason = core.verify_backup_detailed(args.backup, args.password)\n"
        f"{i2}except Exception:\n"
        f"{i2}    ok = _call_verify(core, args.backup, args.password)\n"
        f"{i2}    reason = None\n"
        f"{i2}\n"
        f"{i2}if args.json:\n"
        f"{i2}    _emit_json({{'ok': bool(ok), 'command': 'verify', 'backup': args.backup, 'reason': reason}})\n"
        f"{i2}    return 0 if ok else 1\n"
        f"{i2}\n"
        f"{i2}if ok:\n"
        f"{i2}    _safe_print('✅ Vérification OK')\n"
        f"{i2}    return 0\n"
        f"{i2}\n"
        f"{i2}if reason == 'BAD_PASSWORD':\n"
        f"{i2}    _safe_print('❌ Mot de passe incorrect.')\n"
        f"{i2}    return 1\n"
        f"{i2}\n"
        f"{i2}_safe_print('❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).')\n"
        f"{i2}return 1\n"
    )

    # Remplacer la ligne ok = _call_verify(...) par replacement + supprimer tout "return 0 if ok else 1" restant
    verify_block2 = line_pat.sub(replacement, verify_block, count=1)
    verify_block2 = re.sub(r'^[ \t]*return\s+0\s+if\s+ok\s+else\s+1\s*\r?\n', '', verify_block2, flags=re.M)
else:
    # remplacement direct du bloc try..return
    # Indentation interne = indent + 4 espaces (niveau du handler)
    i2 = indent + "    "
    replacement = (
        f"{i2}# verify (détaillé, messages propres)\n"
        f"{i2}try:\n"
        f"{i2}    ok, reason = core.verify_backup_detailed(args.backup, args.password)\n"
        f"{i2}except Exception:\n"
        f"{i2}    ok = _call_verify(core, args.backup, args.password)\n"
        f"{i2}    reason = None\n"
        f"{i2}\n"
        f"{i2}if args.json:\n"
        f"{i2}    _emit_json({{'ok': bool(ok), 'command': 'verify', 'backup': args.backup, 'reason': reason}})\n"
        f"{i2}    return 0 if ok else 1\n"
        f"{i2}\n"
        f"{i2}if ok:\n"
        f"{i2}    _safe_print('✅ Vérification OK')\n"
        f"{i2}    return 0\n"
        f"{i2}\n"
        f"{i2}if reason == 'BAD_PASSWORD':\n"
        f"{i2}    _safe_print('❌ Mot de passe incorrect.')\n"
        f"{i2}    return 1\n"
        f"{i2}\n"
        f"{i2}_safe_print('❌ Vérification échouée (backup corrompu, incompatible, ou mot de passe incorrect).')\n"
        f"{i2}return 1\n"
    )
    verify_block2 = verify_block[:mcall.start()] + replacement + verify_block[mcall.end():]

# 3) Réassembler fichier
s2 = s[:m1.start()] + verify_block2 + s[m2.start():]
CLI.write_text(s2, encoding="utf-8")

print(f"OK: verify handler patched (v6). Backup: {bak}")
