import base64
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

OUTDIR = Path.home() / ".altiora_backup_pro" / "keys"
OUTDIR.mkdir(parents=True, exist_ok=True)

priv = Ed25519PrivateKey.generate()
pub = priv.public_key()

priv_bytes = priv.private_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PrivateFormat.Raw,
    encryption_algorithm=serialization.NoEncryption(),
)
pub_bytes = pub.public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw,
)

priv_b64 = base64.b64encode(priv_bytes).decode("ascii")
pub_b64 = base64.b64encode(pub_bytes).decode("ascii")

(priv_path := OUTDIR / "ed25519_private_key.b64").write_text(priv_b64, encoding="utf-8")
(pub_path := OUTDIR / "ed25519_public_key.b64").write_text(pub_b64, encoding="utf-8")

print("[OK] Keypair generated.")
print(f"      Private (B64) saved to: {priv_path}")
print(f"      Public  (B64) saved to: {pub_path}")
print(f"      Public  (B64) value   : {pub_b64}")
