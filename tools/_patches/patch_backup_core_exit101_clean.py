import re
from pathlib import Path

BC = Path(__file__).resolve().parents[1] / "src" / "backup_core.py"
text = BC.read_text(encoding="utf-8")

# Idempotence
if "self.last_exit_code = 101" in text:
    print("[OK] backup_core.py already sets last_exit_code=101 (idempotent).")
    raise SystemExit(0)

# On cible le bloc FREE restore limit déjà présent
# Repère: self.last_error_code = "FREE_LIMIT" puis return False
pat = r'(self\.last_error_code\s*=\s*"FREE_LIMIT"\s*\n)([ \t]*return\s+False\s*\n)'
m = re.search(pat, text)
if not m:
    print("[ERR] Cannot find FREE_LIMIT block to patch (pattern not found).")
    raise SystemExit(2)

insert = m.group(1) + '                    self.last_exit_code = 101\n' + m.group(2)
new_text = re.sub(pat, insert, text, count=1)

bak = BC.with_suffix(".py.bak_exit101_clean")
bak.write_text(text, encoding="utf-8")
BC.write_text(new_text, encoding="utf-8")

print(f"[OK] Patched backup_core.py (clean) to set last_exit_code=101. Backup: {bak}")
