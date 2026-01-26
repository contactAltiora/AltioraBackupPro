$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$core = Join-Path $root "src\backup_core.py"
$py   = Join-Path $root "tools\patch_masterkey_errorcodes_verifyclean_v1b.py"

if(-not (Test-Path $core)) { throw "ERROR: missing file: $core" }

$pyText = @'
from pathlib import Path
import re

CORE = Path(r"C:\Dev\AltioraBackupPro\src\backup_core.py")
s = CORE.read_text(encoding="utf-8", errors="strict")

# ------------------------------------------------------------
# 1) helper: distinguer NOT_AVAILABLE vs BAD_PASSWORD
# ------------------------------------------------------------
start_anchor = "def _derive_data_key_from_password("
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
# 2) create_backup: fallback PBKDF2 uniquement si NOT_AVAILABLE
#    (si BAD_PASSWORD => on échoue)
# ------------------------------------------------------------
# On patch un motif robuste: except RuntimeError as e: ... if str(e) == "MASTERKEY_NOT_AVAILABLE": ...
# Si ton bloc diffère, on laissera tel quel et on patchera manuellement après.
pat = re.compile(
    r'except RuntimeError as e:\s*\n'
    r'(\s*)if str\(e\) == "MASTERKEY_NOT_AVAILABLE":\s*\n'
    r'(\s*)key = _derive_key\(password, salt, int\(iterations\)\)\s*\n'
    r'(\s*)kdf_mode = "pbkdf2"\s*\n'
    r'(\s*)else:\s*\n'
    r'(\s*)raise\s*\n',
    re.M
)

m = pat.search(s)
if m:
    indent_if   = m.group(1)
    indent_key  = m.group(2)
    indent_mode = m.group(3)
    indent_else = m.group(4)
    indent_raise= m.group(6)
    repl = (
        'except RuntimeError as e:\n'
        f'{indent_if}if str(e) == "MASTERKEY_NOT_AVAILABLE":\n'
        f'{indent_key}key = _derive_key(password, salt, int(iterations))\n'
        f'{indent_mode}kdf_mode = "pbkdf2"\n'
        f'{indent_else}else:\n'
        f'{indent_raise}# MASTERKEY_BAD_PASSWORD => pas de fallback\n'
        f'{indent_raise}raise\n'
    )
    s = s[:m.start()] + repl + s[m.end():]
    msg2 = "OK: create_backup fallback tightened"
else:
    msg2 = "WARN: create_backup RuntimeError fallback block not matched (left unchanged)"

# ------------------------------------------------------------
# 3) verify_backup_detailed: BAD_PASSWORD => (False, "BAD_PASSWORD") sans traceback
# ------------------------------------------------------------
# On remplace l'unique ligne "key = _derive_data_key_from_password(password, salt)"
# par un try/except qui convertit BAD_PASSWORD en raison.
needle = "key = _derive_data_key_from_password(password, salt)"
if needle in s:
    # patch all occurrences (verify + restore detailed)
    def wrap(match):
        indent = match.group(1)
        return (
            f'{indent}try:\n'
            f'{indent}    key = _derive_data_key_from_password(password, salt)\n'
            f'{indent}except RuntimeError as e:\n'
            f'{indent}    if str(e) == "MASTERKEY_BAD_PASSWORD":\n'
            f'{indent}        return (False, "BAD_PASSWORD")\n'
            f'{indent}    raise\n'
        )

    s2, n = re.subn(r'^(\s*)' + re.escape(needle) + r'\s*$', wrap, s, flags=re.M)
    s = s2
    msg3 = f"OK: verify/restore detailed wrapped ({n} occurrence(s))"
else:
    msg3 = "WARN: derive_data_key call not found (left unchanged)"

CORE.write_text(s, encoding="utf-8")
print("OK: helper updated (BAD_PASSWORD vs NOT_AVAILABLE)")
print(msg2)
print(msg3)
print("OK: patch_masterkey_errorcodes_verifyclean_v1b applied")
'@

Set-Content -Path $py -Value $pyText -Encoding UTF8

Set-Location $root
py -X utf8 $py

py -m py_compile .\src\backup_core.py
Write-Host "OK: py_compile backup_core.py"
