import sys
from pathlib import Path
import inspect

# Ajoute la racine projet (parent de "tools") au sys.path
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from src.backup_core import BackupCore

core = BackupCore()
names = [n for n in dir(core) if not n.startswith("_")]

callables = []
for n in names:
    try:
        v = getattr(core, n)
        if callable(v):
            callables.append(n)
    except Exception:
        pass

print("PUBLIC_CALLABLES=")
for n in sorted(callables):
    try:
        sig = str(inspect.signature(getattr(core, n)))
    except Exception:
        sig = "(signature unavailable)"
    print(f"- {n}{sig}")
