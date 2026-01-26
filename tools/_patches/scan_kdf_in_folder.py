import sys, json, base64
from pathlib import Path

folder = Path(r"C:\Test")
files = sorted(folder.rglob("*.altb"))
print("found_altb=", len(files))

for f in files:
    try:
        # header = 4 bytes len + json (adapte si ton format diffère)
        data = f.read_bytes()
        n = int.from_bytes(data[:4], "big")
        hdr = json.loads(data[4:4+n].decode("utf-8"))
        print(f.name, "kdf=", hdr.get("kdf"))
    except Exception as e:
        print(f.name, "ERR", e)
