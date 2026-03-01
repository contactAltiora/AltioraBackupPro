# ABP_PATCH_REWRITE_ASCII_AUDIT_UTF8_NOBOM_V2_FIX
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TARGET = REPO / "tools" / "ascii_audit_v1.py"

AUDIT = r"""# ASCII/UTF8 audit
# Policy:
# - Accept UTF-8 text files WITHOUT BOM
# - Reject UTF-8 BOM
# - Reject NUL bytes
# - Reject non-UTF8 (undecodable) files
#
# Exit codes:
#   0 = PASS
#   2 = FAIL

from __future__ import annotations

from pathlib import Path
from dataclasses import dataclass

REPO = Path(__file__).resolve().parent.parent
UTF8_BOM = b"\xEF\xBB\xBF"


@dataclass(frozen=True)
class BadFile:
    path: Path
    reason: str
    offset: int | None = None
    byte: int | None = None
    ctx: bytes | None = None


def _ctx_bytes(data: bytes, at: int, radius: int = 16) -> bytes:
    lo = max(0, at - radius)
    hi = min(len(data), at + radius)
    return data[lo:hi]


def _check_file(path: Path) -> BadFile | None:
    data = path.read_bytes()

    if data.startswith(UTF8_BOM):
        return BadFile(path=path, reason="UTF8_BOM", offset=0, byte=data[0], ctx=_ctx_bytes(data, 0))

    nul = data.find(b"\x00")
    if nul != -1:
        return BadFile(path=path, reason="NUL_BYTE", offset=nul, byte=0x00, ctx=_ctx_bytes(data, nul))

    try:
        data.decode("utf-8")
    except UnicodeDecodeError as e:
        off = int(getattr(e, "start", 0) or 0)
        b = data[off] if 0 <= off < len(data) else None
        return BadFile(path=path, reason="NOT_UTF8", offset=off, byte=b, ctx=_ctx_bytes(data, off))

    return None


def _iter_targets() -> list[Path]:
    targets: list[Path] = []

    # root python entry
    if (REPO / "altiora.py").exists():
        targets.append(REPO / "altiora.py")

    # python sources
    src = REPO / "src"
    if src.exists():
        targets.extend(src.rglob("*.py"))

    tools = REPO / "tools"
    if tools.exists():
        targets.extend(tools.rglob("*.py"))

        # include all .ps1 in tools/ (recursive)
        targets.extend(tools.rglob("*.ps1"))

    # de-dup & sort
    return sorted({p.resolve() for p in targets})


def main() -> int:
    bad: list[BadFile] = []
    targets = _iter_targets()

    for p in targets:
        try:
            b = _check_file(p)
        except Exception as e:
            bad.append(BadFile(path=p, reason=f"READ_ERROR:{type(e).__name__}"))
            continue
        if b is not None:
            bad.append(b)

    if bad:
        for b in bad[:200]:
            print(f"NON-ASCII: {b.path}")
            print(f"  reason={b.reason}")
            if b.offset is not None and b.byte is not None:
                print(f"  offset={b.offset} byte=0x{b.byte:02X}")
            if b.ctx is not None:
                print("  ctx=" + " ".join(f"{x:02X}" for x in b.ctx))
        print(f"UTF8-NOBOM-AUDIT: FAIL ({len(bad)} file(s) bad) scanned={len(targets)}")
        return 2

    print(f"UTF8-NOBOM-AUDIT: PASS scanned={len(targets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
"""

def main() -> int:
    if not TARGET.parent.exists():
        print(f"Missing tools dir: {TARGET.parent}")
        return 2
    TARGET.write_text(AUDIT, encoding="utf-8", newline="\n")
    print(f"Patched: {TARGET} (rewritten audit, UTF-8 no BOM policy)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
