from pathlib import Path

def die(msg: str):
    raise SystemExit("[PATCH_CORE_RESTORE_RECOVERY_V2] " + msg)

def normalize(text: str) -> str:
    text = text.lstrip("\ufeff").replace("\r\n","\n").replace("\r","\n")
    return text.rstrip() + "\n"

p = Path("src/backup_core.py")
t = normalize(p.read_text(encoding="utf-8", errors="ignore"))
lines = t.splitlines(True)

# 1) Locate the def line
def_idx = None
for i, l in enumerate(lines):
    if l.lstrip().startswith("def restore_backup"):
        def_idx = i
        break
if def_idx is None:
    die("Cannot find 'def restore_backup' in src/backup_core.py")

sig = lines[def_idx].rstrip("\n")

# 2) Add keyword params BEFORE the closing ')' of the argument list, without breaking '-> ...:'.
if "recovery" not in sig and "recovery_key" not in sig:
    # find first '('
    open_pos = sig.find("(")
    if open_pos == -1:
        die("Malformed restore_backup signature (no '(').")

    # find matching ')'
    i = open_pos + 1
    depth = 1
    in_str = None
    esc = False
    while i < len(sig) and depth > 0:
        ch = sig[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_str:
                in_str = None
        else:
            if ch in ("'", '"'):
                in_str = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
        i += 1

    if depth != 0:
        die("Unbalanced parentheses in restore_backup signature line.")

    close_pos = i - 1  # index of ')'
    insert = ", recovery: bool = False, recovery_key: str | None = None"
    sig = sig[:close_pos] + insert + sig[close_pos:]
    lines[def_idx] = sig + "\n"

# 3) Insert small recovery logic at start of function body (no global replacements)
# Find first non-empty line after def
body = def_idx + 1
while body < len(lines) and lines[body].strip() == "":
    body += 1
if body >= len(lines):
    die("Unexpected EOF after restore_backup def")

indent = lines[body][:len(lines[body]) - len(lines[body].lstrip(" \t"))]

snippet = (
    indent + "# --- Recovery mode support (CLI plumbing) ---\n"
    + indent + "password_effective = password\n"
    + indent + "if recovery:\n"
    + indent + "    if not recovery_key:\n"
    + indent + '        print("ERROR: missing recovery key.")\n'
    + indent + "        return False\n"
    + indent + "    password_effective = recovery_key\n"
    + indent + "password = password_effective\n"
)

window = "".join(lines[def_idx:def_idx+140])
if "password_effective" not in window:
    # if function has an inner docstring, insert after it
    insert_at = body
    if lines[insert_at].lstrip().startswith(('"""',"'''")):
        q = 0
        quote = '"""' if lines[insert_at].lstrip().startswith('"""') else "'''"
        j = insert_at
        while j < len(lines):
            q += lines[j].count(quote)
            j += 1
            if q >= 2:
                break
        insert_at = j
    lines.insert(insert_at, snippet)

out = normalize("".join(lines))
p.write_text(out, encoding="utf-8")
print("[PATCH_CORE_RESTORE_RECOVERY_V2] Patch applied to src/backup_core.py")
