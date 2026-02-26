# ABP_ASCII_OUTPUT_V3
# Bytes-only file patcher: replace specific UTF-8 byte sequences and common mojibake with ASCII.
# Targets: altiora.py, src/*.py, tools/test_*.ps1

from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

MARKER = b"ABP_ASCII_OUTPUT_V3"

def replace_all(data: bytes, needle: bytes, repl: bytes) -> tuple[bytes, bool]:
    if needle not in data:
        return data, False
    return data.replace(needle, repl), True

def ensure_marker(path: Path, data: bytes) -> tuple[bytes, bool]:
    if MARKER in data:
        return data, False

    suffix = path.suffix.lower()
    if suffix == ".ps1":
        prefix = b"# " + MARKER + b"\r\n"
        return prefix + data, True

    if suffix == ".py":
        # If shebang, insert after first line; else prepend.
        if data.startswith(b"#!"):
            nl = data.find(b"\n")
            if nl == -1:
                return data + b"\n# " + MARKER + b"\n", True
            return data[: nl + 1] + b"# " + MARKER + b"\n" + data[nl + 1 :], True
        return b"# " + MARKER + b"\n" + data, True

    return data, False

def apply_replacements(data: bytes) -> tuple[bytes, bool]:
    changed = False

    # ASCII tokens
    B_OK     = b"OK"
    B_ERROR  = b"ERROR"
    B_SEARCH = b"SEARCH"
    B_RUN    = b"RUN"
    B_PATH   = b"PATH"
    B_PACK   = b"PACKAGE"
    B_ID     = b"ID"
    B_FILE   = b"FILE"
    B_TIME   = b"TIME"

    rules: list[tuple[bytes, bytes]] = []

    # Accented words (UTF-8 + common mojibake)
    rules += [
        (bytes([0xC3,0x89,0x63,0x68,0x65,0x63]), B_ERROR),  # "Echec" with accented E
        (bytes([0xC3,0x83,0xE2,0x80,0xB0,0x63,0x68,0x65,0x63]), B_ERROR),  # mojibake
        (bytes([0x53,0x75,0x63,0x63,0xC3,0xA8,0x73]), B_OK),  # "Succes" with accent
        (bytes([0x53,0x75,0x63,0x63,0xC3,0x83,0xC2,0xA8,0x73]), B_OK),  # mojibake
    ]

    # Emoji UTF-8 + common mojibake-as-UTF8 bytes seen on Windows consoles
    rules += [
        (bytes([0xE2,0x9C,0x85]), B_OK),                             # check
        (bytes([0xC3,0xA2,0xC2,0x9C,0xC2,0x85]), B_OK),             # mojibake
        (bytes([0xE2,0x9D,0x8C]), B_ERROR),                          # cross
        (bytes([0xC3,0xA2,0xC2,0x9D,0xC2,0x8C]), B_ERROR),          # mojibake
        (bytes([0xF0,0x9F,0x94,0x8D]), B_SEARCH),                    # magnifier
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x94,0xC2,0x8D]), B_SEARCH),# mojibake
        (bytes([0xF0,0x9F,0x9A,0x80]), B_RUN),                       # rocket
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x9A,0xC2,0x80]), B_RUN),  # mojibake
        (bytes([0xF0,0x9F,0x93,0x8D]), B_PATH),                      # pin
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x93,0xC2,0x8D]), B_PATH), # mojibake
        (bytes([0xF0,0x9F,0x93,0xA6]), B_PACK),                      # box
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x93,0xC2,0xA6]), B_PACK), # mojibake
        (bytes([0xF0,0x9F,0x86,0x94]), B_ID),                        # ID
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x86,0xC2,0x94]), B_ID),   # mojibake
        (bytes([0xF0,0x9F,0x93,0x84]), B_FILE),                      # page
        (bytes([0xC3,0xB0,0xC2,0x9F,0xC2,0x93,0xC2,0x84]), B_FILE), # mojibake
        (bytes([0xE2,0x8F,0xB1]), B_TIME),                           # stopwatch
        (bytes([0xC3,0xA2,0xC2,0x8F,0xC2,0xB1]), B_TIME),            # mojibake
    ]

    # Unicode punctuation -> ASCII
    rules += [
        (bytes([0xE2,0x80,0x94]), b"--"),    # em dash
        (bytes([0xE2,0x80,0x93]), b"-"),     # en dash
        (bytes([0xE2,0x80,0xA6]), b"..."),   # ellipsis
        (bytes([0xE2,0x80,0x9C]), b'"'),     # left double quote
        (bytes([0xE2,0x80,0x9D]), b'"'),     # right double quote
        (bytes([0xE2,0x80,0x98]), b"'"),     # left single quote
        (bytes([0xE2,0x80,0x99]), b"'"),     # right single quote
        (bytes([0xC2,0xA0]),      b" "),     # NBSP
        (bytes([0xE2,0x80,0xA2]), b"*"),     # bullet
    ]

    for needle, repl in rules:
        data, did = replace_all(data, needle, repl)
        if did:
            changed = True

    return data, changed

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

    # deterministic order
    return sorted(set(out), key=lambda p: str(p).lower())

def main() -> int:
    targets = iter_targets()
    if not targets:
        print("No target files found.")
        return 0

    patched = 0
    for path in targets:
        orig = path.read_bytes()
        data, ch1 = apply_replacements(orig)
        data, ch2 = ensure_marker(path, data)
        if ch1 or ch2:
            path.write_bytes(data)
            patched += 1
            print(f"Patched: {path}")
        else:
            print(f"NoChange: {path}")

    print(f"Done. Patched files: {patched} / {len(targets)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())