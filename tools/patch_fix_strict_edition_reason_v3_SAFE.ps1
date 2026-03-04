$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$path = Join-Path $root "src\backup_core.py"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# FAIL-CLOSED markers: we expect previous v2 markers
$need = @(
  'ABP_STRICT_MISSING_FLAG_V2',
  'ABP_STRICT_MISSING_GUARD_V2',
  'if EDITION_REQUESTED == "PRO" and _strict:',
  '_p = os.environ.get("ALTIORA_LICENSE_FILE", "").strip()',
  'EDITION_REASON = "env_free"'
)
foreach($m in $need){
  if($txt -notlike "*$m*"){ throw "FAIL-CLOSED: expected marker not found: $m" }
}

# Add final clamp after env_free assignment (idempotent)
if($txt -notlike "*ABP_STRICT_MISSING_FINAL_CLAMP_V3*"){
  $anchor = 'EDITION_REASON = "env_free"'
  $insert = $anchor + "`r`n" +
            '    # ABP_STRICT_MISSING_FINAL_CLAMP_V3' + "`r`n" +
            '    if "_strict_missing_license" in globals() and _strict_missing_license:' + "`r`n" +
            '        EDITION = "FREE"' + "`r`n" +
            '        EDITION_REASON = "strict_missing_ALTIORA_LICENSE_FILE"'
  $txt2 = $txt.Replace($anchor, $insert)
  if($txt2 -eq $txt){ throw "FAIL-CLOSED: could not insert final clamp after env_free anchor" }
  $txt = $txt2
}

Set-Content -LiteralPath $path -Value $txt -Encoding UTF8

py -m py_compile $path
Write-Host "OK: patched -> src\backup_core.py (STRICT reason final clamp, v3)"
