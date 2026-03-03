$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$pyPath = Join-Path $root "tools\generate_license.py"
$psPath = Join-Path $root "tools\generate_license.ps1"
$marker = "ABP_LICENSE_GEN_V4"

# ----------------------------
# (A) tools\generate_license.py
# ----------------------------
$py = @'
#!/usr/bin/env python3
# ABP_LICENSE_GEN_V4
# Altiora Backup Pro - License generator (email-based, signed)
#
# Usage:
#   py tools/generate_license.py --email client@mail.com --days 365 --out-dir .\_out\licenses --private-key .\keys\altiora_private_key.pem
#
# Output:
#   <out-dir>\AltioraBackupPro_PRO_<email>_<issued>_<expiry>.license.json
#   <same>.sig  (base64)
#
import argparse
import base64
import datetime as dt
import json
import re
import sys
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def utc_today_iso() -> str:
    return dt.datetime.utcnow().date().isoformat()


def add_days(date_iso: str, days: int) -> str:
    d = dt.date.fromisoformat(date_iso)
    return (d + dt.timedelta(days=days)).isoformat()


def safe_slug(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9@._+-]+", "_", s)
    return s.replace("@", "_at_")


def canonical_json_bytes(obj: dict) -> bytes:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sign_bytes(private_key_pem_path: Path, payload: bytes) -> bytes:
    with open(private_key_pem_path, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)

    sig = private_key.sign(
        payload,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
        hashes.SHA256(),
    )
    return sig


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--email", required=True, help="Client email (license identity)")
    ap.add_argument("--days", type=int, default=365, help="Validity in days (default 365)")
    ap.add_argument("--issued", default=utc_today_iso(), help="Issued date ISO (YYYY-MM-DD, default today UTC)")
    ap.add_argument("--product", default="AltioraBackupPro", help="Product name")
    ap.add_argument("--edition", default="PRO", choices=["PRO"], help="Edition (PRO only)")
    ap.add_argument("--out-dir", default=str(Path("_out") / "licenses"), help="Output directory")
    ap.add_argument("--private-key", default=str(Path("keys") / "altiora_private_key.pem"), help="Private key PEM path")
    ap.add_argument("--note", default="", help="Optional internal note")
    args = ap.parse_args()

    email = args.email.strip()
    if "@" not in email or len(email) < 5:
        print("ERROR: email seems invalid", file=sys.stderr)
        return 2

    issued = args.issued
    expiry = add_days(issued, args.days)

    lic = {
        "product": args.product,
        "edition": args.edition,
        "email": email,
        "issued": issued,
        "expiry": expiry,
    }
    if args.note:
        lic["note"] = args.note

    payload = canonical_json_bytes(lic)

    priv_path = Path(args.private_key)
    if not priv_path.exists():
        print(f"ERROR: private key not found: {priv_path}", file=sys.stderr)
        return 2

    sig = sign_bytes(priv_path, payload)
    sig_b64 = base64.b64encode(sig).decode("ascii")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    fname_base = f"{args.product}_{args.edition}_{safe_slug(email)}_{issued}_{expiry}.license"
    lic_path = out_dir / f"{fname_base}.json"
    sig_path = out_dir / f"{fname_base}.sig"

    lic_path.write_text(json.dumps(lic, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sig_path.write_text(sig_b64 + "\n", encoding="utf-8")

    print("OK: license written:")
    print(f"  {lic_path}")
    print("OK: signature written:")
    print(f"  {sig_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

if(Test-Path -LiteralPath $pyPath){
  $existing = Get-Content -LiteralPath $pyPath -Encoding UTF8 -Raw
  if($existing -notmatch $marker){
    throw "FAIL-CLOSED: tools\generate_license.py existe mais marker absent (refuse overwrite)."
  }
  Write-Host "Already present: tools\generate_license.py (V4). No change."
} else {
  Set-Content -LiteralPath $pyPath -Value $py -Encoding UTF8
  Write-Host "OK: created -> tools\generate_license.py"
}

# ----------------------------
# (B) tools\generate_license.ps1
# ----------------------------
$ps = @'
# ABP_LICENSE_GEN_V4
param(
  [Parameter(Mandatory=True)][string],
  [int] = 365,
  [string] = ".\_out\licenses",
  [string] = ".\keys\altiora_private_key.pem"
)
Stop="Stop"
Set-Location (Resolve-Path (Join-Path  "..")) | Out-Null

py .\tools\generate_license.py --email  --days  --out-dir  --private-key 
if( -ne 0){ throw "generate_license.py failed (exit=)" }
'@

if(Test-Path -LiteralPath $psPath){
  $existingPs = Get-Content -LiteralPath $psPath -Encoding UTF8 -Raw
  if($existingPs -notmatch $marker){
    throw "FAIL-CLOSED: tools\generate_license.ps1 existe mais marker absent (refuse overwrite)."
  }
  Write-Host "Already present: tools\generate_license.ps1 (V4). No change."
} else {
  Set-Content -LiteralPath $psPath -Value $ps -Encoding UTF8
  Write-Host "OK: created -> tools\generate_license.ps1"
}

Write-Host "DONE: License generator added (V4)."
