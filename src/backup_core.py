from src import license_core
import os
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


# -----------------------------
# Formats supportés
# -----------------------------
MAGIC8 = b"ALTBKUP1"      # 8 bytes EXACT
MAGIC9 = b"ALTBKUP10"     # 9 bytes (compat lecture)

if len(MAGIC8) != 8:
    raise ValueError("MAGIC8 doit faire exactement 8 bytes.")
if len(MAGIC9) != 9:
    raise ValueError("MAGIC9 doit faire exactement 9 bytes.")

VERSION = 1
GCM_IV_LEN = 12
GCM_TAG_LEN = 16


# ------------------------------------------------------------------
# EDITION / LIMITS
# ------------------------------------------------------------------
# -----------------------------
# Edition / Licence / Limites
# -----------------------------
EDITION_REQUESTED = os.environ.get("ALTIORA_EDITION", "PRO").upper()  # "FREE" or "PRO"
EDITION = EDITION_REQUESTED
EDITION_EFFECTIVE_REASON = "ENV"  # ENV / LICENSE_OK / LICENSE_FAIL:* / BYPASS_DEV
EDITION_REASON = EDITION_EFFECTIVE_REASON  # alias compat

FREE_RESTORE_LIMIT_BYTES = 100 * 1024 * 1024  # 100 MiB strict

# Si on demande PRO, on vérifie la licence. Sinon, on reste en FREE.
if EDITION == "PRO":
    # DEV only: bypass licence check (never set this in production)
    if os.environ.get("ALTIORA_DEV_BYPASS_LICENSE", "0") == "1":
        EDITION_EFFECTIVE_REASON = "BYPASS_DEV"
        EDITION_REASON = EDITION_EFFECTIVE_REASON
    else:
        ok, reason = license_core.verify_license()
        if ok:
            EDITION_EFFECTIVE_REASON = "LICENSE_OK"
            EDITION_REASON = EDITION_EFFECTIVE_REASON
        else:
            EDITION_EFFECTIVE_REASON = "LICENSE_FAIL:%s" % (reason,)
            EDITION_REASON = EDITION_EFFECTIVE_REASON
            EDITION = "FREE"



EXCLUDED_DIRS = {".git", "__pycache__", "node_modules", ".venv", "venv"}


def _b64e(b: bytes) -> str:
    return base64.b64encode(b).decode("utf-8")


def _b64d(s: str) -> bytes:
    return base64.b64decode(s.encode("utf-8"))


def _derive_key(password: str, salt: bytes, iterations: int) -> bytes:
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=int(iterations),
    )
    return kdf.derive(password.encode("utf-8"))


def _safe_join(base_dir: str, rel_path: str) -> str:
    """Empêche d'écrire en dehors de output_dir (path traversal)."""
    rel_path = str(rel_path).replace("\\", "/").lstrip("/")
    norm = os.path.normpath(rel_path)
    out = os.path.abspath(os.path.join(base_dir, norm))
    base = os.path.abspath(base_dir)
    if not out.startswith(base + os.sep) and out != base:
        raise ValueError(f"Chemin dangereux détecté: {rel_path}")
    return out


def _has_wildcards(path: str) -> bool:
    return any(ch in path for ch in ["*", "?", "["])


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

        # Permet à la CLI / tests d’afficher une “raison” si besoin
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
            raise FileNotFoundError(f"Source non trouvée: {abs_source}")

        base_dir = abs_source
        files: List[str] = []
        for root, dirs, filenames in os.walk(abs_source):
            dirs[:] = [d for d in dirs if d not in EXCLUDED_DIRS]
            for fn in filenames:
                files.append(os.path.abspath(os.path.join(root, fn)))

        if not files:
            raise FileNotFoundError(f"Dossier source vide (aucun fichier à sauvegarder): {abs_source}")

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
                print("❌ ERREUR BACKUP: mot de passe vide.")
                return False

            out_dir = os.path.dirname(output_path_abs) or "."
            os.makedirs(out_dir, exist_ok=True)

            backup_id = str(uuid.uuid4())[:16]

            try:
                base_dir, files_to_backup = self._collect_files(source_path)
            except FileNotFoundError as e:
                print(f"❌ ERREUR BACKUP: {e}")
                self._log_error("BACKUP FAILED reason=source_invalid source=%s", os.path.abspath(source_path))
                return False

            if not files_to_backup:
                print("❌ ERREUR BACKUP: aucun fichier à sauvegarder (source vide ou motif invalide).")
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
                print("❌ ERREUR BACKUP: impossible de lire les fichiers de la source (droits/accès).")
                self._log_error("BACKUP FAILED reason=manifest_empty source=%s", os.path.abspath(source_path))
                return False

            suffix = ".tar.gz" if compress else ".tar"
            mode = "w:gz" if compress else "w"

            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
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
                        print("❌ ERREUR BACKUP: archive interne vide (source invalide).")
                        self._log_error("BACKUP FAILED reason=empty_archive source=%s", os.path.abspath(source_path))
                        return False
                except Exception:
                    pass

                salt = os.urandom(16)
                iv = os.urandom(GCM_IV_LEN)
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

                with open(tmp_archive, "rb") as fin, open(tmp_out, "wb") as fout:
                    fout.write(MAGIC8)
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

                print(f"📦 Backup: {os.path.basename(output_path_abs)}")
                print(f"   🆔 ID: {backup_id}")
                print(f"   📄 Fichiers: {len(manifest)}")
                print(f"   📦 Taille: {os.path.getsize(output_path_abs)} bytes")
                print(f"   📄 Données (clair): {total_size} bytes")
                print(f" ⏱️  Durée: {elapsed:.2f}s")

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
            print(f"❌ ERREUR BACKUP: {type(e).__name__}: {e}")
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
                if head9 == MAGIC9:
                    magic_len = 9
                elif head9[:8] == MAGIC8:
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
    # VERIFY (bool) + VERIFY (détaillé)
    # ------------------------------------------------------------------
    def verify_backup_detailed(self, backup_path: str, password: str) -> Tuple[bool, str]:
        """
        Retourne (ok, reason).
        reason est une string stable exploitable côté CLI/tests.
        """
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
        key = _derive_key(password, salt, iterations)

        try:
            file_size = os.path.getsize(backup_path)
            ciphertext_start = magic_len + 2 + 4 + header_len
            ciphertext_end = file_size - GCM_TAG_LEN
            if ciphertext_end <= ciphertext_start:
                self.last_verify_error = "invalid_ciphertext_range"
                return False, "invalid_ciphertext_range"

            with open(backup_path, "rb") as f:
                f.seek(-GCM_TAG_LEN, os.SEEK_END)
                tag = f.read(GCM_TAG_LEN)
                if len(tag) != GCM_TAG_LEN:
                    self.last_verify_error = "invalid_gcm_tag"
                    return False, "invalid_gcm_tag"

                f.seek(ciphertext_start, os.SEEK_SET)
                decryptor = Cipher(algorithms.AES(key), modes.GCM(iv, tag)).decryptor()

                remaining = ciphertext_end - ciphertext_start
                while remaining > 0:
                    to_read = min(1024 * 1024, remaining)
                    chunk = f.read(to_read)
                    if not chunk:
                        break
                    remaining -= len(chunk)
                    decryptor.update(chunk)

                decryptor.finalize()

            self._log_info("VERIFY OK file=%s", os.path.basename(backup_path))
            return True, "ok"

        except InvalidTag:
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

    # Aliases (pour compat côté CLI / altiora.py fallback)
    def verify(self, backup_path: str, password: str) -> bool:
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
            print("❌ Fichier de backup introuvable.")
            return False

        if not password:
            print("❌ Échec restauration: mot de passe vide.")
            return False

        header = self._read_container_header(backup_path)
        if not header:
            print("❌ Échec restauration: format non reconnu.")
            return False

        # ------------------------------------------------------------------
        # FREE: limitation RESTORE uniquement (<= 100 Mo restaurables)
        # Blocage AVANT toute écriture sur disque.
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
                    print("\n❌ RESTAURATION BLOQUÉE — Altiora Backup Free")
                    print(f"   Taille à restaurer : {total_mb:.2f} Mo")
                    print("   Limite Free        : 100 Mo\n")
                    print("👉 Passez à Altiora Backup Pro (24,90€) pour restaurer sans limite.")
                    self.last_error_code = "FREE_LIMIT"
                    self.last_exit_code = 101
                    return False
            except Exception:
                print("\n❌ RESTAURATION BLOQUÉE — Altiora Backup Free (erreur taille)")
                print("👉 Passez à Altiora Backup Pro (24,90€) pour restaurer sans limite.")
                return False

        magic_len = int(header.get("_magic_len", 8))
        header_len = int(header.get("_header_len", 0))

        salt = _b64d(header["salt_b64"])
        iv = _b64d(header["iv_b64"])
        iterations = int(header.get("iterations", 300_000))
        key = _derive_key(password, salt, iterations)

        try:
            file_size = os.path.getsize(backup_path)
            ciphertext_start = magic_len + 2 + 4 + header_len
            ciphertext_end = file_size - GCM_TAG_LEN
            if ciphertext_end <= ciphertext_start:
                print("❌ Échec restauration: contenu chiffré invalide.")
                return False

            with open(backup_path, "rb") as f:
                f.seek(-GCM_TAG_LEN, os.SEEK_END)
                tag = f.read(GCM_TAG_LEN)
                if len(tag) != GCM_TAG_LEN:
                    print("❌ Échec restauration: tag GCM invalide.")
                    return False

                f.seek(ciphertext_start, os.SEEK_SET)
                decryptor = Cipher(algorithms.AES(key), modes.GCM(iv, tag)).decryptor()

                suffix = ".tar.gz" if header.get("archive") == "tar.gz" else ".tar"
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

            mode = "r:gz" if header.get("archive") == "tar.gz" else "r"
            restored = 0
            total_bytes = 0

            with tarfile.open(tmp_archive, mode) as tf:
                members = tf.getmembers()
                if not members:
                    print("❌ Échec restauration: archive interne vide.")
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
            print(f"✅ Restauration OK: {restored} fichier(s) dans {output_dir}")
            print(f"   📄 Données: {total_bytes} bytes")
            print(f"   ⏱️  Durée: {elapsed:.2f}s")
            return restored > 0

        except InvalidTag:
            print("❌ Échec restauration: mot de passe incorrect OU backup corrompu (AES-GCM).")
            return False
        except Exception as e:
            print(f"❌ Échec restauration: {type(e).__name__}: {e}")
            return False
        finally:
            try:
                if tmp_archive and os.path.exists(tmp_archive):
                    os.remove(tmp_archive)
            except Exception:
                pass
