$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$core = Join-Path $root "src\backup_core.py"
$py   = Join-Path $root "tools\patch_kdf_normalize_v1e.py"

if(-not (Test-Path $core)) { throw "ERROR: missing file: $core" }

$pyText = @"
from pathlib import Path

CORE = Path(r"C:\Dev\AltioraBackupPro\src\backup_core.py")
s = CORE.read_text(encoding="utf-8")
lines = s.splitlines(True)

def find_idx(substr, start=0):
    for i in range(start, len(lines)):
        if substr in lines[i]:
            return i
    return -1

def ensure_header_kdf_override():
    # Find header dict creation line within create_backup region
    a = find_idx("def create_backup(")
    if a < 0:
        raise SystemExit("ERROR: cannot find def create_backup(")

    h = find_idx("header: Dict[str, Any] = {", a)
    if h < 0:
        raise SystemExit("ERROR: cannot find header dict anchor inside create_backup")

    # Within next 120 lines, locate 'header_bytes = json.dumps(' and ensure we assign header["kdf"] = kdf_mode before it
    end = min(len(lines), h + 140)
    jb = -1
    for i in range(h, end):
        if "header_bytes" in lines[i] and "json.dumps" in lines[i]:
            jb = i
            break
    if jb < 0:
        raise SystemExit("ERROR: cannot find header_bytes json.dumps anchor near header dict")

    # Check if we already set header["kdf"] = kdf_mode in that window
    window = "".join(lines[h:jb])
    if 'header["kdf"]' in window and "kdf_mode" in window:
        return "INFO: header kdf override already present"

    # Insert just before header_bytes line, preserving indentation
    indent = lines[jb].split("header_bytes")[0]
    ins = [
        indent + "# Normalise le champ KDF (valeur canonique)\n",
        indent + "header[\"kdf\"] = kdf_mode\n",
        indent + "\n",
    ]
    lines[jb:jb] = ins
    return "OK: header kdf override inserted"

def normalize_switch_blocks():
    # Replace two switch blocks (verify + restore) that start with: kdf_mode = str(header.get("kdf") or "pbkdf2")
    # We rewrite them to normalize legacy strings.

    def patch_one(start=0):
        for i in range(start, len(lines)):
            if 'kdf_mode = str(header.get("kdf") or "pbkdf2")' in lines[i]:
                indent = lines[i].split("kdf_mode")[0]
                # Expect next lines pattern:
                # if kdf_mode == "mk_hkdf":
                #    key = ...
                # else:
                #    key = ...
                # We'll replace the whole 5-line block with a normalized 9-line block.
                block_old_len = 5
                new = [
                    indent + 'kdf_raw = str(header.get("kdf") or "pbkdf2")\n',
                    indent + 'kdf_norm = kdf_raw.strip().lower()\n',
                    indent + 'if "mk_hkdf" in kdf_norm or kdf_norm == "mk":\n',
                    indent + '    key = _derive_data_key_from_password(password, salt)\n',
                    indent + 'else:\n',
                    indent + '    # accepte pbkdf2, et libellés legacy type "PBKDF2HMAC-SHA256"\n',
                    indent + '    key = _derive_key(password, salt, iterations)\n',
                    indent + '\n',
                ]
                lines[i:i+block_old_len] = new
                return i + len(new)
        return -1

    p1 = patch_one(0)
    if p1 < 0:
        return "WARN: no switch block found to normalize"
    p2 = patch_one(p1)
    if p2 < 0:
        return "INFO: only one switch block normalized (second not found)"
    return "OK: switch blocks normalized (verify + restore)"

m1 = ensure_header_kdf_override()
m2 = normalize_switch_blocks()

CORE.write_text("".join(lines), encoding="utf-8")
print(m1)
print(m2)
print("OK: patch_kdf_normalize_v1e applied")
"@

Set-Content -Path $py -Value $pyText -Encoding UTF8

Set-Location $root
py -X utf8 $py

py -m py_compile .\src\backup_core.py
Write-Host "OK: py_compile backup_core.py"
