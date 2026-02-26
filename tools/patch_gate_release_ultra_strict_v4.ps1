$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

$begin = "# BEGIN ABP_GATE_SELFTEST_NONCE"
$end   = "# END ABP_GATE_SELFTEST_NONCE"

$posBegin = $raw.IndexOf($begin)
$posEnd   = $raw.IndexOf($end)
if($posBegin -lt 0 -or $posEnd -lt 0 -or $posEnd -le $posBegin){
  throw "Bloc gate BEGIN/END introuvable ou invalide"
}

$afterEnd = $raw.IndexOf("`n", $posEnd)
if($afterEnd -lt 0){ $afterEnd = $posEnd + $end.Length } else { $afterEnd = $afterEnd + 1 }

$newBlockLines = @(
  "# BEGIN ABP_GATE_SELFTEST_NONCE",
  "# ------------------------------------------------------------",
  "# ULTRA STRICT GATE : selftest crypto nonce (fixture versionnée)",
  "# Config via env: ABP_SELFTEST_PASSWORD (required), ABP_SELFTEST_N (default 10)",
  "# ------------------------------------------------------------",
  "",
  '$fixture = Join-Path (Get-Location).Path "_fixtures\selftest_src"',
  'if(!(Test-Path $fixture)){ throw "Fixture selftest introuvable: $fixture" }',
  'if(-not (Get-ChildItem $fixture -File)){ throw "Fixture vide: $fixture" }',
  "",
  '$st = Join-Path $PSScriptRoot "selftest_crypto_nonce.ps1"',
  'if(!(Test-Path $st)){ throw "Selftest introuvable: $st" }',
  "",
  '$pwd = $env:ABP_SELFTEST_PASSWORD',
  'if([string]::IsNullOrWhiteSpace($pwd)){ throw "ABP_SELFTEST_PASSWORD requis pour lancer la release" }',
  "",
  '$n = 10',
  'if(-not [string]::IsNullOrWhiteSpace($env:ABP_SELFTEST_N)){',
  '  $tmp = 0',
  '  if(-not [int]::TryParse($env:ABP_SELFTEST_N, [ref]$tmp)){ throw "ABP_SELFTEST_N invalide (int attendu): $env:ABP_SELFTEST_N" }',
  '  if($tmp -lt 1 -or $tmp -gt 200){ throw "ABP_SELFTEST_N hors bornes (1..200): $tmp" }',
  '  $n = $tmp',
  '}',
  "",
  'Write-Host ("RUN SELFTEST (ULTRA STRICT) N={0}" -f $n)',
  '$ps = (Get-Command powershell).Source',
  '$args = @(',
  '  "-NoProfile","-ExecutionPolicy","Bypass",',
  '  "-File",$st,',
  '  "-N",$n.ToString(),',
  '  "-Password",$pwd,',
  '  "-SourceDir",$fixture,',
  '  "-AltioraPy",(Join-Path (Get-Location).Path "altiora.py")',
  ')',
  "",
  '$p = Start-Process -FilePath $ps -ArgumentList $args -NoNewWindow -Wait -PassThru',
  'if($p.ExitCode -ne 0){ throw ("Selftest crypto nonce FAILED (exit={0}) => RELEASE ABORTED" -f $p.ExitCode) }',
  'Write-Host "SELFTEST OK"',
  "# END ABP_GATE_SELFTEST_NONCE",
  ""
)

$newBlock = ($newBlockLines -join "`n")
$raw2 = $raw.Substring(0, $posBegin) + $newBlock + $raw.Substring($afterEnd)

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: Gate Ultra Strict remplacé (v4 env-based)"
