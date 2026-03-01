$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n", "`n"

# --- Define gate block (unique markers for idempotence)
$begin = "# BEGIN ABP_GATE_SELFTEST_NONCE"
$end   = "# END ABP_GATE_SELFTEST_NONCE"

$gateLines = @(
$begin,
"# ------------------------------------------------------------",
"# Gate release: selftest crypto nonce uniqueness (deterministic)",
"# Abort release if exit code != 0",
"# ------------------------------------------------------------",
'$st = Join-Path $PSScriptRoot "selftest_crypto_nonce.ps1"',
'if(!(Test-Path $st)){ throw "Selftest introuvable: $st" }',
'',
'Write-Host "RUN SELFTEST: crypto nonce uniqueness"',
'$ps = (Get-Command powershell).Source',
'$stArgs = @(',
'  "-NoProfile","-ExecutionPolicy","Bypass",',
'  "-File",$st,',
'  "-N","10",',  # gate release: fast but meaningful
'  "-Password","testpwd",',
'  "-SourceDir","C:\Temp\abp_src",',
'  "-AltioraPy",(Join-Path (Get-Location).Path "altiora.py")',
')',
'$p = Start-Process -FilePath $ps -ArgumentList $stArgs -NoNewWindow -Wait -PassThru',
'if($p.ExitCode -ne 0){',
'  throw "Selftest crypto nonce a échoué (exit=$($p.ExitCode)) => release aborted"',
'}',
'Write-Host "SELFTEST OK"',
$end,
""
)
$gate = ($gateLines -join "`n")

# --- Remove existing block if present (bounded, deterministic)
$idxBegin = $raw.IndexOf($begin)
if($idxBegin -ge 0){
  $idxEnd = $raw.IndexOf($end, $idxBegin)
  if($idxEnd -lt 0){ throw "Gate begin trouvé mais end manquant: $end" }
  $idxEnd2 = $raw.IndexOf("`n", $idxEnd)
  if($idxEnd2 -lt 0){ $idxEnd2 = $idxEnd + $end.Length } else { $idxEnd2 = $idxEnd2 + 1 }
  $raw = $raw.Substring(0, $idxBegin) + $raw.Substring($idxEnd2)
}

# --- Insert gate near the top: after first Set-Location if present, else after $ErrorActionPreference
$insertAt = 0
$posSL = $raw.IndexOf("Set-Location")
if($posSL -ge 0){
  $lineEnd = $raw.IndexOf("`n", $posSL)
  if($lineEnd -ge 0){ $insertAt = $lineEnd + 1 }
} else {
  $posEAP = $raw.IndexOf('$ErrorActionPreference')
  if($posEAP -ge 0){
    $lineEnd = $raw.IndexOf("`n", $posEAP)
    if($lineEnd -ge 0){ $insertAt = $lineEnd + 1 }
  }
}

$raw2 = $raw.Substring(0, $insertAt) + $gate + $raw.Substring($insertAt)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: gate selftest nonce ajouté à release_build_and_backup.ps1"
