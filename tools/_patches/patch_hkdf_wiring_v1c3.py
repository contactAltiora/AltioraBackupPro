from pathlib import Path

CORE = Path(r"C:\Dev\AltioraBackupPro\src\backup_core.py")
s = CORE.read_text(encoding="utf-8")
lines = s.splitlines(True)

def find_line_idx(substr, start=0):
    for i in range(start, len(lines)):
        if substr in lines[i]:
            return i
    return -1

def replace_in_window(anchor_substr, window, match_substr, new_block_lines):
    a = find_line_idx(anchor_substr)
    if a < 0:
        raise SystemExit(f"ERROR: anchor not found: {anchor_substr}")
    end = min(len(lines), a + window + 1)
    for j in range(a, end):
        if match_substr in lines[j]:
            indent = lines[j].split(match_substr)[0]
            block = []
            for ln in new_block_lines:
                if ln.strip() == "":
                    block.append(ln)
                else:
                    block.append(indent + ln)
            lines[j:j+1] = block
            return True
    raise SystemExit(f"ERROR: match '{match_substr}' not found within window after '{anchor_substr}'")

# 1) create_backup: key derivation switch + kdf_mode
new_key_block = [
    "# Derivation clé (V2 MasterKey HKDF) + fallback legacy PBKDF2\n",
    "try:\n",
    "    key = _derive_data_key_from_password(password, salt)\n",
    "    kdf_mode = \"mk_hkdf\"\n",
    "except RuntimeError as e:\n",
    "    if str(e) == \"MASTERKEY_NOT_AVAILABLE\":\n",
    "        key = _derive_key(password, salt, int(iterations))\n",
    "        kdf_mode = \"pbkdf2\"\n",
    "    else:\n",
    "        raise\n",
]
replace_in_window("salt = os.urandom(16)", window=25, match_substr="key = _derive_key(", new_block_lines=new_key_block)

# 2) header dict: store kdf
hdr_anchor = "header: Dict[str, Any] = {"
idx = find_line_idx(hdr_anchor)
if idx < 0:
    raise SystemExit("ERROR: cannot find header dict anchor")

window_text = "".join(lines[idx:idx+60])
if "\"kdf\"" not in window_text:
    indent = lines[idx].split("header:")[0]
    lines.insert(idx+1, indent + "    \"kdf\": kdf_mode,\n")

# 3) verify/restore: switch based on header['kdf']
switch_block = [
    "kdf_mode = str(header.get(\"kdf\") or \"pbkdf2\")\n",
    "if kdf_mode == \"mk_hkdf\":\n",
    "    key = _derive_data_key_from_password(password, salt)\n",
    "else:\n",
    "    key = _derive_key(password, salt, iterations)\n",
]

def patch_next_key_assign(start_idx=0):
    for i in range(start_idx, len(lines)):
        if "key = _derive_key(password, salt, iterations)" in lines[i]:
            indent = lines[i].split("key =")[0]
            block = [indent + ln for ln in switch_block]
            lines[i:i+1] = block
            return i + len(block)
    return -1

p1 = patch_next_key_assign(0)
p2 = patch_next_key_assign(p1 if p1 > 0 else 0)

CORE.write_text("".join(lines), encoding="utf-8")
print("OK: HKDF wiring v1c3 applied to backup_core.py")
