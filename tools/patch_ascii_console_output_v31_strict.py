# ABP_ASCII_OUTPUT_V31_STRICT
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

def iter_targets() -> list[Path]:
    out: list[Path] = []
    out.append(REPO / "altiora.py")
    src = REPO / "src"
    if src.exists():
        out += list(src.rglob("*.py"))
    tools = REPO / "tools"
    if tools.exists():
        out += list(tools.glob("test_*.ps1"))
        # also patch release script output (often contains checkmarks)
        rb = tools / "release_build_and_backup.ps1"
        if rb.exists():
            out.append(rb)
        pr = tools / "patch_runner.ps1"
        if pr.exists():
            out.append(pr)
    return sorted(set([p for p in out if p.exists()]), key=lambda p: str(p).lower())

def rep_all(b: bytes, needle: bytes, repl: bytes) -> tuple[bytes, bool]:
    if needle not in b:
        return b, False
    return b.replace(needle, repl), True

def main() -> int:
    # UTF-8 bytes for common offenders
    ARROW_RIGHT = bytes([0xE2,0x86,0x92])         # "→"
    ARROW_HEAVY = bytes([0xE2,0x9E,0x94])         # "➔"
    CHECKMARK   = bytes([0xE2,0x9C,0x85])         # "✅"
    VS16        = bytes([0xEF,0xB8,0x8F])         # variation selector-16 (often makes emoji)

    patched = 0
    targets = iter_targets()
    for p in targets:
        before = p.read_bytes()
        b = before
        changed = False

        # Replace arrows with ASCII
        b, did = rep_all(b, ARROW_RIGHT, b"->"); changed |= did
        b, did = rep_all(b, ARROW_HEAVY, b"->"); changed |= did

        # Replace checkmark with OK
        b, did = rep_all(b, CHECKMARK, b"OK"); changed |= did

        # Remove variation selector (causes "TIME️" etc.)
        b, did = rep_all(b, VS16, b""); changed |= did

        if changed:
            p.write_bytes(b)
            patched += 1
            print(f"Patched: {p}")
        else:
            print(f"NoChange: {p}")

    print(f"Done. Patched files: {patched} / {len(targets)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())