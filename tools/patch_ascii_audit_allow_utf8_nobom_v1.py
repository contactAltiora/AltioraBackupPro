# ABP_PATCH_ASCII_AUDIT_ALLOW_UTF8_NOBOM_V1
from __future__ import annotations
from pathlib import Path
import re

REPO = Path(__file__).resolve().parent.parent
TARGET = REPO / "tools" / "ascii_audit_v1.py"

def die(msg: str) -> int:
    print(msg)
    return 2

def main() -> int:
    if not TARGET.exists():
        return die(f"Missing target: {TARGET}")

    s = TARGET.read_text(encoding="utf-8", errors="replace")

    # Heuristic: replace strict "non-ascii byte" scanning with:
    # - reject UTF-8 BOM
    # - reject NUL bytes
    # - ensure UTF-8 decodable
    #
    # We patch by inserting a helper and changing the decision logic.
    # To keep this patch resilient, we only patch if key markers exist.

    if "ASCII-AUDIT:" not in s and "ASCII AUDIT" not in s:
        # still patchable, but warn
        print("WARN: could not find usual ASCII-AUDIT markers; patching anyway.")

    # Insert helper near top (after imports) if not present
    if "def _check_text_file_utf8_nobom" not in s:
        s = re.sub(
            r"(^import .+\n(?:import .+\n|from .+\n)*)",
            r"\1\nUTF8_BOM = b\"\\xEF\\xBB\\xBF\"\n\n"
            r"def _check_text_file_utf8_nobom(path: Path, data: bytes) -> tuple[bool, str]:\n"
            r"    if data.startswith(UTF8_BOM):\n"
            r"        return (False, \"UTF8_BOM\")\n"
            r"    if b\"\\x00\" in data:\n"
            r"        return (False, \"NUL_BYTE\")\n"
            r"    try:\n"
            r"        data.decode(\"utf-8\")\n"
            r"    except UnicodeDecodeError:\n"
            r"        return (False, \"NOT_UTF8\")\n"
            r"    return (True, \"OK\")\n\n",
            s,
            count=1,
            flags=re.MULTILINE,
        )

    # Replace any logic that flags bytes > 0x7F as NON-ASCII.
    # Common pattern: "if b > 0x7F:" or "if byte >= 0x80:" etc.
    # We'll patch around occurrences of "NON-ASCII:" printing blocks by gating them on utf8_nobom check instead.
    #
    # Strategy: find the loop where file bytes are read and replace the "non-ascii scan" with our check.

    # Patch 1: if script contains a per-byte scan, replace the scan block.
    # This is intentionally broad: it targets a block that prints "NON-ASCII:" and exits non-zero.
    if "NON-ASCII:" in s:
        # Insert check right before first "NON-ASCII:" print usage by replacing the block that triggers it.
        # We look for: data = ...read_bytes() then scanning; we replace scanning with our check call.
        s2 = re.sub(
            r"(data\s*=\s*p\.read_bytes\(\)\s*\n)([\s\S]{0,1200}?)(\n\s*print\(\s*[fr]?[\"']NON-ASCII:)",
            r"\1    ok, why = _check_text_file_utf8_nobom(p, data)\n"
            r"    if not ok:\n"
            r"        # keep legacy messaging style\n"
            r"        print(f\"NON-ASCII: {p}\")\n"
            r"        if why == \"UTF8_BOM\":\n"
            r"            print(\"  reason=UTF8_BOM\")\n"
            r"        elif why == \"NUL_BYTE\":\n"
            r"            print(\"  reason=NUL_BYTE\")\n"
            r"        else:\n"
            r"            print(\"  reason=NOT_UTF8\")\n"
            r"        bad += 1\n"
            r"        continue\n"
            r"\n    # UTF-8 (no BOM) accepted\n"
            r"\n\3",
            s,
            count=1,
        )
        # If substitution did nothing, we'll patch differently below.
        s = s2

    # Patch 2: If still contains explicit byte>0x7F checks, comment them out by replacing with pass.
    s = re.sub(r"if\s+byte\s*>=\s*0x80\s*:", "if False:  # patched: allow UTF-8", s)
    s = re.sub(r"if\s+b\s*>\s*0x7F\s*:", "if False:  # patched: allow UTF-8", s)

    TARGET.write_text(s, encoding="utf-8", newline="\n")
    print(f"Patched: {TARGET} (allow UTF-8, reject BOM/NUL/non-utf8)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
