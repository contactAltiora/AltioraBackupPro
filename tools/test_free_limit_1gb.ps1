# ABP_ASCII_OUTPUT_V3
# ABP_ASCII_OUTPUT_V2
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-FREE-1GB: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST FREE LIMIT 1GB ==="

$pwd = $env:ABP_SELFTEST_PASSWORD
if([string]::IsNullOrWhiteSpace($pwd)){
  Fail "ABP_SELFTEST_PASSWORD requis (set env var pour tests)"
}

$tmp = Join-Path $env:TEMP ("abp_free_1gb_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$big = Join-Path $tmp "big_1p2gb.bin"

# sparse file >1GB (logical). If product checks logical size, it must fail in FREE.
& fsutil file createnew $big 1300000000 | Out-Null
Assert (Test-Path $big) "big file non cree"

$out = Join-Path $tmp "big.altb"

& python "$root\altiora.py" backup $big $out -p $pwd 2>$null
$ec = $LASTEXITCODE

if($ec -eq 0){
  Fail "limite FREE 1GB NON appliquee: backup >1GB a reussi (exitcode=0)."
}

Write-Host "OK OK TEST FREE LIMIT (echec attendu valide)"

