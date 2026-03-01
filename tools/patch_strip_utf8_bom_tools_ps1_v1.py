# ABP_STRIP_UTF8_BOM_TOOLS_PS1_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOOLS = REPO / "tools"
UTF8_BOM = b"\xEF\xBB\xBF"

def main() -> int:
    if not TOOLS.exists():
        print("No tools/ directory.")
        return 0

    patched = 0
    total = 0

    for p in sorted(TOOLS.rglob("*.ps1")):
        total += 1
        data = p.read_bytes()
        if data.startswith(UTF8_BOM):
            p.write_bytes(data[len(UTF8_BOM):])
            patched += 1
            print(f"Patched: {p}")
        else:
            print(f"NoBOM:   {p}")

    print(f"Done. BOM stripped (tools/*.ps1): {patched} / {total}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
