from pathlib import Path
import re, shutil
from datetime import datetime

CLI = Path(r"C:\Dev\AltioraBackupPro\altiora.py")
s = CLI.read_text(encoding="utf-8", errors="strict")

bak = CLI.with_suffix(".py.bak_dispatchfix_" + datetime.now().strftime("%Y%m%d_%H%M%S"))
shutil.copyfile(CLI, bak)

# 1) Trouver le bloc try: args = parser.parse_args()
m_parse = re.search(r'(?m)^(?P<ti>[ \t]*)args\s*=\s*parser\.parse_args\(\)\s*$', s)
if not m_parse:
    raise SystemExit("ERROR: cannot find 'args = parser.parse_args()'")

ti = m_parse.group("ti")  # indentation du try-block (normalement 8 espaces)

# 2) Vérifier qu'on a bien le handler masterkey juste après
# (sinon on refuse de patcher)
window = s[m_parse.end():]
if 'if args.command == "masterkey":' not in window[:2000]:
    raise SystemExit('ERROR: expected masterkey handler near parse_args (layout unexpected)')

# 3) Localiser le fallback help INCONDITIONNEL qui bloque tout
# On cible le premier "parser.print_help(); return 2" au même niveau d'indentation que parse_args
pat_fallback = re.compile(
    rf'(?ms)^' + re.escape(ti) + r'parser\.print_help\(\)\s*\r?\n'
    rf'^' + re.escape(ti) + r'return\s+2\s*\r?\n'
)
m_fallback = pat_fallback.search(s, m_parse.end())
if not m_fallback:
    raise SystemExit("ERROR: cannot find unconditional fallback 'parser.print_help(); return 2' after masterkey block")

# 4) Localiser le "except SystemExit as e:" du try/except global
# Il est généralement indenté à 4 espaces.
m_except = re.search(r'(?m)^    except SystemExit as e:\s*$', s)
if not m_except:
    raise SystemExit("ERROR: cannot find 'except SystemExit as e:' (layout unexpected)")

# 5) Remplacer TOUT le segment [fallback -> juste avant except SystemExit]
# par un garde-fou NON BLOQUANT : help uniquement si aucune commande.
replacement = (
    f"{ti}# --- dispatch fallback (fixed) ---\n"
    f"{ti}# Ne surtout pas retourner ici, sinon backup/verify/restore/list/stats sont inaccessibles.\n"
    f"{ti}if getattr(args, \"command\", None) is None:\n"
    f"{ti}    parser.print_help()\n"
    f"{ti}    return 2\n"
    f"{ti}# --- end fallback ---\n\n"
)

s2 = s[:m_fallback.start()] + replacement + s[m_except.start():]

CLI.write_text(s2, encoding="utf-8")
print(f"OK: dispatch fallback fixed (masterkey no longer blocks other commands). Backup: {bak}")
