# -*- coding: utf-8 -*-
import base64
import re
import secrets
from dataclasses import dataclass
from typing import Tuple

from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# ASCII-only alphabet via Base32 (A-Z2-7). Easy to type, case-insensitive.
_GROUP = 4

def _chunk(s: str, n: int) -> str:
    return "-".join(s[i:i+n] for i in range(0, len(s), n))

def generate_recovery_key(num_bytes: int = 32) -> str:
    raw = secrets.token_bytes(num_bytes)  # 256-bit
    b32 = base64.b32encode(raw).decode("ascii").rstrip("=")  # strip padding
    # group for readability: XXXX-XXXX-...
    return _chunk(b32, _GROUP)

def normalize_recovery_key(key: str) -> bytes:
    if not key or not isinstance(key, str):
        raise ValueError("Recovery key is empty.")
    # keep only alnum, uppercase, remove dashes/spaces
    k = re.sub(r"[^A-Za-z0-9]", "", key).upper()
    # base32 requires padding to multiple of 8
    pad_len = (-len(k)) % 8
    k_padded = k + ("=" * pad_len)
    try:
        return base64.b32decode(k_padded, casefold=True)
    except Exception as e:
        raise ValueError("Invalid recovery key format.") from e

def derive_kek(recovery_key: str, salt: bytes, iterations: int = 200_000) -> bytes:
    rk = normalize_recovery_key(recovery_key)
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=iterations,
    )
    return kdf.derive(rk)

def wrap_master_key(master_key: bytes, recovery_key: str, salt: bytes) -> Tuple[bytes, bytes]:
    kek = derive_kek(recovery_key, salt)
    aes = AESGCM(kek)
    nonce = secrets.token_bytes(12)
    wrapped = aes.encrypt(nonce, master_key, None)
    return nonce, wrapped

def unwrap_master_key(wrapped: bytes, recovery_key: str, salt: bytes, nonce: bytes) -> bytes:
    kek = derive_kek(recovery_key, salt)
    aes = AESGCM(kek)
    return aes.decrypt(nonce, wrapped, None)

def confirm_recovery_key_once_printed(rk: str) -> None:
    # Mode 1: require confirmation by retyping LAST group
    last = rk.split("-")[-1]
    print("")
    print("IMPORTANT: this Recovery Key is shown only ONCE.")
    print("Store it OFF the PC (paper / safe / dedicated USB).")
    typed = input(f"Type the LAST group to confirm ( {last} ): ").strip().upper()
    if typed != last.upper():
        raise RuntimeError("Recovery key confirmation failed. Backup aborted by policy.")
