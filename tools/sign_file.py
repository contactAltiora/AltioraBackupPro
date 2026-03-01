import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization

if len(sys.argv) != 3:
    print("usage: sign_file.py <private_key.pem> <file>")
    sys.exit(1)

key_path = sys.argv[1]
file_path = sys.argv[2]

with open(key_path, "rb") as f:
    private_key = serialization.load_pem_private_key(
        f.read(),
        password=None
    )

with open(file_path, "rb") as f:
    data = f.read()

signature = private_key.sign(data)

sig_path = file_path + ".sig"

with open(sig_path, "wb") as f:
    f.write(signature)

print("SIGNED:", sig_path)