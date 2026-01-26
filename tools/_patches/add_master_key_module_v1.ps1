$root = "C:\Dev\AltioraBackupPro"
$dst  = Join-Path $root "src\master_key.py"

$py = @"
# -*- coding: utf-8 -*-
"""
Altiora Backup Pro - Master Key Manager (v1)

But:
- Générer une Master Key (32 bytes)
- La stocker localement, CHIFFRÉE par un KEK dérivé du mot de passe (KDF)
- Fournir: init / unlock / rotate

Stockage:
- JSON en UTF-8 (sans BOM)
- Emplacement par défaut: %APPDATA%\AltioraBackupPro\master_key.json
"""

from __future__ import annotations

import os
import json
import base64
import secrets
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


# =========================
# Helpers (base64)
# =========================
def b64e(b: bytes) -> str:
    return base64.b64encode(b).decode("ascii")

def b64d(s: str) -> bytes:
    return base64.b64decode(s.encode("ascii"))


# =========================
# Storage model
# =========================
@dataclass
class MasterKeyRecord:
    version: int
    kdf: str
    salt_b64: str
    n_b64: str
    r: int
    p: int
    nonce_b64: str
    ct_b64: str

    def to_dict(self) -> dict:
        return {
            "version": self.version,
            "kdf": self.kdf,
            "salt_b64": self.salt_b64,
            "n_b64": self.n_b64,
            "r": self.r,
            "p": self.p,
            "nonce_b64": self.nonce_b64,
            "ct_b64": self.ct_b64,
        }

    @staticmethod
    def from_dict(d: dict) -> "MasterKeyRecord":
        return MasterKeyRecord(
            version=int(d["version"]),
            kdf=str(d["kdf"]),
            salt_b64=str(d["salt_b64"]),
            n_b64=str(d["n_b64"]),
            r=int(d["r"]),
            p=int(d["p"]),
            nonce_b64=str(d["nonce_b64"]),
            ct_b64=str(d["ct_b64"]),
        )


class MasterKeyError(RuntimeError):
    pass


class MasterKeyManager:
    """
    Master Key chiffrée avec un KEK dérivé du password (Scrypt).
    """

    def __init__(self, storage_path: Optional[Path] = None) -> None:
        self.storage_path = storage_path or self.default_storage_path()

    @staticmethod
    def default_storage_path() -> Path:
        appdata = os.environ.get("APPDATA") or str(Path.home())
        return Path(appdata) / "AltioraBackupPro" / "master_key.json"

    def exists(self) -> bool:
        return self.storage_path.exists()

    def _derive_kek(self, password: str, salt: bytes, n: int, r: int, p: int) -> bytes:
        if not password:
            raise MasterKeyError("Password vide (impossible de dériver le KEK).")
        kdf = Scrypt(
            salt=salt,
            length=32,
            n=n,
            r=r,
            p=p,
        )
        return kdf.derive(password.encode("utf-8"))

    def init(self, password: str, *, n: int = 2**15, r: int = 8, p: int = 1) -> Path:
        """
        Crée une Master Key neuve et la stocke chiffrée.
        Refuse si elle existe déjà.
        """
        if self.exists():
            raise MasterKeyError(f"Master key déjà initialisée: {self.storage_path}")

        mk = secrets.token_bytes(32)         # Master Key
        salt = secrets.token_bytes(16)
        nonce = secrets.token_bytes(12)

        kek = self._derive_kek(password, salt, n=n, r=r, p=p)
        aes = AESGCM(kek)
        ct = aes.encrypt(nonce, mk, associated_data=b"ALTIORA_MASTER_KEY_V1")

        rec = MasterKeyRecord(
            version=1,
            kdf="scrypt",
            salt_b64=b64e(salt),
            n_b64=b64e(n.to_bytes(4, "big")),
            r=r,
            p=p,
            nonce_b64=b64e(nonce),
            ct_b64=b64e(ct),
        )

        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        self.storage_path.write_text(json.dumps(rec.to_dict(), indent=2), encoding="utf-8")
        return self.storage_path

    def unlock(self, password: str) -> bytes:
        """
        Déchiffre la Master Key avec le password (KEK via Scrypt).
        """
        if not self.exists():
            raise MasterKeyError("Master key non initialisée (fichier absent).")

        d = json.loads(self.storage_path.read_text(encoding="utf-8"))
        rec = MasterKeyRecord.from_dict(d)

        if rec.version != 1 or rec.kdf.lower() != "scrypt":
            raise MasterKeyError("Format master_key.json non supporté.")

        salt = b64d(rec.salt_b64)
        n = int.from_bytes(b64d(rec.n_b64), "big")
        nonce = b64d(rec.nonce_b64)
        ct = b64d(rec.ct_b64)

        kek = self._derive_kek(password, salt, n=n, r=rec.r, p=rec.p)
        aes = AESGCM(kek)

        try:
            mk = aes.decrypt(nonce, ct, associated_data=b"ALTIORA_MASTER_KEY_V1")
        except Exception as e:
            raise MasterKeyError("Mot de passe incorrect (déverrouillage master key impossible).") from e

        if len(mk) != 32:
            raise MasterKeyError("Master key corrompue (taille invalide).")
        return mk

    def rotate(self, old_password: str, new_password: str, *, n: int = 2**15, r: int = 8, p: int = 1) -> None:
        """
        Rotation du mot de passe: on déverrouille avec l'ancien, puis on re-chiffre avec le nouveau.
        La Master Key elle-même ne change pas.
        """
        mk = self.unlock(old_password)

        salt = secrets.token_bytes(16)
        nonce = secrets.token_bytes(12)
        kek = self._derive_kek(new_password, salt, n=n, r=r, p=p)
        aes = AESGCM(kek)
        ct = aes.encrypt(nonce, mk, associated_data=b"ALTIORA_MASTER_KEY_V1")

        rec = MasterKeyRecord(
            version=1,
            kdf="scrypt",
            salt_b64=b64e(salt),
            n_b64=b64e(n.to_bytes(4, "big")),
            r=r,
            p=p,
            nonce_b64=b64e(nonce),
            ct_b64=b64e(ct),
        )

        self.storage_path.write_text(json.dumps(rec.to_dict(), indent=2), encoding="utf-8")


def quick_selftest() -> Tuple[bool, str]:
    """
    Self-test minimal (sans dépendance projet).
    """
    tmp = Path(os.environ.get("TEMP", ".")) / "altiora_master_key_test.json"
    if tmp.exists():
        tmp.unlink()

    mgr = MasterKeyManager(tmp)
    mgr.init("test123")
    mk1 = mgr.unlock("test123")
    mgr.rotate("test123", "test456")
    mk2 = mgr.unlock("test456")

    ok = (mk1 == mk2) and (len(mk1) == 32)
    try:
        mgr.unlock("badpass")
        return (False, "unlock with badpass should have failed")
    except MasterKeyError:
        pass

    tmp.unlink(missing_ok=True)
    return (ok, "ok" if ok else "mismatch")
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($dst, $py, $utf8NoBom)
Write-Host "OK: src/master_key.py créé (UTF-8 no BOM) => $dst"
