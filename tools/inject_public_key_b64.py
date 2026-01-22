import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    print("Usage: inject_public_key_b64.py <PUBLIC_KEY_B64>")
    raise SystemExit(2)

key_b64 = sys.argv[1].strip()
if not key_b64:
    print("[ERR] Empty key.")
    raise SystemExit(2)

LIC = Path(__file__).resolve().parents[1] / "src" / "license_core.py"
text = LIC.read_text(encoding="utf-8")

pat = r'(?m)^PUBLIC_KEY_B64_EMBEDDED\s*=\s*".*"\s*# injected at build-time for Pro\s*$'
m = re.search(pat, text)
if not m:
    print("[ERR] PUBLIC_KEY_B64_EMBEDDED line not found. Run patch_license_core_embed_key.py first.")
    raise SystemExit(2)

new_line = f'PUBLIC_KEY_B64_EMBEDDED = "{key_b64}"  # injected at build-time for Pro'
new_text = re.sub(pat, new_line, text, count=1)

bak = LIC.with_suffix(".py.bak_keyinject")
bak.write_text(text, encoding="utf-8")
LIC.write_text(new_text, encoding="utf-8")

print(f"[OK] Injected public key B64. Backup: {bak}")
