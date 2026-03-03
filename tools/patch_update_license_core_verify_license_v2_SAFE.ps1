$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$p = Join-Path (Get-Location).Path "src\license_core.py"
if(-not (Test-Path -LiteralPath $p)){ throw "FAIL-CLOSED: src\license_core.py introuvable." }

$txt = Get-Content -LiteralPath $p -Encoding UTF8 -Raw

# Preconditions: we require our new verifier to be present
if($txt -notmatch "ABP_LICENSE_RUNTIME_VERIFY_V1"){
  throw "FAIL-CLOSED: ABP_LICENSE_RUNTIME_VERIFY_V1 absent dans src\license_core.py"
}

$marker = "ABP_VERIFY_LICENSE_V2_ED25519"
if($txt -match $marker){
  Write-Host "Already present: verify_license V2. No change."
  exit 0
}

$append = @'
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
'@

$txt2 = $txt.TrimEnd() + "

" + $append + "
"
Set-Content -LiteralPath $p -Value $txt2 -Encoding UTF8
Write-Host "OK: updated verify_license() -> V2 Ed25519 (src\license_core.py)"
