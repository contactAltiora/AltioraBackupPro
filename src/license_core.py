# ABP_ASCII_OUTPUT_V3
import os, json, base64
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey


# IMPORTANT:
# - La clé privée ne doit JAMAIS être dans le repo.
# - Ici: clé publique embarquée dans le binaire Pro.
PUBLIC_KEY_B64_EMBEDDED = "7fEUhLtG8qTqCOuQNQfQZRQLfln0BJMq/oJwwVNHSqY="  # injected at build-time for Pro
PUBLIC_KEY_B64 = (os.environ.get("ALTIORA_PUBLIC_KEY_B64", "").strip()
                 or PUBLIC_KEY_B64_EMBEDDED.strip())

PRODUCT = "ALTIORA_BACKUP_PRO"


def _canonical_payload(lic: Dict[str, Any]) -> bytes:
    unsigned = dict(lic)
    unsigned.pop("signature_b64", None)
    unsigned.pop("signature", None)
    # Canonique + stable
    return json.dumps(
        unsigned,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _parse_dt(s: str) -> Optional[datetime]:
    try:
        # accepte "2026-12-31" ou ISO "2026-12-31T23:59:59Z"
        if len(s) == 10:
            return datetime.fromisoformat(s + "T23:59:59+00:00")
        s2 = s.replace("Z", "+00:00")
        dt = datetime.fromisoformat(s2)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _load_json(path: str) -> Optional[Dict[str, Any]]:
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            obj = json.load(f)
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def find_license_file() -> Optional[str]:
    # Ordre: env -> cwd -> userprofile appdata (simple)
    envp = os.environ.get("ALTIORA_LICENSE_FILE", "").strip()
    if envp and os.path.exists(envp):
        return envp

    cwd = os.path.abspath(os.getcwd())
    p1 = os.path.join(cwd, "license.json")
    if os.path.exists(p1):
        return p1

    home = os.path.expanduser("~")
    p2 = os.path.join(home, ".altiora_backup_pro", "license.json")
    if os.path.exists(p2):
        return p2

    return None


def verify_license() -> Tuple[bool, str]:
    if not PUBLIC_KEY_B64:
        return False, "missing_public_key"

    lic_path = find_license_file()
    if not lic_path:
        return False, "license_not_found"

    lic = _load_json(lic_path)
    if not lic:
        return False, "license_unreadable"

    # Champs attendus
    product = str(lic.get("product", "")).strip()
    edition = str(lic.get("edition", "")).strip().upper()
    sig_b64 = (lic.get("signature_b64") or lic.get("signature") or "").strip()

    if product != PRODUCT:
        return False, "bad_product"
    if edition != "PRO":
        return False, "bad_edition"
    if not sig_b64:
        return False, "missing_signature"

    # Expiration optionnelle
    exp = lic.get("expires_at")
    if exp:
        dt = _parse_dt(str(exp))
        if not dt:
            return False, "bad_expires_at"
        if datetime.now(timezone.utc) > dt:
            return False, "expired"

    try:
        pub = Ed25519PublicKey.from_public_bytes(base64.b64decode(PUBLIC_KEY_B64))
        payload = _canonical_payload(lic)
        sig = base64.b64decode(sig_b64)
        pub.verify(sig, payload)
        return True, "ok"
    except Exception:
        return False, "signature_invalid"

# ABP_LICENSE_RUNTIME_VERIFY_V1
# Adds Ed25519 license verification + expiry checks (non-invasive).
import os
import json
import base64
import datetime as _dt
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ed25519


def _abp_canonical_json_bytes(obj: dict) -> bytes:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _abp_utc_today_iso() -> str:
    return _dt.datetime.utcnow().date().isoformat()


def abp_verify_pro_license_file(
    license_json_path: str,
    public_key_pem_path: str = str(Path("keys") / "altiora_public_key.pem"),
    require_product: str = "AltioraBackupPro",
    require_edition: str = "PRO",
) -> dict:
    """
    Verifies:
      - license json exists
      - sibling .sig exists (base64)
      - Ed25519 signature over canonical JSON
      - product/edition match
      - expiry >= today(UTC)
    Returns parsed license dict on success. Raises RuntimeError on failure.
    """
    lic_path = Path(license_json_path)
    if not lic_path.exists():
        raise RuntimeError(f"License file not found: {lic_path}")

    sig_path = Path(str(lic_path)[:-5] + ".sig") if str(lic_path).endswith(".json") else Path(str(lic_path) + ".sig")
    if not sig_path.exists():
        raise RuntimeError(f"License signature not found: {sig_path}")

    pub_path = Path(public_key_pem_path)
    if not pub_path.exists():
        raise RuntimeError(f"Public key not found: {pub_path}")

    lic = json.loads(lic_path.read_text(encoding="utf-8"))
    payload = _abp_canonical_json_bytes(lic)

    sig_b64 = sig_path.read_text(encoding="utf-8").strip()
    sig = base64.b64decode(sig_b64)

    pub = serialization.load_pem_public_key(pub_path.read_bytes())
    if not isinstance(pub, ed25519.Ed25519PublicKey):
        raise RuntimeError("Unsupported public key type (expected Ed25519).")

    try:
        pub.verify(sig, payload)
    except Exception as e:
        raise RuntimeError(f"License signature invalid: {e}")

    if lic.get("product") != require_product:
        raise RuntimeError(f"License product mismatch: {lic.get('product')}")

    if lic.get("edition") != require_edition:
        raise RuntimeError(f"License edition mismatch: {lic.get('edition')}")

    expiry = lic.get("expiry", "")
    if not expiry or expiry < _abp_utc_today_iso():
        raise RuntimeError(f"License expired (expiry={expiry}, today={_abp_utc_today_iso()})")

    return lic


def abp_verify_pro_license_env(strict: bool = False) -> dict | None:
    """
    Uses env ALTIORA_LICENSE_FILE.
    - strict=False: returns None if missing/invalid
    - strict=True: raises RuntimeError if missing/invalid
    """
    lic_path = os.environ.get("ALTIORA_LICENSE_FILE", "").strip()
    if not lic_path:
        if strict:
            raise RuntimeError("ALTIORA_LICENSE_FILE requis (mode strict).")
        return None

    try:
        return abp_verify_pro_license_file(lic_path)
    except Exception as e:
        if strict:
            raise
        return None

# ABP_LICENSE_GATE_V1
def _abp_env_truthy(name: str) -> bool:
    v = (os.environ.get(name, "") or "").strip().lower()
    return v in ("1", "true", "yes", "y", "on")


def abp_require_pro_license_if_needed() -> dict | None:
    """
    Central gate for PRO features.
    - If ALTIORA_LICENSE_STRICT truthy => license required and must be valid.
    - Else => returns None if missing/invalid (soft-fail).
    """
    strict = _abp_env_truthy("ALTIORA_LICENSE_STRICT")
    return abp_verify_pro_license_env(strict=strict)

# ABP_VERIFY_LICENSE_V2_ED25519
def verify_license():
    """
    Backward-compatible API used by src.backup_core.py:
      returns (ok: bool, reason: str)

    V2 behavior:
      - Uses ALTIORA_LICENSE_FILE (path to *.license.json)
      - Expects sibling .sig (base64)
      - Verifies Ed25519 signature over canonical JSON
      - Checks product/edition + expiry (UTC)
    """
    try:
        lic_path = (os.environ.get("ALTIORA_LICENSE_FILE", "") or "").strip()
        if not lic_path:
            return (False, "missing_ALTIORA_LICENSE_FILE")

        if not os.path.exists(lic_path):
            return (False, "license_file_not_found")

        try:
            _lic = abp_verify_pro_license_file(lic_path)
            # Optional: keep small stable info for debugging
            _email = _lic.get("email", "")
            _exp = _lic.get("expiry", "")
            return (True, f"ed25519_ok:{_email}:{_exp}")
        except Exception as e:
            return (False, "ed25519_invalid:" + str(e))

    except Exception as e_outer:
        return (False, "verify_license_error:" + e_outer.__class__.__name__)

