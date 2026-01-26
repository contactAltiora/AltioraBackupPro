import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.master_key import MasterKeyManager
m = MasterKeyManager()
print("path=", getattr(m, "path", None) or getattr(m, "_path", None))
print("exists=", m.exists())
