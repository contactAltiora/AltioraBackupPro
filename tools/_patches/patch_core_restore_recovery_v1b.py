from pathlib import Path

def die(msg: str):
    raise SystemExit("[PATCH_CORE_RESTORE_RECOVERY_V1b] " + msg)

def normalize(text: str) -> str:
    text = text.lstrip("\ufeff").replace("\r\n","\n").replace("\r","\n")
    return text.rstrip() + "\n"

p = Path(r"src/backup_core.py")
t = normalize(p.read_text(encoding="utf-8", errors="ignore"))
lines = t.splitlines(True)

# Find def restore_backup (method or function)
def_idx = None
for i, l in enumerate(lines):
    if l.lstrip().startswith("def restore_backup"):
        def_idx = i
        break
if def_idx is None:
    die("Cannot find def restore_backup(...) in src/backup_core.py")

sig = lines[def_idx]
if ")" not in sig:
    die("restore_backup signature is multi-line; this patcher expects a single-line def.")

# Add params if missing
if "recovery" not in sig and "recovery_key" not in sig:
    sig2 = sig.rstrip("\n")
    sig2 = sig2[:-1] + ", recovery: bool = False, recovery_key: str | None = None)"  # replace final ')'
    lines[def_idx] = sig2 + "\n"

# Locate first real body line to get indentation
body_start = def_idx + 1
while body_start < len(lines) and lines[body_start].strip() == "":
    body_start += 1
if body_start >= len(lines):
    die("Unexpected EOF after restore_backup def")

body_indent = lines[body_start][:len(lines[body_start]) - len(lines[body_start].lstrip(" \t"))]

snippet = (
    body_indent + "# --- Recovery mode support (CLI plumbing) ---\n"
    + body_indent + "password_effective = password\n"
    + body_indent + "if recovery:\n"
    + body_indent + "    if not recovery_key:\n"
    + body_indent + '        print("ERROR: missing recovery key.")\n'
    + body_indent + "        return False\n"
    + body_indent + "    password_effective = recovery_key\n"
)

window = "".join(lines[def_idx:def_idx+120])
if "password_effective" not in window:
    lines.insert(body_start, snippet)

# Replace 'password' usages with 'password_effective' in the early part of the method (bounded)
# Determine block range by indentation
base_ind = lines[def_idx][:len(lines[def_idx]) - len(lines[def_idx].lstrip(" \t"))]
block_end = def_idx + 1
while block_end < len(lines):
    l = lines[block_end]
    if l.strip() == "":
        block_end += 1
        continue
    ind = l[:len(l) - len(l.lstrip(" \t"))]
    if len(ind) <= len(base_ind) and l.lstrip().startswith(("def ","class ")):
        break
    block_end += 1

limit_end = min(def_idx + 180, block_end)
for k in range(def_idx, limit_end):
    lk = lines[k]
    if "password" in lk and "password_effective" not in lk:
        lines[k] = lk.replace("password", "password_effective")

out = normalize("".join(lines))
p.write_text(out, encoding="utf-8")
print("[PATCH_CORE_RESTORE_RECOVERY_V1b] Patch applied to src/backup_core.py")
