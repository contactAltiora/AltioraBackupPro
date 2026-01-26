from pathlib import Path

def die(msg: str):
    raise SystemExit("[PATCH_RECOVERY_PASSWORD_OPTIONAL_V1] " + msg)

def normalize(text: str) -> str:
    text = text.lstrip("\ufeff").replace("\r\n","\n").replace("\r","\n")
    return text.rstrip() + "\n"

p = Path("altiora.py")
t = normalize(p.read_text(encoding="utf-8", errors="ignore"))
lines = t.splitlines(True)

# --- 1) Make restore password optional (remove required=True on the restore password argument line) ---
changed_pwd = 0
for i, l in enumerate(lines):
    if 'add_argument' in l and '--password' in l and ('-p' in l or '"-p"' in l or "'-p'" in l):
        # Only adjust if it looks like the restore password arg line
        # Remove "required=True" safely (with/without comma)
        nl = l.replace("required=True,", "").replace("required=True", "")
        if nl != l:
            lines[i] = nl
            changed_pwd += 1

if changed_pwd == 0:
    # It might already be optional; that's fine, but we still validate runtime.
    pass

t = "".join(lines)

# --- 2) Runtime validation: if not recovery, require password ---
# Insert just before the first core.restore_backup(...) call
marker = "core.restore_backup("
pos = t.find(marker)
if pos == -1:
    die("Cannot find core.restore_backup( call.")

# Find line start for insertion
line_start = t.rfind("\n", 0, pos) + 1
indent = ""
# compute indentation from that line
j = line_start
while j < len(t) and t[j] in (" ", "\t"):
    indent += t[j]
    j += 1

guard = (
    indent + "if (not args.recovery) and (not args.password):\n"
    + indent + "    print(\"ERROR: missing password. Use -p/--password OR --recovery.\")\n"
    + indent + "    return 2\n"
)

if guard.strip() not in t:
    t = t[:line_start] + guard + t[line_start:]

# --- 3) Ensure restore_backup receives a string password (avoid None) ---
# Replace the first occurrence of args.password in the restore call with (args.password or "")
# but only in the restore_backup call segment.
pos = t.find(marker)
call_end = t.find(")", pos)
if call_end == -1:
    die("Cannot find end of restore_backup call.")
segment = t[pos:call_end+1]
if "args.password" in segment and "(args.password or" not in segment:
    segment2 = segment.replace("args.password", '(args.password or "")', 1)
    t = t[:pos] + segment2 + t[call_end+1:]

p.write_text(normalize(t), encoding="utf-8")
print("[PATCH_RECOVERY_PASSWORD_OPTIONAL_V1] Patch applied.")
