$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$core = Join-Path $root "src\backup_core.py"
$py   = Join-Path $root "tools\patch_masterkey_verifyclean_v1c.py"

if(-not (Test-Path $core)) { throw "ERROR: missing file: $core" }

$pyText = @'
from pathlib import Path
import re

CORE = Path(r"C:\Dev\AltioraBackupPro\src\backup_core.py")
s = CORE.read_text(encoding="utf-8", errors="strict")

# ------------------------------------------------------------
# 1) Remplacer _derive_data_key_from_password (version BAD_PASSWORD)
# ------------------------------------------------------------
start_anchor = r"def _derive_data_key_from_password("
i = s.find(start_anchor)
if i < 0:
    raise SystemExit("ERROR: cannot find _derive_data_key_from_password anchor")

j = s.find("\ndef ", i + 5)
if j < 0:
    raise SystemExit("ERROR: cannot find next def after helper")

helper_new = '''def _derive_data_key_from_password(password: str, header_salt: bytes) -> bytes:
    """
    V2 (MasterKey): data_key = HKDF(master_key, salt=header_salt)

    Codes d'erreur:
    - RuntimeError("MASTERKEY_NOT_AVAILABLE") : MK absente/import impossible
    - RuntimeError("MASTERKEY_BAD_PASSWORD")  : MK présente mais mot de passe incorrect
    """
    try:
        from .master_key import MasterKeyManager, MasterKeyError, derive_data_key
    except Exception as e:
        raise RuntimeError("MASTERKEY_NOT_AVAILABLE") from e

    mgr = MasterKeyManager()
    if not mgr.exists():
        raise RuntimeError("MASTERKEY_NOT_AVAILABLE")

    try:
        mk = mgr.unlock(password)
    except MasterKeyError as e:
        raise RuntimeError("MASTERKEY_BAD_PASSWORD") from e

    return derive_data_key(mk, header_salt)

'''

s = s[:i] + helper_new + s[j:]

# ------------------------------------------------------------
# 2) Wrap key derivation in verify/restore detailed:
#    key = _derive_data_key_from_password(password, salt)
#    => BAD_PASSWORD -> return (False, "BAD_PASSWORD") (pas de traceback)
# ------------------------------------------------------------
needle = "key = _derive_data_key_from_password(password, salt)"

def wrap(match):
    indent = match.group(1)
    return (
        f"{indent}try:\n"
        f"{indent}    key = _derive_data_key_from_password(password, salt)\n"
        f"{indent}except RuntimeError as e:\n"
        f"{indent}    if str(e) == \"MASTERKEY_BAD_PASSWORD\":\n"
        f"{indent}        return (False, \"BAD_PASSWORD\")\n"
        f"{indent}    raise\n"
    )

s2, n = re.subn(r'^(\s*)' + re.escape(needle) + r'\s*$', wrap, s, flags=re.M)
s = s2

CORE.write_text(s, encoding="utf-8")
print("OK: helper updated -> MASTERKEY_BAD_PASSWORD supported")
print(f"OK: wrapped derive_data_key call(s): {n}")
print("OK: patch_masterkey_verifyclean_v1c applied")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8

Set-Location $root
py -X utf8 $py

py -m py_compile .\src\backup_core.py
Write-Host "OK: py_compile backup_core.py"
