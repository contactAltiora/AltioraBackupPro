$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw = (Get-Content -LiteralPath $target -Encoding UTF8 -Raw) -replace "`r`n","`n"

$begin = "# BEGIN ABP_GATE_SELFTEST_NONCE"
$end   = "# END ABP_GATE_SELFTEST_NONCE"

# Supprimer bloc existant si présent
$posBegin = $raw.IndexOf($begin)
$posEnd   = $raw.IndexOf($end)

if($posBegin -ge 0 -and $posEnd -gt $posBegin){
    $lineEnd = $raw.IndexOf("`n",$posEnd)
    if($lineEnd -lt 0){ $lineEnd = $posEnd + $end.Length } else { $lineEnd++ }
    $raw = $raw.Substring(0,$posBegin) + $raw.Substring($lineEnd)
}

$newBlock = @"
$begin
# ------------------------------------------------------------
# ULTRA STRICT GATE : selftest crypto nonce (fixture versionnée)
# ------------------------------------------------------------

`$fixture = Join-Path (Get-Location).Path "_fixtures\selftest_src"
if(!(Test-Path `$fixture)){
    throw "Fixture selftest introuvable: `$fixture"
}

if(-not (Get-ChildItem `$fixture -File)){
    throw "Fixture vide: `$fixture"
}

`$st = Join-Path `$PSScriptRoot "selftest_crypto_nonce.ps1"
if(!(Test-Path `$st)){
    throw "Selftest introuvable: `$st"
}

Write-Host "RUN SELFTEST (ULTRA STRICT)"

`$ps = (Get-Command powershell).Source
`$args = @(
    "-NoProfile","-ExecutionPolicy","Bypass",
    "-File", `$st,
    "-N","10",
    "-Password","testpwd",
    "-SourceDir", `$fixture,
    "-AltioraPy",(Join-Path (Get-Location).Path "altiora.py")
)

`$p = Start-Process -FilePath `$ps -ArgumentList `$args -NoNewWindow -Wait -PassThru

if(`$p.ExitCode -ne 0){
    throw "Selftest crypto nonce FAILED (exit=$(`$p.ExitCode)) => RELEASE ABORTED"
}

Write-Host "SELFTEST OK"
$end

"@

# insérer après Set-Location si trouvé
$insertPos = 0
$posSL = $raw.IndexOf("Set-Location")
if($posSL -ge 0){
    $insertPos = $raw.IndexOf("`n",$posSL) + 1
}

$raw2 = $raw.Substring(0,$insertPos) + $newBlock + $raw.Substring($insertPos)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8

Write-Host "[PATCH] OK: Gate Ultra Strict installé"
