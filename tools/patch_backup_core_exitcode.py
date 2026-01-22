import re
from pathlib import Path

BC = Path(__file__).resolve().parents[1] / "src" / "backup_core.py"
text = BC.read_text(encoding="utf-8")

# Idempotence
if "last_exit_code" in text and "FREE_EXIT_CODE" in text:
    print("[OK] backup_core already patched (last_exit_code present).")
    raise SystemExit(0)

# We rely on the exact banner line that exists in your output
BANNER = "❌ RESTAURATION BLOQUÉE — Altiora Backup Free"
if BANNER not in text:
    print("[ERR] Cannot find Free-limit banner in src/backup_core.py. Aborting.")
    raise SystemExit(2)

# 1) Define constants near FREE_RESTORE_LIMIT_BYTES if present, otherwise near top.
# We'll inject a constant FREE_EXIT_CODE=101 once.
if "FREE_EXIT_CODE" not in text:
    # Try to place it right after FREE_RESTORE_LIMIT_BYTES definition
    m = re.search(r"(?m)^(FREE_RESTORE_LIMIT_BYTES\s*=\s*.+)$", text)
    if m:
        insert_at = m.end(1)
        text = text[:insert_at] + "\nFREE_EXIT_CODE = 101\n" + text[insert_at:]
    else:
        # fallback: after imports block
        m2 = re.search(r"(?s)\A(.*?\n)\n", text)
        if not m2:
            print("[ERR] Cannot locate safe insertion point for FREE_EXIT_CODE.")
            raise SystemExit(2)
        insert_at = m2.end(1)
        text = text[:insert_at] + "FREE_EXIT_CODE = 101\n\n" + text[insert_at:]

# 2) Add reset of self.last_exit_code at the start of restore_backup
# Find def restore_backup
m_def = re.search(r"(?m)^(\s*)def\s+restore_backup\s*\(.*\)\s*:\s*$", text)
if not m_def:
    print("[ERR] Cannot find def restore_backup(...) in src/backup_core.py")
    raise SystemExit(2)

base_indent = m_def.group(1)
body_indent = base_indent + " " * 4

# Inject reset right after the def line (and possible docstring start handled simply)
pos = m_def.end(0)
# Insert after next newline
nl = text.find("\n", pos)
if nl == -1:
    print("[ERR] Unexpected file structure after restore_backup def.")
    raise SystemExit(2)
nl += 1

reset_block = (
    f"{body_indent}# --- exit code propagation (used by altiora.py) ---\n"
    f"{body_indent}self.last_exit_code = 0\n"
    f"{body_indent}# --- end exit code propagation ---\n"
)

# Avoid double insert if already there
if "self.last_exit_code" not in text[nl:nl+400]:
    text = text[:nl] + reset_block + text[nl:]

# 3) In the FREE limit banner section, set last_exit_code = FREE_EXIT_CODE just before returning False
# We locate the banner print line and insert assignment above the nearest 'return False' in the following lines.
lines = text.splitlines(True)
idx = None
for i, ln in enumerate(lines):
    if BANNER in ln:
        idx = i
        break
if idx is None:
    print("[ERR] Banner not found after split (unexpected).")
    raise SystemExit(2)

# Find the next 'return False' after the banner within a reasonable window
ret_idx = None
for j in range(idx, min(idx + 80, len(lines))):
    if re.search(r"(?m)^\s*return\s+False\s*$", lines[j]):
        ret_idx = j
        break
if ret_idx is None:
    print("[ERR] Cannot find 'return False' after FREE banner. Aborting.")
    raise SystemExit(2)

# Determine indentation of return line
m_ret = re.match(r"^(\s*)return\s+False\s*$", lines[ret_idx])
ret_indent = m_ret.group(1) if m_ret else body_indent

assign_line = f"{ret_indent}self.last_exit_code = FREE_EXIT_CODE\n"
# Insert only if not already present in the few lines above
window = "".join(lines[max(idx, ret_idx-5):ret_idx+1])
if "self.last_exit_code" not in window:
    lines.insert(ret_idx, assign_line)

new_text = "".join(lines)

bak = BC.with_suffix(".py.bak_exitcode101")
bak.write_text(BC.read_text(encoding="utf-8"), encoding="utf-8")
BC.write_text(new_text, encoding="utf-8")

print(f"[OK] Patched backup_core.py (last_exit_code + FREE_EXIT_CODE). Backup: {bak}")
