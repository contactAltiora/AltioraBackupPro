# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-EXE-SMOKE: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST EXE SMOKE ==="

$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"

# exe --help doit marcher (exit 0)
& $exe --help | Out-Null
Assert ($LASTEXITCODE -eq 0) "exe --help exitcode=$LASTEXITCODE"

# exe --json --version doit etre JSON pur
$je = (& $exe --json --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($je.Count -eq 1) "exe json --version doit produire 1 ligne"
Assert ($je[0] -match '^\{') "exe json --version pas JSON"

Write-Host "OK OK TEST EXE SMOKE"

