# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-CLI: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST CLI (altiora.py + exe) ==="

python -m py_compile "$root\altiora.py"

$v = @(python "$root\altiora.py" --version | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($v.Count -eq 1) "altiora.py --version doit produire 1 ligne, obtenu=$($v.Count)"
Assert ($v[0] -match "^Altiora Backup Pro v\d+\.\d+\.\d+$") "format version inattendu: $($v[0])"

$v2 = @(python "$root\altiora.py" -V | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($v2.Count -eq 1) "altiora.py -V doit produire 1 ligne, obtenu=$($v2.Count)"
Assert ($v2[0] -eq $v[0]) "-V != --version ($($v2[0]) vs $($v[0]))"

$h = (python "$root\altiora.py" --help) | Out-String
Assert ($h -match "--version") "help: --version absent"
Assert ($h -match "\-V") "help: -V absent"

$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"

$ev = @(& $exe --version | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($ev.Count -eq 1) "exe --version doit produire 1 ligne, obtenu=$($ev.Count)"
Assert ($ev[0] -eq $v[0]) "exe version != python version ($($ev[0]) vs $($v[0]))"

Write-Host "OK OK TEST CLI"

