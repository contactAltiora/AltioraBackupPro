# ABP_FIX_ASCII_AUDIT_BAD_ESCAPES_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TARGET = REPO / "tools" / "ascii_audit_v1.py"

def main() -> int:
    if not TARGET.exists():
        print(f"Missing: {TARGET}")
        return 2

    s = TARGET.read_text(encoding="utf-8", errors="replace")

    # Fix the accidental injection of backslash-escaped quotes in Python code:
    #   f\"...\"  -> f"..."
    #   \"        -> "
    # We keep it narrow-ish but robust.
    before = s
    s = s.replace('f\\"', 'f"')
    s = s.replace('\\"', '"')

    if s == before:
        print(f"NoChange: {TARGET} (no bad escapes found)")
    else:
        TARGET.write_text(s, encoding="utf-8", newline="\n")
        print(f"Patched: {TARGET} (removed bad \\\")")

    return 0

if __name__ == "__main__":
    raise SystemExit(main())
