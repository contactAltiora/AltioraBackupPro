$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$path = Join-Path $root "src\backup_core.py"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

# FAIL-CLOSED markers
$need = @(
  'EDITION_REQUESTED = os.environ.get("ALTIORA_EDITION", "FREE").upper()',
  'if EDITION_REQUESTED == "PRO" and _strict:',
  '_p = os.environ.get("ALTIORA_LICENSE_FILE", "").strip()',
  'EDITION_REQUESTED = "FREE"',
  'EDITION_REASON = "strict_missing_ALTIORA_LICENSE_FILE"',
  'if EDITION_REQUESTED == "PRO":'
)
foreach($m in $need){
  if($txt -notlike "*$m*"){ throw "FAIL-CLOSED: expected marker not found: $m" }
}

# (1) add flag (idempotent)
if($txt -notlike "*ABP_STRICT_MISSING_FLAG_V2*"){
  $anchor = 'EDITION_REQUESTED = os.environ.get("ALTIORA_EDITION", "FREE").upper()'
  $insert = $anchor + "`r`n" +
            '    # ABP_STRICT_MISSING_FLAG_V2' + "`r`n" +
            '    _strict_missing_license = False'
  $txt2 = $txt.Replace($anchor, $insert)
  if($txt2 -eq $txt){ throw "FAIL-CLOSED: insertion failed (flag)" }
  $txt = $txt2
}

# (2) strict block: keep requested=PRO, but mark missing license
$txt2 = $txt.Replace('        EDITION_REQUESTED = "FREE"', '        _strict_missing_license = True')
if($txt2 -eq $txt){ throw "FAIL-CLOSED: could not replace strict downgrade line" }
$txt = $txt2

# (3) prevent PRO license path when strict missing (single-line condition change)
if($txt -notlike "*ABP_STRICT_MISSING_GUARD_V2*"){
  $anchor = 'if EDITION_REQUESTED == "PRO":'
  $insert = 'if EDITION_REQUESTED == "PRO" and not _strict_missing_license:  # ABP_STRICT_MISSING_GUARD_V2'
  $txt2 = $txt.Replace($anchor, $insert)
  if($txt2 -eq $txt){ throw "FAIL-CLOSED: could not patch PRO condition" }
  $txt = $txt2
}

# (4) enforce reason if strict missing (idempotent)
if($txt -notlike "*ABP_STRICT_MISSING_FINAL_V2*"){
  $anchor = 'EDITION_REASON = "strict_missing_ALTIORA_LICENSE_FILE"'
  # Put a final clamp right after the reason is assigned in strict block (safe, localized)
  $insert = $anchor + "`r`n" +
            '        # ABP_STRICT_MISSING_FINAL_V2' + "`r`n" +
            '        EDITION = "FREE"'
  $txt2 = $txt.Replace($anchor, $insert)
  if($txt2 -eq $txt){ throw "FAIL-CLOSED: could not add strict final clamp" }
  $txt = $txt2
}

Set-Content -LiteralPath $path -Value $txt -Encoding UTF8

# Compile check (fail fast)
py -m py_compile $path
Write-Host "OK: patched -> src\backup_core.py (STRICT missing license reason fixed, v2)"
