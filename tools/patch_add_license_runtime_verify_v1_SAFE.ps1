$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$p = Join-Path (Get-Location).Path "src\license_core.py"
if(-not (Test-Path -LiteralPath $p)){ throw "FAIL-CLOSED: src\license_core.py introuvable." }

$txt = Get-Content -LiteralPath $p -Encoding UTF8 -Raw
$marker = "ABP_LICENSE_RUNTIME_VERIFY_V1"
if($txt -match $marker){
  Write-Host "Already present: license runtime verify V1. No change."
  exit 0
}

$append = @'
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
'@

$txt2 = $txt.TrimEnd() + "

" + $append + "
"
Set-Content -LiteralPath $p -Value $txt2 -Encoding UTF8
Write-Host "OK: added license runtime verify V1 -> src\license_core.py"
