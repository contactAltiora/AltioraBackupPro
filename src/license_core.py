import os, json, base64
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey


# IMPORTANT:
# - La clé privée ne doit JAMAIS être dans le repo.
# - Ici: clé publique embarquée dans le binaire Pro.
PUBLIC_KEY_B64 = os.environ.get("ALTIORA_PUBLIC_KEY_B64", "").strip()

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
