$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"

if(!(Test-Path $target)){
    throw "altiora.py introuvable"
}

$lines = Get-Content $target -Encoding UTF8

$out = New-Object System.Collections.Generic.List[string]

foreach($line in $lines){

    if($line -match '\)\s*verify_official_release\(\)'){
        $fixed = $line -replace 'verify_official_release\(\)',''
        $out.Add($fixed)
        $out.Add("")
        $out.Add("verify_official_release()")
    }
    else{
        $out.Add($line)
    }
}

$out | Set-Content $target -Encoding UTF8

Write-Host "verify_official_release call fixed"
