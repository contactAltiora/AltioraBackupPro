import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.hazmat.primitives import serialization

if len(sys.argv) != 3:
    print("usage: verify_signature.py <public_key.pem> <file>")
    sys.exit(1)

pub_path = sys.argv[1]
file_path = sys.argv[2]
sig_path = file_path + ".sig"

with open(pub_path, "rb") as f:
    public_key = serialization.load_pem_public_key(f.read())

with open(file_path, "rb") as f:
    data = f.read()

with open(sig_path, "rb") as f:
    signature = f.read()

try:
    public_key.verify(signature, data)
    print("SIGNATURE VALID")
    sys.exit(0)
except Exception:
    print("SIGNATURE INVALID")
    sys.exit(1)