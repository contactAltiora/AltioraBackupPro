# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-JSON: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST JSON MODE ==="

$j = @(python "$root\altiora.py" --json --version | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($j.Count -eq 1) "json --version doit produire 1 ligne JSON, obtenu=$($j.Count)"
Assert ($j[0] -match '^\{') "json --version pas JSON: $($j[0])"
Assert ($j[0] -match '"ok"\s*:\s*true') "json ok:true absent: $($j[0])"
Assert ($j[0] -match '"version"\s*:\s*"Altiora Backup Pro v\d+\.\d+\.\d+"') "json version absent/inattendu: $($j[0])"
Assert ($j[0] -notmatch "=====") "json contamine par banniere"

$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"

$je = @(& $exe --json --version | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($je.Count -eq 1) "exe json --version doit produire 1 ligne, obtenu=$($je.Count)"
Assert ($je[0] -match '^\{') "exe json --version pas JSON: $($je[0])"
Assert ($je[0] -match '"ok"\s*:\s*true') "exe json ok:true absent: $($je[0])"

Write-Host "OK OK TEST JSON"

