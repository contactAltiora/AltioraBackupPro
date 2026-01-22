import base64
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

def canonical_payload(lic: Dict[str, Any]) -> bytes:
    unsigned = dict(lic)
    unsigned.pop("signature_b64", None)
    unsigned.pop("signature", None)
    return json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")

if len(sys.argv) < 3:
    print("Usage: make_license_json.py <PRIVATE_KEY_B64_FILE> <OUTPUT_LICENSE_JSON> [EXPIRES_AT]")
    print("  EXPIRES_AT examples: 2026-12-31  OR  2026-12-31T23:59:59Z")
    raise SystemExit(2)

priv_file = Path(sys.argv[1]).expanduser()
out_file = Path(sys.argv[2]).expanduser()
expires_at = sys.argv[3] if len(sys.argv) >= 4 else None

priv_b64 = priv_file.read_text(encoding="utf-8").strip()
priv_raw = base64.b64decode(priv_b64)
priv = Ed25519PrivateKey.from_private_bytes(priv_raw)

lic: Dict[str, Any] = {
    "product": "ALTIORA_BACKUP_PRO",
    "edition": "PRO",
    "issued_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
}

if expires_at:
    lic["expires_at"] = expires_at

payload = canonical_payload(lic)
sig = priv.sign(payload)
lic["signature_b64"] = base64.b64encode(sig).decode("ascii")

out_file.parent.mkdir(parents=True, exist_ok=True)
out_file.write_text(json.dumps(lic, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("[OK] license.json generated and signed.")
print(f"      Output: {out_file}")
