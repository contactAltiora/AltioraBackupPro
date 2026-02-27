$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root=(Get-Location).Path
$altiora=Join-Path $root "altiora.py"
$cli=Join-Path $root "src\backup_cli.py"

if(!(Test-Path $altiora)){ throw "altiora.py introuvable" }
if(!(Test-Path $cli)){ throw "src\backup_cli.py introuvable" }

# Ensure __version__ line exists and is clean + newline after it
$t = Get-Content -LiteralPath $altiora -Raw -Encoding UTF8
if($t -notmatch '__version__\s*=\s*"\d+\.\d+\.\d+"'){ throw "__version__ introuvable dans altiora.py" }

$t = $t -replace '__version__\s*=\s*"\d+\.\d+\.\d+"', '__version__ = "1.0.16"'
$t = $t -replace 'Altiora Backup Pro v\d+\.\d+\.\d+', 'Altiora Backup Pro v1.0.16'
Set-Content -LiteralPath $altiora -Value $t -Encoding UTF8
Write-Host "PATCH OK: altiora.py -> v1.0.16"

$u = Get-Content -LiteralPath $cli -Raw -Encoding UTF8
$u = $u -replace 'Altiora Backup Pro v\d+\.\d+\.\d+', 'Altiora Backup Pro v1.0.16'
Set-Content -LiteralPath $cli -Value $u -Encoding UTF8
Write-Host "PATCH OK: src\backup_cli.py -> v1.0.16"

Write-Host "PATCH OK: version alignment v1.0.16 complete"
