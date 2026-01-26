import sys
from pathlib import Path
from getpass import getpass

# Ajoute la racine projet (parent de "tools") au sys.path
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.master_key import MasterKeyManager

pwd = getpass("Mot de passe Master Key (ne s'affiche pas): ")
mgr = MasterKeyManager()
path = mgr.init(pwd)
print(path)
