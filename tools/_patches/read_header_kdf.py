import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.backup_core import BackupCore
c = BackupCore()
h = c._read_container_header(r"C:\Test\out.altb")
print("kdf=", h.get("kdf"))
print("salt_b64=", bool(h.get("salt_b64")))
