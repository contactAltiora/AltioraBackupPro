import re
from pathlib import Path

LIC = Path(__file__).resolve().parents[1] / "src" / "license_core.py"
text = LIC.read_text(encoding="utf-8")

# Idempotence
if "PUBLIC_KEY_B64_EMBEDDED" in text:
    print("[OK] license_core already supports embedded public key.")
    raise SystemExit(0)

# On remplace la ligne actuelle PUBLIC_KEY_B64 = os.environ.get(...)
pat = r'(?m)^PUBLIC_KEY_B64\s*=\s*os\.environ\.get\("ALTIORA_PUBLIC_KEY_B64",\s*""\)\.strip\(\)\s*$'
m = re.search(pat, text)
if not m:
    print("[ERR] Cannot find PUBLIC_KEY_B64 env line in license_core.py")
    raise SystemExit(2)

replacement = (
    'PUBLIC_KEY_B64_EMBEDDED = ""  # injected at build-time for Pro\\n'
    'PUBLIC_KEY_B64 = (os.environ.get("ALTIORA_PUBLIC_KEY_B64", "").strip()\\n'
    '                 or PUBLIC_KEY_B64_EMBEDDED.strip())\\n'
)

new_text = re.sub(pat, replacement, text, count=1)

bak = LIC.with_suffix(".py.bak_embed")
bak.write_text(text, encoding="utf-8")
LIC.write_text(new_text, encoding="utf-8")

print(f"[OK] Patched license_core.py for embedded key fallback. Backup: {bak}")
