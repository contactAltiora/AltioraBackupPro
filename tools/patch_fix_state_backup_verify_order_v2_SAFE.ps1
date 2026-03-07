$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
    throw "ALTIORA_PATCH=1 requis"
}

$repo = (Get-Location).Path
$path = Join-Path $repo "tools\release_finalize_and_state.ps1"

if (!(Test-Path $path)) {
    throw "release_finalize_and_state.ps1 introuvable"
}

Write-Host "PATCH: fix STATE backup verify order v2"

$txt = Get-Content -LiteralPath $path -Encoding UTF8 -Raw

$old = @'
# copy STATE + signature to backup drives
foreach($d in $backupDirs){

    Copy-Item $statePath "$d\STATE.md" -Force
    Copy-Item $stateSig "$d\STATE.md.sig" -Force

    & py $verifyScript $publicKey "$d\STATE.md" | Out-Host

    if($LASTEXITCODE -ne 0){
        throw "STATE signature invalid on $d"
    }

    Write-Host "STATE backed up and verified on $d"
}
'@

$new = @'
# copy STATE + signature to backup drives
foreach($d in $backupDirs){

    $dstState = "$d\STATE.md"
    $dstSig   = "$d\STATE.md.sig"

    Copy-Item $statePath $dstState -Force
    Copy-Item $stateSig  $dstSig  -Force

    if(-not (Test-Path -LiteralPath $dstState)){
        throw "STATE.md missing on $d after copy"
    }

    if(-not (Test-Path -LiteralPath $dstSig)){
        throw "STATE.md.sig missing on $d after copy"
    }

    & py $verifyScript $publicKey $dstState | Out-Host

    if($LASTEXITCODE -ne 0){
        throw "STATE signature invalid on $d"
    }

    Write-Host "STATE backed up and verified on $d"
}
'@

if ($txt.Contains($new.Trim())) {
    Write-Host "Patch deja applique"
}
elseif ($txt.Contains($old)) {
    $txt = $txt.Replace($old, $new)
    Set-Content -LiteralPath $path -Value $txt -Encoding UTF8
    Write-Host "Bloc STATE backup/verify corrige"
}
else {
    throw "Bloc cible introuvable. Patch fail-closed."
}

Write-Host "PATCH OK"