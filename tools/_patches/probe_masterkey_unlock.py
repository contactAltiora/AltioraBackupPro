import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from src.master_key import MasterKeyManager, MasterKeyError

m = MasterKeyManager()
print("exists=", m.exists())
try:
    mk = m.unlock("TON_MDP")
    print("unlock_ok=", True)
    print("mk_len=", len(mk))
except MasterKeyError as e:
    print("unlock_ok=", False)
    print("error=", str(e))
