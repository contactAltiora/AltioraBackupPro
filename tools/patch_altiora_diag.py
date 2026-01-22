import re
from pathlib import Path

ALT = Path(__file__).resolve().parents[1] / "altiora.py"
text = ALT.read_text(encoding="utf-8")

# Idempotence
if "🧾 Edition: demandée=" in text:
    print("[OK] Edition diag already present; no changes.")
    raise SystemExit(0)

# Capture l'indentation du bloc où on injecte
pattern = r"""
(?P<indent>^[ \t]*)
_safe_print\(f"📍\s*altiora\.py:\s*\{os\.path\.abspath\(__file__\)\}"\)\s*\n
(?P=indent)[ \t]*try:\s*\n
(?P=indent)[ \t]*_safe_print\(f"📍\s*BackupCore:\s*\{backup_core_module\.__file__\}"\)\s*\n
(?P=indent)[ \t]*except\s+Exception:\s*\n
(?P=indent)[ \t]*pass\s*\n
"""
m = re.search(pattern, text, flags=re.VERBOSE | re.MULTILINE)
if not m:
    print("[ERR] Anchor block not found (safe_print BackupCore path).")
    raise SystemExit(2)

indent = m.group("indent")

injection_raw = """\
# --- Edition diagnostics (requested / effective / reason) ---
import os
requested = getattr(backup_core_module, "EDITION_REQUESTED", (os.getenv("ALTIORA_EDITION") or "FREE").strip().upper())
effective = getattr(backup_core_module, "EDITION", "FREE")
reason = getattr(backup_core_module, "EDITION_REASON", getattr(backup_core_module, "EDITION_EFFECTIVE_REASON", "UNKNOWN"))

_show = ((os.getenv("ALTIORA_EDITION") or "").strip().upper() == "PRO") or bool(getattr(args, "verbose", False))
if _show and not json_mode:
    _safe_print(f"🧾 Edition: demandée={requested} • effective={effective} • raison={reason}")

if logger:
    logger.info("Edition diag requested=%s effective=%s reason=%s", requested, effective, reason)
# --- end edition diagnostics ---
"""

# Applique l'indent à chaque ligne (y compris les lignes vides)
injection = "\n".join((indent + line) if line.strip() != "" else "" for line in injection_raw.splitlines()) + "\n"

# Insert juste après le bloc ancre
insert_pos = m.end()
new_text = text[:insert_pos] + injection + text[insert_pos:]

# Backup + write
bak = ALT.with_suffix(".py.bak_diag")
bak.write_text(text, encoding="utf-8")
ALT.write_text(new_text, encoding="utf-8")

print(f"[OK] Patched altiora.py (indent-aware). Backup saved to: {bak}")
