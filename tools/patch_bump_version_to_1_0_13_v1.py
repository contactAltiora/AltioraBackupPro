# ABP_BUMP_VERSION_TO_1_0_13_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TARGET = REPO / "altiora.py"

OLD = b"Altiora Backup Pro v1.0.12"
NEW = b"Altiora Backup Pro v1.0.13"

def main() -> int:
    b = TARGET.read_bytes()

    count = b.count(OLD)
    if count == 0:
        print(f"NoChange: {TARGET} (pattern not found)")
        return 0

    b2 = b.replace(OLD, NEW)
    TARGET.write_bytes(b2)
    print(f"Patched: {TARGET} ({count} replacements)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())