$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$spec = Join-Path $repo "altiora.spec"

if (!(Test-Path $spec)) {
    throw "altiora.spec introuvable"
}

Write-Host "PATCH: align altiora.spec output name"

$txt = Get-Content -LiteralPath $spec -Encoding UTF8 -Raw

$old = "    name='altiora',"
$new = "    name='AltioraBackupPro',"

if ($txt.Contains($new)) {
    Write-Host "altiora.spec deja aligne"
}
elseif ($txt.Contains($old)) {
    $txt = $txt.Replace($old, $new)
    Set-Content -LiteralPath $spec -Value $txt -Encoding UTF8
    Write-Host "altiora.spec aligne vers AltioraBackupPro"
}
else {
    throw "Ancrage name='altiora' introuvable. Patch fail-closed."
}

Write-Host "PATCH OK"