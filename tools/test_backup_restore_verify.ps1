# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-BACKUP: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST BACKUP/RESTORE/VERIFY (python) ==="

$pwd = $env:ABP_SELFTEST_PASSWORD
if([string]::IsNullOrWhiteSpace($pwd)){
  Fail "ABP_SELFTEST_PASSWORD requis (set env var pour tests)"
}

$tmp = Join-Path $env:TEMP ("abp_test_" + [guid]::NewGuid().ToString("N"))
$src = Join-Path $tmp "src"
$out = Join-Path $tmp "out"
$rst = Join-Path $tmp "restored"
New-Item -ItemType Directory -Force -Path $src,$out,$rst | Out-Null

# Fixture file with unicode name + unicode content
$f = Join-Path $src "echantillon.txt"
Set-Content -LiteralPath $f -Value "Bonjour`nAltiora OK`n" -Encoding UTF8

$backupPath = Join-Path $out ("t1_" + [guid]::NewGuid().ToString("N") + ".altb")

& python "$root\altiora.py" backup $src $backupPath -p $pwd | Out-Null
Assert (Test-Path $backupPath) "backup non cree: $backupPath"

& python "$root\altiora.py" verify $backupPath -p $pwd | Out-Null
& python "$root\altiora.py" restore $backupPath $rst -p $pwd --force | Out-Null

# Find restored txt (do not assume exact unicode filename)
$txtFile = Get-ChildItem -LiteralPath $rst -Recurse -File -Filter "*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
Assert ($null -ne $txtFile) "aucun fichier .txt restaure trouve sous: $rst"

$txt = Get-Content -LiteralPath $txtFile.FullName -Encoding UTF8 -Raw
Assert ($txt -match "Altiora") "contenu restaure inattendu dans $($txtFile.FullName)"

Write-Host "OK OK TEST BACKUP/RESTORE/VERIFY"

