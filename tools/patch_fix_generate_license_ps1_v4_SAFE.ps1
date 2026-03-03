$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$psPath = Join-Path (Get-Location).Path "tools\generate_license.ps1"
$marker = "ABP_LICENSE_GEN_V4"

if(-not (Test-Path -LiteralPath $psPath)){
  throw "FAIL-CLOSED: tools\generate_license.ps1 introuvable."
}

$existing = Get-Content -LiteralPath $psPath -Encoding UTF8 -Raw
if($existing -notmatch $marker){
  throw "FAIL-CLOSED: marker V4 absent dans tools\generate_license.ps1 (refuse rewrite)."
}

$b64 = "IyBBQlBfTElDRU5TRV9HRU5fVjQKW0NtZGxldEJpbmRpbmcoKV0KcGFyYW0oCiAgW1BhcmFtZXRlcihNYW5kYXRvcnk9JHRydWUpXQogIFtzdHJpbmddICRFbWFpbCwKCiAgW1BhcmFtZXRlcigpXQogIFtpbnRdICREYXlzID0gMzY1LAoKICBbUGFyYW1ldGVyKCldCiAgW3N0cmluZ10gJE91dERpciA9ICIuXF9vdXRcbGljZW5zZXMiLAoKICBbUGFyYW1ldGVyKCldCiAgW3N0cmluZ10gJFByaXZhdGVLZXkgPSAiLlxrZXlzXGFsdGlvcmFfcHJpdmF0ZV9rZXkucGVtIgopCgokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0gIlN0b3AiCgokcmVwb1Jvb3QgPSBSZXNvbHZlLVBhdGggKEpvaW4tUGF0aCAkUFNTY3JpcHRSb290ICIuLiIpClNldC1Mb2NhdGlvbiAkcmVwb1Jvb3QgfCBPdXQtTnVsbAoKcHkgLlx0b29sc1xnZW5lcmF0ZV9saWNlbnNlLnB5IC0tZW1haWwgJEVtYWlsIC0tZGF5cyAkRGF5cyAtLW91dC1kaXIgJE91dERpciAtLXByaXZhdGUta2V5ICRQcml2YXRlS2V5CmlmKCRMQVNURVhJVENPREUgLW5lIDApewogIHRocm93ICJnZW5lcmF0ZV9saWNlbnNlLnB5IGZhaWxlZCAoZXhpdD0kTEFTVEVYSVRDT0RFKSIKfQ=="
$fixed = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))

Set-Content -LiteralPath $psPath -Value $fixed -Encoding UTF8
Write-Host "OK: tools\generate_license.ps1 fixed (V4)."
