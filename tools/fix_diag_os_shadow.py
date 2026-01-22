import re
from pathlib import Path

ALT = Path(__file__).resolve().parents[1] / "altiora.py"
text = ALT.read_text(encoding="utf-8")

# sécurise : on ne modifie que si on trouve les marqueurs du bloc diag
m_start = text.find("# --- Edition diagnostics")
m_end = text.find("# --- end edition diagnostics ---", m_start)
if m_start == -1 or m_end == -1:
    print("[ERR] Edition diagnostics block markers not found. Aborting.")
    raise SystemExit(2)

block = text[m_start:m_end]

# retire uniquement la ligne 'import os' (avec indentation) dans ce bloc
pattern = r"(?m)^[ \t]*import\s+os\s*\n"
new_block, n = re.subn(pattern, "", block)

if n == 0:
    print("[OK] No local 'import os' in diag block; nothing to change.")
    raise SystemExit(0)

# recompose le fichier
new_text = text[:m_start] + new_block + text[m_end:]

bak = ALT.with_suffix(".py.bak_diag_osfix")
bak.write_text(text, encoding="utf-8")
ALT.write_text(new_text, encoding="utf-8")

print(f"[OK] Removed local 'import os' from diag block. Backup: {bak}")
