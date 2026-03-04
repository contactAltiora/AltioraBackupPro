# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
from src import license_core  # ABP_REMOVE_DEBUG_VERIFY_OFFSETS_V60E  # ABP_FIX_ORPHAN_WITH_INDENT_V60F  # ABP_DEBUG_VERIFY_FIELDS_V61B  # ABP_FIX_V61B_AND_DEBUG_V61C  # ABP_DISABLE_HDR_IT_OVERRIDE_V62B  # ABP_DEBUG_VERIFY_PAYLOAD_V63B  # ABP_DEBUG_VERIFY_LAYOUT_V64  # ABP_DEBUG_PAYLOAD_BOUNDARY_V65  # ABP_DEBUG_JSON_TO_BIN_BOUNDARY_V66  # ABP_FIX_VERIFY_PAYLOAD_OFFSET_V67  # ABP_FIX_STRIP_APPENDED_TAG_AFTER_TAG_PARSE_V68B  # ABP_FIX_STRIP_APPENDED_TAG_EXPLICIT_V69  # ABP_DEBUG_TRY_AAD_CANDIDATES_V70  # ABP_FIX_V70_TOPLEVEL_AND_INJECT_V70B  # ABP_DEBUG_LOCATE_SALT_IV_TAG_V71C  # ABP_DEBUG_PRINT_BACKUP_PATH_EXISTS_V72
import os

# ABP_DEBUG_TRY_AAD_CANDIDATES_V70
try:
    import os as __os70
    __dbg = ((__os70.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES')) and ('backup_path' in locals()))
    if __dbg:
        print('[ABP_DEBUG] v70_aad_probe_start=True')

    # We attempt independent AESGCM decrypt with multiple AAD candidates
    __raw = None
    try:
        with open(backup_path,'rb') as __f:
            __raw = __f.read()
    except Exception as __e_read:
        __raw = None
        if __dbg: print('[ABP_DEBUG] v70_read_fail=%r' % (__e_read,))

    def __np_ratio(b):
        if not b: return 0.0
        np = 0
        for x in b:
            if not ((x in (9,10,13)) or (32 <= x <= 126)):
                np += 1
        return np / float(len(b))

    def __find_json_to_bin_off(raw, end):
        scan_back = min(end, 64*1024*1024)
        start = end - scan_back
        pats = (b'}\\n', b']\\n', b'}\\r\\n', b']\\r\\n')
        for i in range(end-2, start, -1):
            for pat in pats:
                lp = len(pat)
                if i-lp+1 < start: continue
                if raw[i-lp+1:i+1] == pat:
                    after = i+1
                    win = raw[after:min(after+4096, end)]
                    r = __np_ratio(win)
                    if r >= 0.55 and len(win) >= 512:
                        return after
        return None

    if __raw is not None and ('tag' in locals()) and isinstance(tag,(bytes,bytearray)) and len(tag)==16:
        __n = len(__raw)
        __tag_end = (__n>=16 and __raw[-16:] == tag)
        __end = (__n-16) if __tag_end else __n
        __off = __find_json_to_bin_off(__raw, __end)
        if __dbg:
            print('[ABP_DEBUG] v70_tag_at_end=%s end=%d off=%s' % (__tag_end, __end, str(__off)))

        # pick ciphertext var actually present
        __ct = None
        for __nm in ('ciphertext','ct','data','payload','encrypted','blob','enc'):
            if __nm in locals() and isinstance(locals()[__nm], (bytes, bytearray)):
                __ct = locals()[__nm]
                break

        # pick a 32-byte key candidate from locals (do not print it)
        __key = None
        for __kn in ('key','aes_key','enc_key','k','dk','derived_key'):
            if __kn in locals() and isinstance(locals()[__kn], (bytes, bytearray)) and len(locals()[__kn]) in (32,):
                __key = locals()[__kn]
                break
        if __key is None:
            for __kn,__vv in list(locals().items()):
                if isinstance(__vv,(bytes,bytearray)) and len(__vv)==32:
                    __key = __vv; break

        # nonce/iv
        __iv = None
        for __inm in ('iv','nonce'):
            if __inm in locals() and isinstance(locals()[__inm], (bytes, bytearray)) and len(locals()[__inm]) in (12,):
                __iv = locals()[__inm]
                break

        if __dbg:
            print('[ABP_DEBUG] v70_have_key=%s have_iv=%s have_ct=%s' % (str(__key is not None), str(__iv is not None), str(__ct is not None)))

        if (__key is not None) and (__iv is not None) and (__ct is not None):
            try:
                from cryptography.hazmat.primitives.ciphers.aead import AESGCM as __AESGCM
                __aes = __AESGCM(bytes(__key))
                __buf = bytes(__ct) + bytes(tag)

                __aad_list = []
                __aad_list.append(('aad_None', None))
                __aad_list.append(('aad_empty', b''))
                __aad_list.append(('aad_header12', __raw[:12] if len(__raw)>=12 else __raw))
                if __off is not None and __off > 0:
                    __aad_list.append(('aad_prefix_0_off', __raw[:__off]))
                    __aad_list.append(('aad_prefix_12_off', __raw[12:__off] if __off>12 else b''))

                __ok = None
                for __name,__aad in __aad_list:
                    try:
                        __pt = __aes.decrypt(bytes(__iv), __buf, __aad)
                        __ok = __name
                        if __dbg: print('[ABP_DEBUG] v70_decrypt_OK=%s pt_len=%d' % (__name, len(__pt)))
                        break
                    except Exception as __e_dec:
                        if __dbg: print('[ABP_DEBUG] v70_decrypt_FAIL=%s err=%s' % (__name, __e_dec.__class__.__name__))

                if __dbg: print('[ABP_DEBUG] v70_decrypt_best=%s' % (str(__ok),))
            except Exception as __e_outer:
                if __dbg: print('[ABP_DEBUG] v70_probe_fail=%r' % (__e_outer,))

except Exception as __e:
    try:
        _abp_dbg('v70_fail=%r' % (__e,))
    except Exception:
        pass

# ABP_DEBUG_HDR_ITER_V57
def _abp_dbg(msg):
    try:
        import os
        if os.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
            print('[ABP_DEBUG]', msg)
    except Exception:
        pass

import json
import uuid
import time
import base64
import struct
import tarfile
import tempfile
import glob
from datetime import datetime
from typing import Dict, Any, List, Tuple, Optional

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
# v75j: core constants (single source of truth, module-scope)
# Garantit que CREATE/VERIFY/RESTORE ne cassent jamais sur drift de scope.
if "VERSION" not in globals():
    VERSION = 1
if "GCM_IV_LEN" not in globals():
    GCM_IV_LEN = 12
if "GCM_TAG_LEN" not in globals():
    GCM_TAG_LEN = 16
if "MAGIC8" not in globals():
    MAGIC8 = b"ALTBKUP1"
if "MAGIC9" not in globals():
    MAGIC9 = b"ALTBKUP10"
# v75i: restore _has_wildcards (drift-safe)
# Utilise par _collect_files pour detecter les patterns (glob).
if "_has_wildcards" not in globals():
    def _has_wildcards(p: str) -> bool:
        if p is None:
            return False
        try:
            s = str(p)
        except Exception:
            return False
        # Caracteres glob usuels: *, ?, [] (Windows/Posix glob)
        return ("*" in s) or ("?" in s) or ("[" in s) or ("]" in s)
# v75h: restore _safe_join (drift-safe)
# Anti path-traversal: interdit les chemins qui sortent de output_dir pendant la restauration.
if "_safe_join" not in globals():
    def _safe_join(base_dir: str, rel_path: str) -> str:
        if base_dir is None:
            raise ValueError("base_dir is None")
        if rel_path is None:
            raise ValueError("rel_path is None")

        base = os.path.abspath(str(base_dir))
        rel = str(rel_path).replace("\\\\", "/")

        # Refuser les chemins absolus ou UNC
        if rel.startswith("/") or rel.startswith("\\\\"):
            raise ValueError("absolute/UNC path not allowed")

        # Refuser les chemins de type "C:..." (drive) meme sans slash
        if len(rel) >= 2 and rel[1] == ":":
            raise ValueError("drive path not allowed")

        # Normaliser: supprimer les slashes initiaux
        rel = rel.lstrip("/")

        joined = os.path.abspath(os.path.join(base, rel))

        # Autoriser exactement base (rare) ou base + sep
        base_prefix = base + os.sep
        if joined != base and not joined.startswith(base_prefix):
            raise ValueError("path traversal blocked")

        return joined
# v75g3: restore tag len (drift-safe)
# GCM_TAG_LEN doit exister au scope module (verify/restore en dependent).
if "GCM_TAG_LEN" not in globals():
    GCM_TAG_LEN = 16
# v75f: restore _derive_key (drift-safe)
# PBKDF2-HMAC-SHA256 -> 32 bytes (AES-256)
if "_derive_key" not in globals():
    def _derive_key(password: str, salt: bytes, iterations: int) -> bytes:
        if password is None:
            raise ValueError("password is None")
        if salt is None:
            raise ValueError("salt is None")
        try:
            it = int(iterations)
        except Exception:
            it = 300_000
        if it <= 0:
            it = 300_000

        # imports locaux pour eviter tout souci de drift d'import
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives import hashes

        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=it,
        )
        return kdf.derive(password.encode("utf-8"))
# v75e: restore b64 helpers (drift-safe)
# _b64d/_b64e doivent exister au scope module (utilises par verify/restore/create).
import base64 as _abp_b64

if "_b64d" not in globals():
    def _b64d(s: str) -> bytes:
        if s is None:
            raise ValueError("b64 input is None")
        if isinstance(s, bytes):
            s = s.decode("utf-8")
        return _abp_b64.b64decode(s.encode("utf-8"))

if "_b64e" not in globals():
    def _b64e(b: bytes) -> str:
        if b is None:
            raise ValueError("bytes input is None")
        return _abp_b64.b64encode(b).decode("utf-8")

# v75a: restore module constants (drift-safe)
# v75k: edition lock + reason (single source of truth, module-scope)
# Regle: FREE par defaut. PRO seulement si licence valide.
if "FREE_RESTORE_LIMIT_BYTES" not in globals():
    FREE_RESTORE_LIMIT_BYTES = 1024 * 1024 * 1024  # 1 GiB (Free restore limit)
# FREE: limitation BACKUP (taille logique en clair)
FREE_BACKUP_LIMIT_BYTES = 1024 * 1024 * 1024  # 1 GiB (Free backup limit)


try:
    EDITION_REQUESTED = os.environ.get("ALTIORA_EDITION", "FREE").upper()
    # ABP_STRICT_MISSING_FLAG_V2
    _strict_missing_license = False
except Exception:
    EDITION_REQUESTED = "FREE"

# v75l: optional strict license mode
# Si ALTIORA_LICENSE_STRICT=1 et PRO demande, alors licence doit etre fournie explicitement via ALTIORA_LICENSE_FILE.
try:
    _strict = os.environ.get("ALTIORA_LICENSE_STRICT", "").strip() == "1"
except Exception:
    _strict = False

if EDITION_REQUESTED == "PRO" and _strict:
    _p = os.environ.get("ALTIORA_LICENSE_FILE", "").strip()
    if (not _p) or (not os.path.exists(_p)):
        _strict_missing_license = True
        # on force une raison stable (visible via logs)
        EDITION_REASON = "strict_missing_ALTIORA_LICENSE_FILE"
        # ABP_STRICT_MISSING_FINAL_V2
        EDITION = "FREE"
EDITION = "FREE"
EDITION_REASON = "default_free"

if EDITION_REQUESTED == "PRO" and not _strict_missing_license:  # ABP_STRICT_MISSING_GUARD_V2
    try:
        ok, _reason = license_core.verify_license()
        if ok:
            EDITION = "PRO"
            EDITION_REASON = "license_ok"
        else:
            EDITION = "FREE"
            EDITION_REASON = "license_invalid:" + str(_reason)
    except Exception as e:
        EDITION = "FREE"
        EDITION_REASON = "license_error:" + e.__class__.__name__
else:
    EDITION = "FREE"
    EDITION_REASON = "env_free"
    # ABP_STRICT_MISSING_FINAL_CLAMP_V3
    if "_strict_missing_license" in globals() and _strict_missing_license:
        EDITION = "FREE"
        EDITION_REASON = "strict_missing_ALTIORA_LICENSE_FILE"
class BackupCore:
    """
    Backup container format:
      MAGIC8 (8) or MAGIC9 (9)
      version (uint16 BE)
      header_len (uint32 BE)
      header_json (utf-8)
      ciphertext (AES-256-GCM)
      tag (16)
    """

    def __init__(self, manager=None):
        if manager is None:
            try:
                from src.backup_manager import BackupManager
            except ImportError:
                from backup_manager import BackupManager
            self.manager = BackupManager()
        else:
            self.manager = manager

        self.log = None
        try:
            try:
                from src.logging import setup_logging
            except Exception:
                setup_logging = None  # type: ignore
            if setup_logging:
                self.log = setup_logging("backup_core")
                self.log.info("BackupCore ready")
        except Exception:
            self.log = None

        # Permet a la CLI / tests d'afficher une "raison" si besoin
        self.last_verify_error: Optional[str] = None

    def _log_info(self, msg: str, *args: Any) -> None:
        if self.log:
            try:
                self.log.info(msg, *args)
            except Exception:
                pass

    def _log_error(self, msg: str, *args: Any) -> None:
        if self.log:
            try:
                self.log.error(msg, *args)
            except Exception:
                pass

    def _log_exception(self, msg: str) -> None:
        if self.log:
            try:
                self.log.exception(msg)
            except Exception:
                pass

    # ------------------------------------------------------------------
    # Collecte fichiers (avec support wildcards)
    # ------------------------------------------------------------------
    def _collect_files(self, source_path: str) -> Tuple[str, List[str]]:
        if not source_path or not str(source_path).strip():
            raise FileNotFoundError("Source vide (aucun chemin fourni).")

        raw = str(source_path).strip()

        if _has_wildcards(raw):
            matches = glob.glob(raw, recursive=True)
            files = [os.path.abspath(p) for p in matches if os.path.isfile(p)]
            if not files:
                raise FileNotFoundError(f"Aucun fichier ne correspond au motif: {raw}")
            common = os.path.commonpath(files)
            if os.path.isfile(common):
                common = os.path.dirname(common)
            base_dir = common or "."
            return os.path.abspath(base_dir), files

        abs_source = os.path.abspath(raw)

        if os.path.isfile(abs_source):
            base_dir = os.path.dirname(abs_source) or "."
            return os.path.abspath(base_dir), [abs_source]

        if not os.path.isdir(abs_source):
            raise FileNotFoundError(f"Source non trouvee: {abs_source}")

        base_dir = abs_source
        files: List[str] = []
        for root, dirs, filenames in os.walk(abs_source):
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
            for fn in filenames:
                files.append(os.path.abspath(os.path.join(root, fn)))

        if not files:
            raise FileNotFoundError(f"Dossier source vide (aucun fichier a sauvegarder): {abs_source}")

        return os.path.abspath(base_dir), files

    # ------------------------------------------------------------------
    # BACKUP (container)
    # ------------------------------------------------------------------
    def create_backup(
        self,
        source_path: str,
        output_path: str,
        password: str,
        iterations: int = 300_000,
        compress: bool = True,
    ) -> bool:
        start = time.time()
        output_path_abs = os.path.abspath(output_path)

        try:
            if not password:
                print("ERROR ERREUR BACKUP: mot de passe vide.")
                return False

            out_dir = os.path.dirname(output_path_abs) or "."
            os.makedirs(out_dir, exist_ok=True)

            backup_id = str(uuid.uuid4())[:16]

            try:
                base_dir, files_to_backup = self._collect_files(source_path)
            except FileNotFoundError as e:
                print(f"ERROR ERREUR BACKUP: {e}")
                self._log_error("BACKUP FAILED reason=source_invalid source=%s", os.path.abspath(source_path))
                return False

            if not files_to_backup:
                print("ERROR ERREUR BACKUP: aucun fichier a sauvegarder (source vide ou motif invalide).")
                self._log_error("BACKUP FAILED reason=no_files source=%s", os.path.abspath(source_path))
                return False

            manifest: List[Dict[str, Any]] = []
            total_size = 0
            for p in files_to_backup:
                try:
                    st = os.stat(p)
                    rel = os.path.relpath(p, base_dir).replace("\\", "/")
                    manifest.append({"path": rel, "size": int(st.st_size), "mtime": int(st.st_mtime)})
                    total_size += int(st.st_size)
                except Exception:
                    continue

            if not manifest:
                print("ERROR ERREUR BACKUP: impossible de lire les fichiers de la source (droits/acces).")
                self._log_error("BACKUP FAILED reason=manifest_empty source=%s", os.path.abspath(source_path))
                return False

            suffix = ".tar.gz" if compress else ".tar"
            mode = "w:gz" if compress else "w"

            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                # ABP_FREE_BACKUP_LIMIT_V4: block backup > 1GiB in FREE (logical/plain size)
                if EDITION == "FREE":
                    try:
                        if int(total_size) > int(FREE_BACKUP_LIMIT_BYTES):
                            total_gb = float(total_size) / (1024.0 * 1024.0 * 1024.0)
                            limit_gb = float(FREE_BACKUP_LIMIT_BYTES) / (1024.0 * 1024.0 * 1024.0)
                            print("\nERROR BACKUP BLOQUE - Altiora Backup Free")
                            print(f"   Taille a sauvegarder : {total_gb:.2f} Go")
                            print(f"   Limite Free          : {limit_gb:.2f} Go\n")
                            print("-> Passez a Altiora Backup Pro pour sauvegarder sans limite.")
                            self.last_error_code = "FREE_LIMIT_BACKUP"
                            self.last_exit_code = 102
                            return False
                    except Exception:
                        print("\nERROR BACKUP BLOQUE - Altiora Backup Free (erreur taille)")
                        print("-> Passez a Altiora Backup Pro pour sauvegarder sans limite.")
                        self.last_error_code = "FREE_LIMIT_BACKUP_ERROR"
                        self.last_exit_code = 102
                        return False
                tmp_archive = tmp.name

            try:
                with tarfile.open(tmp_archive, mode) as tf:
                    for abs_path in files_to_backup:
                        try:
                            rel = os.path.relpath(abs_path, base_dir).replace("\\", "/")
                            tf.add(abs_path, arcname=rel)
                        except Exception:
                            continue

                try:
                    if os.path.getsize(tmp_archive) <= 0:
                        print("ERROR ERREUR BACKUP: archive interne vide (source invalide).")
                        self._log_error("BACKUP FAILED reason=empty_archive source=%s", os.path.abspath(source_path))
                        return False
                except Exception:
                    pass

                salt = os.urandom(16)
                iv_len = globals().get("GCM_IV_LEN", 12)
                iv = os.urandom(int(iv_len))
                key = _derive_key(password, salt, int(iterations))

                header: Dict[str, Any] = {
                    "version": VERSION,
                    "backup_id": backup_id,
                    "created_at": datetime.now().isoformat(timespec="seconds"),
                    "source": os.path.abspath(source_path),
                    "archive": "tar.gz" if compress else "tar",
                    "algo": "AES-256-GCM",
                    "kdf": "PBKDF2HMAC-SHA256",
                    "iterations": int(iterations),
                    "salt_b64": _b64e(salt),
                    "iv_b64": _b64e(iv),
                    "files_count": len(manifest),
                    "plain_size": total_size,
                    "manifest": manifest,
                }
                header_bytes = json.dumps(header, ensure_ascii=False).encode("utf-8")

                tmp_out = output_path_abs + ".tmp"
                encryptor = Cipher(algorithms.AES(key), modes.GCM(iv)).encryptor()
                # v74a: lier le header au chiffrement (AAD)
                encryptor.authenticate_additional_data(header_bytes)

                with open(tmp_archive, "rb") as fin, open(tmp_out, "wb") as fout:
                    fout.write(b"ALTBKUP1")
                    fout.write(struct.pack(">H", VERSION))
                    fout.write(struct.pack(">I", len(header_bytes)))
                    fout.write(header_bytes)

                    while True:
                        chunk = fin.read(1024 * 1024)
                        if not chunk:
                            break
                        fout.write(encryptor.update(chunk))

                    fout.write(encryptor.finalize())
                    fout.write(encryptor.tag)

                os.replace(tmp_out, output_path_abs)

                elapsed = time.time() - start
                speed_bps = total_size / elapsed if elapsed > 0 else 0

                self.manager.add_backup(
                    {
                        "backup_id": backup_id,
                        "id": backup_id,
                        "name": os.path.basename(output_path_abs),
                        "source": os.path.abspath(source_path),
                        "size": os.path.getsize(output_path_abs),
                        "files_count": len(manifest),
                        "timestamp": header["created_at"],
                        "duration": elapsed,
                        "speed_bps": speed_bps,
                        "plain_size": total_size,
                        "iterations": int(iterations),
                        "algo": "AES-256-GCM",
                        "file_path": output_path_abs,
                    }
                )

                print(f"PACKAGE Backup: {os.path.basename(output_path_abs)}")
                print(f"   ID ID: {backup_id}")
                print(f"   FILE Fichiers: {len(manifest)}")
                print(f"   PACKAGE Taille: {os.path.getsize(output_path_abs)} bytes")
                print(f"   FILE Donnees (clair): {total_size} bytes")
                print(f" TIME  Duree: {elapsed:.2f}s")

                self._log_info(
                    "BACKUP OK id=%s files=%s bytes=%s elapsed=%.2f",
                    backup_id,
                    len(manifest),
                    os.path.getsize(output_path_abs),
                    elapsed,
                )
                return True

            finally:
                try:
                    if os.path.exists(tmp_archive):
                        os.remove(tmp_archive)
                except Exception:
                    pass

        except Exception as e:
            print(f"ERROR ERREUR BACKUP: {type(e).__name__}: {e}")
            self._log_exception("BACKUP FAILED")
            try:
                tmp_candidate = output_path_abs + ".tmp"
                if os.path.exists(tmp_candidate):
                    os.remove(tmp_candidate)
            except Exception:
                pass
            return False

    # ------------------------------------------------------------------
    # Lecture header container (sans restaurer)
    # ------------------------------------------------------------------
    def _read_container_header(self, backup_path: str) -> Optional[Dict[str, Any]]:
        backup_path = os.path.abspath(backup_path)
        if not os.path.exists(backup_path):
            return None
        try:
            with open(backup_path, "rb") as f:
                head9 = f.read(9)

                magic_len: Optional[int] = None
                if head9 == b"ALTBKUP10":
                    magic_len = 9
                elif head9[:8] == b"ALTBKUP1":
                    magic_len = 8
                    f.seek(8, os.SEEK_SET)

                if magic_len is None:
                    return None

                ver_bytes = f.read(2)
                header_len_bytes = f.read(4)
                if len(ver_bytes) != 2 or len(header_len_bytes) != 4:
                    return None

                ver = struct.unpack(">H", ver_bytes)[0]
                header_len = struct.unpack(">I", header_len_bytes)[0]

                # Compat : on accepte ver >=1, et on garde un plafond sur header_len
                if ver < 1 or header_len <= 0 or header_len > 50_000_000:
                    return None

                header_raw = f.read(header_len)
                if len(header_raw) != header_len:
                    return None

                header = json.loads(header_raw.decode("utf-8"))
                # v74a: garder les bytes exacts du header (AAD compat)
                header["_header_raw"] = header_raw
                if "salt_b64" not in header or "iv_b64" not in header:
                    return None

                header["_magic_len"] = magic_len
                header["_header_len"] = header_len
                header["_container_ver"] = ver
                return header
        except Exception:
            return None

    # ------------------------------------------------------------------
    # SAFE MODE collisions
    # ------------------------------------------------------------------
    def check_restore_collisions(self, backup_path: str, output_dir: str) -> List[str]:
        output_dir = os.path.abspath(output_dir)
        header = self._read_container_header(backup_path)
        if not header:
            return []

        manifest = header.get("manifest", [])
        if not isinstance(manifest, list):
            return []

        collisions: List[str] = []
        for it in manifest:
            try:
                rel = str(it.get("path", "")).replace("\\", "/")
                if not rel:
                    continue
                dst = _safe_join(output_dir, rel)
                if os.path.exists(dst):
                    collisions.append(rel)
            except Exception:
                continue
        return collisions

    # ------------------------------------------------------------------
    # VERIFY (bool) + VERIFY (detaille)
    # ------------------------------------------------------------------
    def verify_backup_detailed(self, backup_path: str, password: str) -> Tuple[bool, str]:
        """
        Retourne (ok, reason).
        reason est une string stable exploitable cote CLI/tests.
        """
        # ABP_DEBUG_VERIFY_BD_V58C
        _abp_dbg("verify_backup_detailed() ENTER")
        # ABP_DEBUG_PRINT_BACKUP_PATH_EXISTS_V72
        try:
            import os as __os72
            __dbg72 = (__os72.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'))
            if __dbg72:
                try:
                    __bp = backup_path
                except Exception as __e:
                    __bp = '<backup_path_UNDEF:%s>' % (__e.__class__.__name__,)
                try:
                    __bps = str(__bp)
                except Exception:
                    __bps = '<str_fail>'
                __norm = __os72.path.normpath(__bps) if isinstance(__bps,str) else '<norm_skip>'
                __ex1 = __os72.path.exists(__bps) if isinstance(__bps,str) else False
                __ex2 = __os72.path.exists(__norm) if isinstance(__norm,str) else False
                print('[ABP_DEBUG] v72_backup_path_repr=%r' % (__bp,))
                print('[ABP_DEBUG] v72_backup_path_str=%s' % (__bps,))
                print('[ABP_DEBUG] v72_backup_path_norm=%s' % (__norm,))
                print('[ABP_DEBUG] v72_exists_str=%s exists_norm=%s' % (str(__ex1), str(__ex2)))
                # if normpath exists but original doesn't, adopt normpath (non-destructive)
                if (not __ex1) and __ex2 and isinstance(__norm,str):
                    try:
                        backup_path = __norm
                        print('[ABP_DEBUG] v72_backup_path_replaced_with_norm=True')
                    except Exception:
                        pass
        except Exception as __e:
            try:
                _abp_dbg('v72_fail=%r' % (__e,))
            except Exception:
                pass

        try:
            with open(backup_path, "rb") as __f:
                pass

                __h16 = __f.read(16)
            __raw = __h16[8:12] if (__h16 and len(__h16) >= 12) else None
            if __raw is not None:
                __be32 = int.from_bytes(__raw, "big", signed=False)
                __le32 = int.from_bytes(__raw, "little", signed=False)
                __ver16 = int.from_bytes(__raw[0:2], "big", signed=False)
                __it16  = int.from_bytes(__raw[2:4], "big", signed=False)
                _abp_dbg("HEAD16=%s raw8_12=%s be32=%d le32=%d u16ver=%d u16it=%d" % (__h16.hex(), __raw.hex(), __be32, __le32, __ver16, __it16))
        except Exception as __e:
            _abp_dbg("header read failed: %r" % (__e,))

        self.last_verify_error = None

        backup_path = os.path.abspath(backup_path)
        if not os.path.exists(backup_path):
            self.last_verify_error = "file_not_found"
            return False, "file_not_found"
        if not password:
            self.last_verify_error = "empty_password"
            return False, "empty_password"

        header = self._read_container_header(backup_path)
        if not header:
            self.last_verify_error = "unrecognized_format_or_bad_header"
            return False, "unrecognized_format_or_bad_header"

        magic_len = int(header.get("_magic_len", 8))
        header_len = int(header.get("_header_len", 0))

        try:
            salt = _b64d(header["salt_b64"])
            iv = _b64d(header["iv_b64"])
        except Exception:
            self.last_verify_error = "header_missing_crypto_params"
            return False, "header_missing_crypto_params"

        iterations = int(header.get("iterations", 300_000))
        # ABP_DEBUG_VERIFY_BD_V58C
#         __abp_it = _abp_autodetect_iterations_from_header_DISABLED(backup_path, default=None) if ("_abp_autodetect_iterations_from_header" in globals()) else None
#         if __abp_it is not None:
#             try:
#                 iterations = int(__abp_it)
#                 _abp_dbg("iterations OVERRIDE -> %s" % (iterations,))
#             except Exception as __e:
#                 _abp_dbg("iterations override failed: %r" % (__e,))
# 
        key = _derive_key(password, salt, iterations)

        try:
            # ABP_FIX_VERIFY_PAYLOAD_OFFSET_V67
            try:
                import os as __os
                # Build correct ciphertext slice for JSON->BIN layout: [hdr][json plaintext][ciphertext][tag]
                __raw = None
                try:
                    with open(backup_path,'rb') as __f:
                        __raw = __f.read()
                except Exception:
                    __raw = None
            
                if __raw is not None:
                    __n = len(__raw)
                    __tag_end = False
                    try:
                        __tag_end = ('tag' in locals() and tag is not None and __n>=16 and __raw[-16:] == tag)
                    except Exception:
                        __tag_end = False
                    __end = (__n-16) if __tag_end else __n
            
                    def __nonprint_ratio(b):
                        if not b: return 0.0
                        np = 0
                        for x in b:
                            if not ((x in (9,10,13)) or (32 <= x <= 126)):
                                np += 1
                        return np / float(len(b))
            
                    def __find_json_to_bin_off(raw, end):
                        # Scan backwards looking for JSON terminator then binary-ish region
                        scan_back = min(end, 64*1024*1024)
                        start = end - scan_back
                        pats = (b'}\\n', b']\\n', b'}\\r\\n', b']\\r\\n')
                        for i in range(end-2, start, -1):
                            for pat in pats:
                                lp = len(pat)
                                if i-lp+1 < start: continue
                                if raw[i-lp+1:i+1] == pat:
                                    after = i+1
                                    win = raw[after:min(after+4096, end)]
                                    r = __nonprint_ratio(win)
                                    if r >= 0.55 and len(win) >= 512:
                                        return after
                        return None
            
                    def __find_fallback_off(raw, end):
                        # Fallback: forward scan for printable->binary transition
                        win = 4096
                        step = 256
                        prev_r = None
                        limit = min(end, 8*1024*1024)
                        for off in range(0, max(0, limit-win), step):
                            r = __nonprint_ratio(raw[off:off+win])
                            if prev_r is not None and prev_r < 0.20 and r >= 0.55:
                                return off
                            prev_r = r
                        return None
            
                    __off = __find_json_to_bin_off(__raw, __end)
                    if __off is None:
                        __off = __find_fallback_off(__raw, __end)
            
                    if __off is not None and __off < __end:
                        __ct_candidate = __raw[__off:__end]
                        # Only apply if candidate looks binary-ish (avoid overwriting valid payload)
                        __r0 = __nonprint_ratio(__ct_candidate[:min(4096, len(__ct_candidate))])
                        if len(__ct_candidate) > 0 and __r0 >= 0.55:
                            # Prefer overwriting whichever variable name the code uses for ciphertext
                            if 'ciphertext' in locals():
                                ciphertext = __ct_candidate
                            elif 'ct' in locals():
                                ct = __ct_candidate
                            elif 'data' in locals():
                                data = __ct_candidate
                            elif 'payload' in locals():
                                payload = __ct_candidate
                            elif 'encrypted' in locals():
                                encrypted = __ct_candidate
                            else:
                                ciphertext = __ct_candidate
            
                            # Some implementations pass (ciphertext+tag) as one buffer
                            try:
                                if 'ciphertext_and_tag' in locals() and ('tag' in locals() and tag is not None):
                                    ciphertext_and_tag = __ct_candidate + tag
                            except Exception:
                                pass
            
                            if __os.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
                                print('[ABP_DEBUG] v67_apply_payload_off=%d ct_len=%d nonprint=%.3f tag_at_end=%s' % (__off, len(__ct_candidate), __r0, __tag_end))
            except Exception as __e:
                try:
                    _abp_dbg('v67_payload_fix_fail=%r' % (__e,))
                except Exception:
                    pass

            file_size = os.path.getsize(backup_path)
            ciphertext_start = magic_len + 2 + 4 + header_len
            ciphertext_end = file_size - GCM_TAG_LEN
            if ciphertext_end <= ciphertext_start:
                self.last_verify_error = "invalid_ciphertext_range"
                return False, "invalid_ciphertext_range"

            with open(backup_path, "rb") as f:
                f.seek(-GCM_TAG_LEN, os.SEEK_END)
                tag = f.read(GCM_TAG_LEN)
                # ABP_FIX_STRIP_APPENDED_TAG_EXPLICIT_V69
                # After tag is parsed, STRIP it from ciphertext FOR REAL (do not rely on locals() mutation).
                try:
                    import os as __os69
                    __dbg = (__os69.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'))
                    if isinstance(tag, (bytes, bytearray)) and len(tag) == 16:
                        __done = False
                        if not __done and 'ciphertext' in locals() and isinstance(ciphertext, (bytes, bytearray)) and len(ciphertext) >= 16 and ciphertext[-16:] == tag:
                            ciphertext = ciphertext[:-16]; __done = True
                        if not __done and 'ct' in locals() and isinstance(ct, (bytes, bytearray)) and len(ct) >= 16 and ct[-16:] == tag:
                            ct = ct[:-16]; __done = True
                        if not __done and 'data' in locals() and isinstance(data, (bytes, bytearray)) and len(data) >= 16 and data[-16:] == tag:
                            data = data[:-16]; __done = True
                        if not __done and 'payload' in locals() and isinstance(payload, (bytes, bytearray)) and len(payload) >= 16 and payload[-16:] == tag:
                            payload = payload[:-16]; __done = True
                        if not __done and 'encrypted' in locals() and isinstance(encrypted, (bytes, bytearray)) and len(encrypted) >= 16 and encrypted[-16:] == tag:
                            encrypted = encrypted[:-16]; __done = True
                        if not __done and 'blob' in locals() and isinstance(blob, (bytes, bytearray)) and len(blob) >= 16 and blob[-16:] == tag:
                            blob = blob[:-16]; __done = True
                        if not __done and 'enc' in locals() and isinstance(enc, (bytes, bytearray)) and len(enc) >= 16 and enc[-16:] == tag:
                            enc = enc[:-16]; __done = True
                        if __done and __dbg:
                            print('[ABP_DEBUG] v69_stripped_appended_tag_explicit=True')
                except Exception as __e:
                    try:
                        _abp_dbg('v69_strip_fail=%r' % (__e,))
                    except Exception:
                        pass

                # ABP_DEBUG_TRY_AAD_CANDIDATES_V70B
                try:
                    import os as __os70b
                    __dbg70b = (__os70b.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'))
                    if __dbg70b:
                        print('[ABP_DEBUG] v70b_aad_probe_start=True')

                        if __raw71 is not None:
                            __n71 = len(__raw71)
                            __head71 = __raw71[:64]
                            print('[ABP_DEBUG] v71_file_size=%d' % (__n71,))
                            print('[ABP_DEBUG] v71_first64_hex=%s' % (__head71.hex(),))

                            # locate salt/iv/tag bytes inside file
                            __salt = salt if ('salt' in locals()) else None
                            __iv   = iv if ('iv' in locals()) else (nonce if ('nonce' in locals()) else None)
                            __tag  = tag if ('tag' in locals()) else None

                            def __pos(x):
                                if x is None: return -2
                                try:
                                    xb = bytes(x)
                                    return __raw71.find(xb)
                                except Exception:
                                    return -3

                            __ps = __pos(__salt)
                            __pi = __pos(__iv)
                            __pt = __pos(__tag)
                            print('[ABP_DEBUG] v71_pos_salt=%d v71_pos_iv=%d v71_pos_tag=%d' % (__ps, __pi, __pt))

                            if __tag is not None:
                                try:
                                    __tb = bytes(__tag)
                                    __tag_end = (__n71>=16 and __raw71[-16:] == __tb)
                                    __last = __raw71.rfind(__tb)
                                    print('[ABP_DEBUG] v71_tag_at_end=%s v71_rfind_tag=%d' % (str(__tag_end), __last))
                                except Exception as __e:
                                    print('[ABP_DEBUG] v71_tag_check_fail=%r' % (__e,))
                except Exception as __e:
                    try:
                        _abp_dbg('v71_fail=%r' % (__e,))
                    except Exception:
                        pass

                    __raw70b = None
                    try:
                        with open(backup_path,'rb') as __f70b:
                            __raw70b = __f70b.read()
                    except Exception as __e_read70b:
                        __raw70b = None
                        if __dbg70b: print('[ABP_DEBUG] v70b_read_fail=%r' % (__e_read70b,))

                    def __np_ratio70b(b):
                        if not b: return 0.0
                        np = 0
                        for x in b:
                            if not ((x in (9,10,13)) or (32 <= x <= 126)):
                                np += 1
                        return np / float(len(b))

                    def __find_json_to_bin_off70b(raw, end):
                        scan_back = min(end, 64*1024*1024)
                        start = end - scan_back
                        pats = (b'}\\n', b']\\n', b'}\\r\\n', b']\\r\\n')
                        for i in range(end-2, start, -1):
                            for pat in pats:
                                lp = len(pat)
                                if i-lp+1 < start: continue
                                if raw[i-lp+1:i+1] == pat:
                                    after = i+1
                                    win = raw[after:min(after+4096, end)]
                                    r = __np_ratio70b(win)
                                    if r >= 0.55 and len(win) >= 512:
                                        return after
                        return None

                    if (__raw70b is not None) and ('tag' in locals()) and isinstance(tag,(bytes,bytearray)) and len(tag)==16:
                        __n70b = len(__raw70b)
                        __tag_end70b = (__n70b>=16 and __raw70b[-16:] == tag)
                        __end70b = (__n70b-16) if __tag_end70b else __n70b
                        __off70b = __find_json_to_bin_off70b(__raw70b, __end70b)
                        if __dbg70b:
                            print('[ABP_DEBUG] v70b_tag_at_end=%s end=%d off=%s' % (__tag_end70b, __end70b, str(__off70b)))

                        __ct70b = None
                        for __nm70b in ('ciphertext','ct','data','payload','encrypted','blob','enc'):
                            if __nm70b in locals() and isinstance(locals()[__nm70b], (bytes, bytearray)):
                                __ct70b = locals()[__nm70b]
                                break

                        __key70b = None
                        for __kn70b in ('key','aes_key','enc_key','k','dk','derived_key'):
                            if __kn70b in locals() and isinstance(locals()[__kn70b], (bytes, bytearray)) and len(locals()[__kn70b])==32:
                                __key70b = locals()[__kn70b]
                                break
                        if __key70b is None:
                            for __kn70b,__vv70b in list(locals().items()):
                                if isinstance(__vv70b,(bytes,bytearray)) and len(__vv70b)==32:
                                    __key70b = __vv70b; break

                        __iv70b = None
                        for __inm70b in ('iv','nonce'):
                            if __inm70b in locals() and isinstance(locals()[__inm70b], (bytes, bytearray)) and len(locals()[__inm70b])==12:
                                __iv70b = locals()[__inm70b]
                                break

                        if __dbg70b:
                            print('[ABP_DEBUG] v70b_have_key=%s have_iv=%s have_ct=%s' % (str(__key70b is not None), str(__iv70b is not None), str(__ct70b is not None)))

                        if (__key70b is not None) and (__iv70b is not None) and (__ct70b is not None):
                            try:
                                from cryptography.hazmat.primitives.ciphers.aead import AESGCM as __AESGCM70b
                                __aes70b = __AESGCM70b(bytes(__key70b))
                                __buf70b = bytes(__ct70b) + bytes(tag)

                                __aad_list70b = []
                                __aad_list70b.append(('aad_None', None))
                                __aad_list70b.append(('aad_empty', b''))
                                __aad_list70b.append(('aad_header12', __raw70b[:12] if len(__raw70b)>=12 else __raw70b))
                                if __off70b is not None and __off70b > 0:
                                    __aad_list70b.append(('aad_prefix_0_off', __raw70b[:__off70b]))
                                    __aad_list70b.append(('aad_prefix_12_off', __raw70b[12:__off70b] if __off70b>12 else b''))

                                __ok70b = None
                                for __name70b,__aad70b in __aad_list70b:
                                    try:
                                        __pt70b = __aes70b.decrypt(bytes(__iv70b), __buf70b, __aad70b)
                                        __ok70b = __name70b
                                        if __dbg70b: print('[ABP_DEBUG] v70b_decrypt_OK=%s pt_len=%d' % (__name70b, len(__pt70b)))
                                        break
                                    except Exception as __e_dec70b:
                                        if __dbg70b: print('[ABP_DEBUG] v70b_decrypt_FAIL=%s err=%s' % (__name70b, __e_dec70b.__class__.__name__))

                                if __dbg70b: print('[ABP_DEBUG] v70b_decrypt_best=%s' % (str(__ok70b),))
                            except Exception as __e_outer70b:
                                if __dbg70b: print('[ABP_DEBUG] v70b_probe_fail=%r' % (__e_outer70b,))

                except Exception as __e70b:
                    try:
                        _abp_dbg('v70b_fail=%r' % (__e70b,))
                    except Exception:
                        pass

                # ABP_FIX_STRIP_APPENDED_TAG_AFTER_TAG_PARSE_V68B
                # After tag is parsed, ensure ciphertext does NOT already include the tag at its end.
                try:
                    import os as __os2
                    __v = locals()
                    __tag = __v.get('tag', None)
                    def __strip(name):
                        if name in __v:
                            __ct = __v.get(name, None)
                            if isinstance(__ct, (bytes, bytearray)) and isinstance(__tag, (bytes, bytearray)) and len(__tag)==16:
                                if len(__ct) >= 16 and __ct[-16:] == __tag:
                                    __v[name] = __ct[:-16]
                                    return True
                        return False
                    __changed = False
                    for __nm in ('ciphertext','ct','data','payload','encrypted','blob','enc'):
                        if __strip(__nm):
                            __changed = True
                            break
                    if __changed and __os2.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
                        print('[ABP_DEBUG] v68b_stripped_appended_tag=True')
                except Exception as __e:
                    try:
                        _abp_dbg('v68b_strip_fail=%r' % (__e,))
                    except Exception:
                        pass

                if len(tag) != GCM_TAG_LEN:
                    self.last_verify_error = "invalid_gcm_tag"
                    return False, "invalid_gcm_tag"

                header_raw = header.get("_header_raw", None)

                def _try_verify_with_aad(aad_bytes):
                    f.seek(ciphertext_start, os.SEEK_SET)
                    decryptor = Cipher(algorithms.AES(key), modes.GCM(iv, tag)).decryptor()
                    if aad_bytes is not None:
                        decryptor.authenticate_additional_data(aad_bytes)

                    remaining = ciphertext_end - ciphertext_start
                    while remaining > 0:
                        to_read = min(1024 * 1024, remaining)
                        chunk = f.read(to_read)
                        if not chunk:
                            break
                        remaining -= len(chunk)
                        decryptor.update(chunk)

                    decryptor.finalize()

                # v74a: priorite aux backups AAD (nouveau format), puis fallback legacy sans AAD
                try:
                    if header_raw is not None:
                        _try_verify_with_aad(header_raw)
                    else:
                        raise InvalidTag()
                except InvalidTag:
                    # fallback legacy
                    _try_verify_with_aad(None)

            self._log_info("VERIFY OK file=%s", os.path.basename(backup_path))
            return True, "ok"

            _abp_dbg("fields_dump_fail=%r" % (__e,))

            # ABP_DEBUG_VERIFY_PAYLOAD_V63B
            try:
                import os as __os
                if __os.environ.get("ABP_DEBUG_HDR","0") in ("1","true","TRUE","yes","YES"):
                    __v = locals()
                    print("[ABP_DEBUG] --- PRE-EXCEPT PAYLOAD CANDIDATES ---")
                    print("[ABP_DEBUG] iterations=%s GCM_TAG_LEN=%s" % (__v.get('iterations',None), globals().get('GCM_TAG_LEN',None)))
                    # show known fields if present
                    for __name in ('salt','iv','nonce','tag'):
                        if __name in __v and __v[__name] is not None and hasattr(__v[__name],'__len__'):
                            try:
                                print("[ABP_DEBUG] %s_len=%d head=%s" % (__name, len(__v[__name]), (__v[__name][:16].hex() if hasattr(__v[__name],'hex') else str(type(__v[__name])))))
                            except Exception:
                                pass
            
                    # heuristic: list biggest byte-like locals (excluding salt/iv/nonce/tag)
                    __cands = []
                    for __k,__val in __v.items():
                        try:
                            if __k in ('salt','iv','nonce','tag'):
                                continue
                            if isinstance(__val, (bytes, bytearray)) and len(__val) > 0:
                                __cands.append((len(__val), __k, __val))
                        except Exception:
                            pass
                    __cands.sort(reverse=True, key=lambda t: t[0])
                    if not __cands:
                        print("[ABP_DEBUG] NO byte-like locals found (payload passed inline or not stored)")
                    else:
                        for __n in range(0, min(10, len(__cands))):
                            __ln,__k,__val = __cands[__n]
                            try:
                                __h = __val[:16].hex() if __ln>=16 else __val.hex()
                                __t = __val[-16:].hex() if __ln>=16 else __val.hex()
                                print("[ABP_DEBUG] cand[%d] %s_len=%d head=%s tail=%s" % (__n, __k, __ln, __h, __t))
                            except Exception:
                                print("[ABP_DEBUG] cand[%d] %s_len=%d (no hex)" % (__n, __k, __ln))
                    print("[ABP_DEBUG] --- END PRE-EXCEPT ---")
            except Exception as __e:
                try:
                    _abp_dbg("pre_except_dump_fail=%r" % (__e,))
                except Exception:
                    pass

        except InvalidTag:
            # ABP_DEBUG_LOCATE_SALT_IV_TAG_V71C
            try:
                import os as __os71c
                __dbg71c = (__os71c.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'))
                if __dbg71c:
                    __raw = None
                    try:
                        with open(backup_path,'rb') as __f:
                            __raw = __f.read()
                    except Exception as __e:
                        __raw = None
                        print('[ABP_DEBUG] v71c_read_fail=%r' % (__e,))
                    if __raw is not None:
                        __n = len(__raw)
                        print('[ABP_DEBUG] v71c_file_size=%d' % (__n,))
                        print('[ABP_DEBUG] v71c_first64_hex=%s' % (__raw[:64].hex(),))
                        def __pos(x):
                            if x is None: return -2
                            try:
                                return __raw.find(bytes(x))
                            except Exception:
                                return -3
                        __ps = __pos(salt if ('salt' in locals()) else None)
                        __pi = __pos(iv if ('iv' in locals()) else (nonce if ('nonce' in locals()) else None))
                        __pt = __pos(tag if ('tag' in locals()) else None)
                        print('[ABP_DEBUG] v71c_pos_salt=%d v71c_pos_iv=%d v71c_pos_tag=%d' % (__ps, __pi, __pt))
                        if ('tag' in locals()) and isinstance(tag,(bytes,bytearray)) and len(tag)==16:
                            __tb = bytes(tag)
                            __tag_end = (__n>=16 and __raw[-16:] == __tb)
                            __last = __raw.rfind(__tb)
                            print('[ABP_DEBUG] v71c_tag_at_end=%s v71c_rfind_tag=%d' % (str(__tag_end), __last))
            except Exception as __e:
                try:
                    _abp_dbg('v71c_fail=%r' % (__e,))
                except Exception:
                    pass

            # ABP_DEBUG_JSON_TO_BIN_BOUNDARY_V66
            try:
                import os as __os
                if __os.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
                    __raw = None
                    try:
                        with open(backup_path,'rb') as __f:
                            __raw = __f.read()
                    except Exception as __e2:
                        print('[ABP_DEBUG] v66_read_fail=%r' % (__e2,))
                        __raw = None
            
                    if __raw is not None:
                        __n = len(__raw)
                        __tag_end = False
                        try:
                            __tag_end = ('tag' in locals() and tag is not None and __n>=16 and __raw[-16:] == tag)
                        except Exception:
                            __tag_end = False
                        __end = (__n-16) if __tag_end else __n
                        print('[ABP_DEBUG] v66_file_size=%d tag_at_end=%s end=%d' % (__n, __tag_end, __end))
            
                        # helper: printable ratio in a bytes window
                        def __nonprint_ratio(b):
                            if not b: return 0.0
                            np = 0
                            for x in b:
                                if not ((x in (9,10,13)) or (32 <= x <= 126)):
                                    np += 1
                            return np / float(len(b))
            
                        # show last 128 bytes before tag (should be binary-ish if ciphertext is right before tag)
                        __tail = __raw[max(0,__end-128):__end]
                        print('[ABP_DEBUG] v66_pre_tag_nonprint_ratio=%.3f' % (__nonprint_ratio(__tail),))
                        try:
                            print('[ABP_DEBUG] v66_pre_tag_hex=%s' % (__tail.hex(),))
                        except Exception:
                            pass
            
                        # Search for JSON terminator close to where binary starts.
                        # We scan backwards from end-16 up to 64MB max (fast enough).
                        __scan_back = min(__end, 64*1024*1024)
                        __start = __end - __scan_back
                        __cand = -1
                        __cands_found = 0
                        # patterns of JSON end (bytes)
                        __pats = [b'}\\n', b']\\n', b'}\\r\\n', b']\\r\\n']
                        for __i in range(__end-2, __start, -1):
                            for __pat in __pats:
                                __lp = len(__pat)
                                if __i-__lp+1 < __start: continue
                                if __raw[__i-__lp+1:__i+1] == __pat:
                                    __after = __i+1
                                    # measure nonprint ratio right after terminator (4KB)
                                    __win = __raw[__after:min(__after+4096, __end)]
                                    __r = __nonprint_ratio(__win)
                                    if __r >= 0.55 and len(__win) >= 512:
                                        __cand = __after
                                        __cands_found += 1
                                        print('[ABP_DEBUG] v66_candidate_off=%d term=%r after_nonprint_ratio=%.3f' % (__cand, __pat, __r))
                                        # show snippets around boundary
                                        __pre = __raw[max(__start, __cand-120):__cand]
                                        __post = __raw[__cand:min(__cand+120, __end)]
                                        try:
                                            __pre_txt = ''.join([chr(x) if ((x in (9,10,13)) or (32 <= x <= 126)) else '.' for x in __pre])
                                        except Exception:
                                            __pre_txt = '<pre_fail>'
                                        print('[ABP_DEBUG] v66_boundary_pre_ascii=%s' % (__pre_txt,))
                                        try:
                                            print('[ABP_DEBUG] v66_boundary_post_hex=%s' % (__post.hex(),))
                                        except Exception:
                                            pass
                                        # stop at first strong candidate
                                        break
                            if __cand >= 0: break
                            if __cand >= 0: break
            
                        if __cand < 0:
                            print('[ABP_DEBUG] v66_no_json_end_candidate_found')
                        else:
                            if __tag_end:
                                __ct = __raw[__cand:__end]
                                print('[ABP_DEBUG] v66_ct_len=%d head=%s tail=%s' % (len(__ct), __ct[:16].hex(), __ct[-16:].hex()))
            except Exception as __e:
                try:
                    _abp_dbg('v66_fail=%r' % (__e,))
                except Exception:
                    pass

            # ABP_DEBUG_PAYLOAD_BOUNDARY_V65
            try:
                import os as __os
                if __os.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
                    try:
                        with open(backup_path,'rb') as __f:
                            __raw = __f.read()
                    except Exception as __e2:
                        __raw = None
                        print('[ABP_DEBUG] boundary_read_fail=%r' % (__e2,))
            
                    if __raw is not None:
                        __n = len(__raw)
                        __tag_end = False
                        try:
                            __tag_end = ('tag' in locals() and tag is not None and __n>=16 and __raw[-16:] == tag)
                        except Exception:
                            __tag_end = False
                        __end = (__n-16) if __tag_end else __n
                        print('[ABP_DEBUG] boundary_file_size=%d tag_at_end=%s end=%d' % (__n, __tag_end, __end))
            
                        # Scan first 512KB for transition from text-ish to binary-ish (window 1024).
                        __scan_max = min(__end, 512*1024)
                        __win = 1024
                        __thr = 0.20  # non-printable ratio threshold
                        __best = None
            
                        def __is_printable(b):
                            # allow TAB/LF/CR and visible ASCII 0x20..0x7E
                            return (b in (9,10,13)) or (32 <= b <= 126)
            
                        for __i in range(0, max(0, __scan_max-__win), 64):
                            __chunk = __raw[__i:__i+__win]
                            if not __chunk: break
                            __np = 0
                            for __b in __chunk:
                                if not __is_printable(__b):
                                    __np += 1
                            __ratio = __np / float(len(__chunk))
                            if __ratio >= __thr:
                                __best = (__i, __ratio)
                                break
            
                        if __best is None:
                            print('[ABP_DEBUG] boundary_not_found_in_first_512KB')
                        else:
                            __off, __r = __best
                            print('[ABP_DEBUG] payload_boundary_guess_off=%d nonprint_ratio=%.3f win=%d' % (__off, __r, __win))
                            # show 96 bytes before (as safe ASCII) and 96 after (as hex)
                            __pre0 = max(0, __off-96)
                            __pre = __raw[__pre0:__off]
                            __post = __raw[__off: min(__off+96, __end)]
                            try:
                                __pre_txt = ''.join([chr(x) if __is_printable(x) else '.' for x in __pre])
                            except Exception:
                                __pre_txt = '<pre_decode_fail>'
                            print('[ABP_DEBUG] boundary_pre_ascii=%s' % (__pre_txt,))
                            print('[ABP_DEBUG] boundary_post_hex=%s' % (__post.hex(),))
            
                            # Also propose ciphertext candidate if tag_at_end
                            if __tag_end:
                                __ct = __raw[__off:__end]
                                print('[ABP_DEBUG] candidate_ct_len=%d head=%s tail=%s' % (len(__ct), __ct[:16].hex(), __ct[-16:].hex()))
            except Exception as __e:
                try:
                    _abp_dbg('payload_boundary_fail=%r' % (__e,))
                except Exception:
                    pass

            # ABP_DEBUG_VERIFY_LAYOUT_V64
            try:
                import os as __os
                if __os.environ.get('ABP_DEBUG_HDR','0') in ('1','true','TRUE','yes','YES'):
                    print('[ABP_DEBUG] --- LAYOUT FINDER (except InvalidTag) ---')
                    __raw = None
                    try:
                        with open(backup_path,'rb') as __f:
                            __raw = __f.read()
                    except Exception as __e2:
                        __raw = None
                        print('[ABP_DEBUG] read_fail=%r' % (__e2,))
            
                    if __raw is not None:
                        print('[ABP_DEBUG] file_size=%d' % (len(__raw),))
                        # Where are salt/iv/tag in the raw file?
                        try:
                            __isalt = __raw.find(salt) if 'salt' in locals() and salt is not None else -1
                        except Exception:
                            __isalt = -1
                        try:
                            __iiv   = __raw.find(iv) if 'iv' in locals() and iv is not None else (-1)
                        except Exception:
                            __iiv = -1
                        try:
                            __itag  = __raw.find(tag) if 'tag' in locals() and tag is not None else (-1)
                        except Exception:
                            __itag = -1
            
                        print('[ABP_DEBUG] idx_salt=%d idx_iv=%d idx_tag=%d' % (__isalt, __iiv, __itag))
            
                        # If tag appears multiple times, also check if it's at end
                        if 'tag' in locals() and tag is not None and len(__raw) >= 16:
                            __tag_end = (__raw[-16:] == tag)
                            print('[ABP_DEBUG] tag_at_end=%s' % (__tag_end,))
            
                        # Candidate layouts (print ciphertext head/tail lengths)
                        def __dump_ct(name, ct_bytes):
                            try:
                                if ct_bytes is None:
                                    print('[ABP_DEBUG] %s: ct=None' % (name,)); return
                                ln = len(ct_bytes)
                                h = ct_bytes[:16].hex() if ln>=16 else ct_bytes.hex()
                                t = ct_bytes[-16:].hex() if ln>=16 else ct_bytes.hex()
                                print('[ABP_DEBUG] %s: ct_len=%d head=%s tail=%s' % (name, ln, h, t))
                            except Exception as __e3:
                                print('[ABP_DEBUG] %s: dump_fail=%r' % (name, __e3))
            
                        # Common header guess: magic8 + ver2 + it2 = 12 bytes, then salt16, iv12
                        __off0 = 12
                        __off1 = __off0 + 16 + 12
                        # Layout A: [hdr12][salt16][iv12][tag16][ct...]
                        if len(__raw) > (__off1 + 16):
                            __dump_ct('LAYOUT_A(tag_then_ct)', __raw[__off1+16:])
                        # Layout B: [hdr12][salt16][iv12][ct...][tag16] (tag at end)
                        if len(__raw) > (__off1 + 16):
                            __dump_ct('LAYOUT_B(ct_then_tag_end)', __raw[__off1:len(__raw)-16])
                        # Layout C: use discovered indexes if present
                        if __iiv >= 0 and len(__raw) > (__iiv+12):
                            # if tag comes after iv
                            if __itag > (__iiv+12):
                                __dump_ct('LAYOUT_C(ct_between_iv_and_tag)', __raw[__iiv+12:__itag])
                            # if tag is at end
                            if len(__raw) >= 16:
                                __dump_ct('LAYOUT_C2(ct_after_iv_to_endminus16)', __raw[__iiv+12:len(__raw)-16])
            
                        print('[ABP_DEBUG] --- END LAYOUT FINDER ---')
            except Exception as __e:
                try:
                    _abp_dbg('layout_finder_fail=%r' % (__e,))
                except Exception:
                    pass

            # ABP_DEBUG_VERIFY_FIELDS_V61C
            try:
                import os as __os
                if __os.environ.get("ABP_DEBUG_HDR","0") in ("1","true","TRUE","yes","YES"):
                    __v = locals()
                    def __pick(*names):
                        for __n in names:
                            if __n in __v and __v.get(__n) is not None:
                                return __n, __v.get(__n)
                        return None, None
            
                    __saltN, __salt = __pick('salt','salt_bytes','kdf_salt','s')
                    __nonceN, __nonce = __pick('nonce','iv','nonce_bytes','n')
                    __tagN, __tag = __pick('tag','gcm_tag','tag_bytes','t')
                    __ctN, __ct = __pick('ciphertext','ct','data','payload','enc','blob','encrypted')
            
                    print("[ABP_DEBUG] --- FIELDS DUMP (in except InvalidTag) ---")
                    print("[ABP_DEBUG] iterations=%s GCM_TAG_LEN=%s" % (__v.get('iterations',None), globals().get('GCM_TAG_LEN',None)))
                    if __salt is not None and hasattr(__salt,'__len__'):
                        print("[ABP_DEBUG] %s_len=%d head=%s" % (__saltN, len(__salt), (__salt[:16].hex() if hasattr(__salt,'hex') else str(type(__salt)))))
                    else:
                        print("[ABP_DEBUG] salt=None (searched: salt/salt_bytes/kdf_salt/s)")
            
                    if __nonce is not None and hasattr(__nonce,'__len__'):
                        print("[ABP_DEBUG] %s_len=%d head=%s" % (__nonceN, len(__nonce), (__nonce[:16].hex() if hasattr(__nonce,'hex') else str(type(__nonce)))))
                    else:
                        print("[ABP_DEBUG] nonce/iv=None (searched: nonce/iv/nonce_bytes/n)")
            
                    if __tag is not None and hasattr(__tag,'__len__'):
                        print("[ABP_DEBUG] %s_len=%d head=%s" % (__tagN, len(__tag), (__tag[:16].hex() if hasattr(__tag,'hex') else str(type(__tag)))))
                    else:
                        print("[ABP_DEBUG] tag=None (searched: tag/gcm_tag/tag_bytes/t)")
            
                    if __ct is not None and hasattr(__ct,'__len__'):
                        try:
                            __h = __ct[:16].hex() if len(__ct)>=16 else __ct.hex()
                            __t = __ct[-16:].hex() if len(__ct)>=16 else __ct.hex()
                            print("[ABP_DEBUG] %s_len=%d head=%s tail=%s" % (__ctN, len(__ct), __h, __t))
                        except Exception:
                            print("[ABP_DEBUG] %s present but cannot hex()" % (__ctN,))
                    else:
                        print("[ABP_DEBUG] ciphertext/data=None (searched: ciphertext/ct/data/payload/enc/blob/encrypted)")
            
                    print("[ABP_DEBUG] --- END FIELDS DUMP ---")
            except Exception as __e:
                pass

            # AES-GCM: impossible de distinguer mauvais mdp vs corruption => auth_failed
            self._log_error("VERIFY FAIL InvalidTag file=%s", os.path.basename(backup_path))
            self.last_verify_error = "auth_failed"
            return False, "auth_failed"
        except Exception:
            self._log_exception("VERIFY FAILED")
            self.last_verify_error = "exception"
            return False, "exception"

    def verify_backup(self, backup_path: str, password: str) -> bool:
        ok, _reason = self.verify_backup_detailed(backup_path, password)
        return ok

    # Aliases (pour compat cote CLI / altiora.py fallback)
    def verify(self, backup_path: str, password: str) -> bool:
        # ABP_CORE_HDR_ITER_V51
        __abp_it = int(header.get("iterations", 300_000))  # v75f: fallback stable (no autodetect helper)
        if __abp_it is not None:
            iterations = int(__abp_it)
            _abp_dbg(f'iterations override -> {iterations}')

        return self.verify_backup(backup_path, password)

    def verify_file(self, backup_path: str, password: str) -> bool:
        return self.verify_backup(backup_path, password)

    def verify_integrity(self, backup_path: str, password: str) -> bool:
        return self.verify_backup(backup_path, password)

    # ------------------------------------------------------------------
    # RESTORE LEGACY (optionnel)
    # ------------------------------------------------------------------
    def _restore_legacy_json(self, backup_path: str, output_dir: str, password: str) -> bool:
        return False

    # ------------------------------------------------------------------
    # RESTORE (container)
    # ------------------------------------------------------------------
    def restore_backup(self, backup_path: str, output_dir: str, password: str) -> bool:
        start = time.time()
        tmp_archive: Optional[str] = None

        backup_path = os.path.abspath(backup_path)
        output_dir = os.path.abspath(output_dir)
        os.makedirs(output_dir, exist_ok=True)

        if not os.path.exists(backup_path):
            print("ERROR Fichier de backup introuvable.")
            return False

        if not password:
            print("ERROR Echec restauration: mot de passe vide.")
            return False

        header = self._read_container_header(backup_path)
        if not header:
            print("ERROR Echec restauration: format non reconnu.")
            return False

        # ------------------------------------------------------------------
        # FREE: limitation RESTORE uniquement (<= 100 Mo restaurables)
        # Blocage AVANT toute ecriture sur disque.
        # ------------------------------------------------------------------
        if EDITION == "FREE":
            try:
                plain_size = int(header.get("plain_size") or 0)
                if plain_size <= 0:
                    manifest = header.get("manifest", [])
                    if isinstance(manifest, list):
                        plain_size = sum(int(it.get("size") or 0) for it in manifest)
                if plain_size > FREE_RESTORE_LIMIT_BYTES:
                    total_mb = plain_size / (1024 * 1024)
                    print("\nERROR RESTAURATION BLOQUEE - Altiora Backup Free")
                    print(f"   Taille a restaurer : {total_mb:.2f} Mo")
                    print("   Limite Free        : 100 Mo\n")
                    print("-> Passez a Altiora Backup Pro (49,99€/mois) pour restaurer sans limite.")
                    self.last_error_code = "FREE_LIMIT"
                    self.last_exit_code = 101
                    return False
            except Exception:
                print("\nERROR RESTAURATION BLOQUEE - Altiora Backup Free (erreur taille)")
                print("-> Passez a Altiora Backup Pro (49,99€/mois) pour restaurer sans limite.")
                return False

        magic_len = int(header.get("_magic_len", 8))
        header_len = int(header.get("_header_len", 0))

        salt = _b64d(header["salt_b64"])
        iv = _b64d(header["iv_b64"])
        iterations = int(header.get("iterations", 300_000))
        # ABP_CORE_HDR_ITER_V51
        __abp_it = None  # v75g3: autodetect removed (stable); use header["iterations"]
        if __abp_it is not None:
            iterations = int(__abp_it)
            _abp_dbg(f'iterations override -> {iterations}')

        key = _derive_key(password, salt, iterations)

        try:
            file_size = os.path.getsize(backup_path)
            ciphertext_start = magic_len + 2 + 4 + header_len
            ciphertext_end = file_size - GCM_TAG_LEN
            if ciphertext_end <= ciphertext_start:
                print("ERROR Echec restauration: contenu chiffre invalide.")
                return False

            with open(backup_path, "rb") as f:
                f.seek(-GCM_TAG_LEN, os.SEEK_END)
                tag = f.read(GCM_TAG_LEN)
                if len(tag) != GCM_TAG_LEN:
                    print("ERROR Echec restauration: tag GCM invalide.")
                    return False

                header_raw = header.get("_header_raw", None)

                suffix = ".tar.gz" if header.get("archive") == "tar.gz" else ".tar"

                def _decrypt_to_tmp_with_aad(aad_bytes):
                    nonlocal tmp_archive
                    f.seek(ciphertext_start, os.SEEK_SET)
                    decryptor = Cipher(algorithms.AES(key), modes.GCM(iv, tag)).decryptor()
                    if aad_bytes is not None:
                        decryptor.authenticate_additional_data(aad_bytes)

                    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                        tmp_archive = tmp.name

                    remaining = ciphertext_end - ciphertext_start
                    with open(tmp_archive, "wb") as out:
                        while remaining > 0:
                            to_read = min(1024 * 1024, remaining)
                            chunk = f.read(to_read)
                            if not chunk:
                                break
                            remaining -= len(chunk)
                            out.write(decryptor.update(chunk))
                        out.write(decryptor.finalize())

                # v74a: priorite AAD (nouveau), puis fallback legacy sans AAD
                try:
                    if header_raw is not None:
                        _decrypt_to_tmp_with_aad(header_raw)
                    else:
                        raise InvalidTag()
                except InvalidTag:
                    _decrypt_to_tmp_with_aad(None)

            mode = "r:gz" if header.get("archive") == "tar.gz" else "r"
            restored = 0
            total_bytes = 0

            with tarfile.open(tmp_archive, mode) as tf:
                members = tf.getmembers()
                if not members:
                    print("ERROR Echec restauration: archive interne vide.")
                    return False

                for member in members:
                    if member.isdir():
                        safe_dir = _safe_join(output_dir, member.name)
                        os.makedirs(safe_dir, exist_ok=True)
                        continue

                    safe_path = _safe_join(output_dir, member.name)
                    os.makedirs(os.path.dirname(safe_path), exist_ok=True)

                    src = tf.extractfile(member)
                    if src is None:
                        continue

                    with open(safe_path, "wb") as dst:
                        while True:
                            buf = src.read(1024 * 1024)
                            if not buf:
                                break
                            dst.write(buf)
                            total_bytes += len(buf)

                    restored += 1

            elapsed = time.time() - start
            print(f"OK Restauration OK: {restored} fichier(s) dans {output_dir}")
            print(f"   FILE Donnees: {total_bytes} bytes")
            print(f"   TIME  Duree: {elapsed:.2f}s")
            return restored > 0

        except InvalidTag:
            print("ERROR Echec restauration: mot de passe incorrect OU backup corrompu (AES-GCM).")
            return False
        except Exception as e:
            print(f"ERROR Echec restauration: {type(e).__name__}: {e}")
            return False
        finally:
            try:
                if tmp_archive and os.path.exists(tmp_archive):
                    os.remove(tmp_archive)
            except Exception:
                pass



















