# ABP_REMOVE_FEFF_GLOBAL_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

UTF8_BOM = b"\xEF\xBB\xBF"   # also used to encode U+FEFF in UTF-8
NBSP = b"\xC2\xA0"

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

def normalize_text(s: str) -> str:
    # Remove FEFF anywhere, replace NBSP with space
    s = s.replace("\ufeff", "")
    s = s.replace("\u00A0", " ")
    return s

def main() -> int:
    targets = iter_targets()
    if not targets:
        print("No targets.")
        return 0

    patched = 0
    for p in targets:
        before_bytes = p.read_bytes()

        # Remove UTF-8 BOM bytes anywhere (start or injected in file)
        b = before_bytes.replace(UTF8_BOM, b"")
        b = b.replace(NBSP, b" ")

        # Write bytes first if changed
        if b != before_bytes:
            p.write_bytes(b)

        # Now remove FEFF that may exist as a decoded char (if file contains it in other encoding paths)
        # We read back from current bytes.
        text = p.read_text(encoding="utf-8", errors="surrogatepass")
        text2 = normalize_text(text)
        if text2 != text:
            # keep LF; scripts already use CRLF sometimes but PS is fine with LF
            p.write_text(text2, encoding="utf-8", newline="\n")

        did = (b != before_bytes) or (text2 != text)
        if did:
            patched += 1
            print(f"Patched: {p}")
        else:
            print(f"NoChange: {p}")

    print(f"Done. Patched files: {patched} / {len(targets)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())