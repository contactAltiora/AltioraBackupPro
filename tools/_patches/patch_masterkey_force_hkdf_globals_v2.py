from pathlib import Path
import re

MK = Path(r"C:\Dev\AltioraBackupPro\src\master_key.py")
s = MK.read_text(encoding="utf-8", errors="strict")
lines = s.splitlines(True)

# remove any existing hkdf/hashes import lines (any indentation)
pat_drop  = re.compile(r'^\s*from\s+cryptography\.hazmat\.primitives\.kdf\.hkdf\s+import\s+HKDF\s*$', re.I)
pat_drop2 = re.compile(r'^\s*from\s+cryptography\.hazmat\.primitives\s+import\s+hashes\s*$', re.I)

new_lines = []
dropped = 0
for ln in lines:
    if pat_drop.match(ln.rstrip("\r\n")) or pat_drop2.match(ln.rstrip("\r\n")):
        dropped += 1
        continue
    new_lines.append(ln)
lines = new_lines

# find insertion point: before first top-level 'class ' or 'def ' (col 0)
insert_at = None
for i, ln in enumerate(lines):
    if ln.startswith("class ") or ln.startswith("def "):
        insert_at = i
        break
if insert_at is None:
    insert_at = len(lines)

ins = [
    "from cryptography.hazmat.primitives.kdf.hkdf import HKDF\n",
    "from cryptography.hazmat.primitives import hashes\n",
    "\n",
]

joined = "".join(lines[:insert_at])
if "from cryptography.hazmat.primitives.kdf.hkdf import HKDF" not in joined:
    lines[insert_at:insert_at] = ins

MK.write_text("".join(lines), encoding="utf-8")
print(f"OK: forced HKDF/hashes at module scope (dropped={dropped})")
