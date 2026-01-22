import re
from pathlib import Path

SRC = Path(__file__).resolve().parents[1] / "src" / "backup_core.py"
text = SRC.read_text(encoding="utf-8")

# Localise le bloc FREE restore
m = re.search(r"(?s)(#\s*FREE:\s*limitation RESTORE uniquement.*?)(\n\s*magic_len\s*=)", text)
if not m:
    print("[ERR] FREE restore block not found.")
    raise SystemExit(2)

block = m.group(1)

# Idempotence
if "self.last_exit_code = 101" in block:
    print("[OK] FREE block already patched.")
    raise SystemExit(0)

# Patch 1 : FREE_LIMIT normal
block = re.sub(
    r'(?m)^(?P<i>\s*)self\.last_error_code\s*=\s*"FREE_LIMIT"\s*\n(?P=i)return\s+False\s*$',
    r'\g<i>self.last_error_code = "FREE_LIMIT"\n\g<i>self.last_exit_code = 101\n\g<i>return False',
    block,
    count=1
)

# Patch 2 : FREE erreur taille
block = re.sub(
    r'(?s)(RESTAURATION BLOQUÉE — Altiora Backup Free \(erreur taille\).*?\n)(?P<i>\s*)return\s+False\s*$',
    r'\1\g<i>self.last_error_code = "FREE_LIMIT_ERROR"\n\g<i>self.last_exit_code = 101\n\g<i>return False',
    block,
    count=1
)

if "self.last_exit_code = 101" not in block:
    print("[ERR] Injection failed.")
    raise SystemExit(2)

new_text = text[:m.start(1)] + block + text[m.end(1):]

bak = SRC.with_suffix(".py.bak_exit101_fixed")
bak.write_text(text, encoding="utf-8")
SRC.write_text(new_text, encoding="utf-8")

print(f"[OK] exit_code=101 injected correctly. Backup: {bak}")
