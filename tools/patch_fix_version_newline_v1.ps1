$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$target = Join-Path (Get-Location).Path "altiora.py"
$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8

# fix missing newline after __version__
$text2 = $text -replace '__version__ = "1\.0\.14"\s*ABP_JSON_MODE_EARLY',
                    "__version__ = `"1.0.14`"`r`nABP_JSON_MODE_EARLY"

if($text2 -eq $text){
    throw "Pattern newline fix not applied (abort)"
}

Set-Content -LiteralPath $target -Value $text2 -Encoding UTF8
Write-Host "PATCH OK: newline after __version__ fixed"
