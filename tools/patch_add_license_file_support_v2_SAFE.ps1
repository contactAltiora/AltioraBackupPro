$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$module = Join-Path $repo "src\license_info.py"

if (!(Test-Path $module)) {
    throw "src\license_info.py introuvable"
}

Write-Host "PATCH: add license file support v2"

$new = @'
import os
import json

def _load_license_data():
    env_path = os.environ.get("ALTIORA_LICENSE_FILE")
    candidates = []

    if env_path:
        candidates.append(env_path)

    candidates.append(os.path.join(os.getcwd(), "license", "altiora_license.json"))

    for path in candidates:
        if path and os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return data, path
            except Exception:
                return None, path

    return None, None

def show_license_info():
    edition = "FREE"
    status = "active"
    source = "fallback_free"
    restore_limit = "1 GB"
    customer = "N/A"

    data, path = _load_license_data()

    if data:
        edition = str(data.get("edition", "FREE"))
        status = str(data.get("status", "active"))
        customer = str(data.get("customer", "N/A"))
        restore_limit = str(data.get("restore_limit", "1 GB"))
        source = path

    print("")
    print("=== LICENSE INFO ===")
    print("")
    print("Edition :", edition)
    print("License status :", status)
    print("License source :", source)
    print("Customer :", customer)
    print("Restore limit :", restore_limit)
    print("")
'@

Set-Content -LiteralPath $module -Value $new -Encoding UTF8
Write-Host "src/license_info.py reecrit"
Write-Host "PATCH OK"