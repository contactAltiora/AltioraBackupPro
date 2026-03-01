# ABP_FIX_INVISIBLE_WHITESPACE_V1
from __future__ import annotations
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

UTF8_BOM = b"\xEF\xBB\xBF"      # also represents U+FEFF in UTF-8
NBSP_UTF8 = b"\xC2\xA0"         # non-breaking space

def iter_targets() -> list[Path]:
    out: list[Path] = []
    # keep it focused: the file that fails + scripts
    out.append(REPO / "altiora.py")
    out.append(REPO / "src" / "backup_cli.py")
    return [p for p in out if p.exists()]

def normalize_indentation_text(text: str) -> str:
    # Remove FEFF anywhere in text
    text = text.replace("\ufeff", "")
    # Replace NBSP with normal space
    text = text.replace("\u00A0", " ")
    # Convert leading tabs to 4 spaces (only at start of line)
    out_lines = []
    for line in text.splitlines(True):
        # preserve newline
        nl = ""
        if line.endswith("\r\n"):
            core, nl = line[:-2], "\r\n"
        elif line.endswith("\n"):
            core, nl = line[:-1], "\n"
        else:
            core = line

        # only touch leading whitespace
        i = 0
        while i < len(core) and core[i] in (" ", "\t"):
            i += 1
        lead = core[:i].replace("\t", " " * 4)
        out_lines.append(lead + core[i:] + nl)
    return "".join(out_lines)

def main() -> int:
    changed_files = 0
    for p in iter_targets():
        b = p.read_bytes()
        b2 = b.replace(UTF8_BOM, b"")   # remove UTF-8 BOM bytes even if in the middle
        b2 = b2.replace(NBSP_UTF8, b" ")# remove NBSP bytes
        if b2 != b:
            p.write_bytes(b2)

        # Now do safe text-level normalization for indentation + U+FEFF if present as char
        # (fallback tolerant decode)
        text = p.read_text(encoding="utf-8", errors="surrogatepass")
        text2 = normalize_indentation_text(text)
        if text2 != text:
            p.write_text(text2, encoding="utf-8", newline="\n")

        if b2 != b or text2 != text:
            changed_files += 1
            print(f"Patched: {p}")
        else:
            print(f"NoChange: {p}")

    print(f"Done. Patched files: {changed_files} / {len(iter_targets())}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())