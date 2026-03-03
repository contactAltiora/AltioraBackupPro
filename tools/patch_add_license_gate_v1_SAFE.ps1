$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$p = Join-Path (Get-Location).Path "src\license_core.py"
if(-not (Test-Path -LiteralPath $p)){ throw "FAIL-CLOSED: src\license_core.py introuvable." }

$txt = Get-Content -LiteralPath $p -Encoding UTF8 -Raw
$marker = "ABP_LICENSE_GATE_V1"
if($txt -match $marker){
  Write-Host "Already present: license gate V1. No change."
  exit 0
}

$append = @'
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
'@

$txt2 = $txt.TrimEnd() + "

" + $append + "
"
Set-Content -LiteralPath $p -Value $txt2 -Encoding UTF8
Write-Host "OK: added license gate V1 -> src\license_core.py"
