import re
from pathlib import Path

ALT = Path(__file__).resolve().parents[1] / "altiora.py"
text = ALT.read_text(encoding="utf-8")

# Idempotence
if "last_exit_code" in text and "exit_code = 0 if ok else" in text:
    print("[OK] altiora.py already patched for restore exit codes.")
    raise SystemExit(0)

# Find the restore handler block where ok is assigned
# We target the exact line:
#   ok = bool(core.restore_backup(args.backup, args.output, args.password))
pat_ok = r"(?m)^(?P<indent>\s*)ok\s*=\s*bool\(core\.restore_backup\(args\.backup,\s*args\.output,\s*args\.password\)\)\s*$"
m = re.search(pat_ok, text)
if not m:
    print("[ERR] Cannot find restore ok assignment in altiora.py")
    raise SystemExit(2)

indent = m.group("indent")
insert_pos = m.end(0)

inject = (
    "\n"
    f"{indent}exit_code = 0 if ok else int(getattr(core, \"last_exit_code\", 1) or 1)\n"
)

text = text[:insert_pos] + inject + text[insert_pos:]

# Now replace the two returns in the restore block:
# JSON return: return 0 if ok else 1  -> return exit_code
# Normal return: return 0 if ok else 1 -> return exit_code
# We'll only replace within a window after the ok assignment to avoid touching other commands.
start = m.start(0)
window_end = min(start + 1200, len(text))
window = text[start:window_end]

window2, n_json = re.subn(r"(?m)^\s*return\s+0\s+if\s+ok\s+else\s+1\s*$", "        return exit_code", window, count=1)
# The indentation "        " above might not match; let's do indent-aware replaces instead:
# We'll redo properly: replace the first two occurrences of 'return 0 if ok else 1' after ok assignment with 'return exit_code'
def repl(match):
    return match.group(1) + "return exit_code"

window3, n_all = re.subn(r"(?m)^(\s*)return\s+0\s+if\s+ok\s+else\s+1\s*$", repl, window, count=2)

if n_all == 0:
    print("[ERR] Could not replace restore return statements in window. Aborting.")
    raise SystemExit(2)

new_text = text[:start] + window3 + text[window_end:]

bak = ALT.with_suffix(".py.bak_exitcode101")
bak.write_text(ALT.read_text(encoding="utf-8"), encoding="utf-8")
ALT.write_text(new_text, encoding="utf-8")

print(f"[OK] Patched altiora.py restore returns to use last_exit_code. Backup: {bak}")
