# ABP_STRIP_UTF8_BOM_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
UTF8_BOM = b"\xEF\xBB\xBF"

def iter_targets() -> list[Path]:
    out: list[Path] = []
    altiora = REPO / "altiora.py"
    if altiora.exists():
        out.append(altiora)

    src = REPO / "src"
    if src.exists():
        out += list(src.rglob("*.py"))

    tools = REPO / "tools"
    if tools.exists():
        out += list(tools.glob("test_*.ps1"))

    return sorted(set(out), key=lambda p: str(p).lower())

def main() -> int:
    targets = iter_targets()
    if not targets:
        print("No targets.")
        return 0

    stripped = 0
    for p in targets:
        b = p.read_bytes()
        if b.startswith(UTF8_BOM):
            p.write_bytes(b[len(UTF8_BOM):])
            stripped += 1
            print(f"StrippedBOM: {p}")
        else:
            print(f"NoBOM: {p}")

    print(f"Done. BOM stripped: {stripped} / {len(targets)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())