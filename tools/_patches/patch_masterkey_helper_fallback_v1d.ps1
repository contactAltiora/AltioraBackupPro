$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$core = Join-Path $root "src\backup_core.py"
if(-not (Test-Path $core)) { throw "ERROR: missing file: $core" }

function WriteUtf8NoBom([string]$path, [string]$text){
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

$txt = Get-Content -Path $core -Raw -Encoding UTF8

$startAnchor = "def _derive_data_key_from_password("
$start = $txt.IndexOf($startAnchor)
if($start -lt 0){ throw "ERROR: cannot find helper start anchor in backup_core.py" }

# On remplace jusqu'à la ligne vide double suivante après le helper (borne simple)
$after = $txt.IndexOf("`r`n`r`n", $start)
if($after -lt 0){ throw "ERROR: cannot find helper end boundary (blank line) in backup_core.py" }

# Trouver la fin du bloc helper: on va chercher le prochain "def " après le helper
$nextDef = $txt.IndexOf("`r`ndef ", $start + 5)
if($nextDef -lt 0){ throw "ERROR: cannot find next def after helper" }

$helperNew = @"
def _derive_data_key_from_password(password: str, header_salt: bytes) -> bytes:
    """
    V2 (MasterKey): data_key = HKDF(master_key, salt=header_salt)

    Comportement:
    - Si MK absente / import impossible => RuntimeError("MASTERKEY_NOT_AVAILABLE")
    - Si password MK incorrect => RuntimeError("MASTERKEY_NOT_AVAILABLE") (=> fallback PBKDF2 possible)
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
        # password incorrect => on autorise le fallback legacy
        raise RuntimeError("MASTERKEY_NOT_AVAILABLE") from e

    return derive_data_key(mk, header_salt)

"@

$before = $txt.Substring(0, $start)
$rest   = $txt.Substring($nextDef)   # conserve tout ce qui suit le helper
$txt2   = $before + $helperNew + $rest

WriteUtf8NoBom $core $txt2
Write-Host "OK: backup_core.py helper updated (fallback-friendly)."

Set-Location $root
py -m py_compile .\src\backup_core.py
Write-Host "OK: py_compile backup_core.py"
