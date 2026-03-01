$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_fix_test_scripts_v2: exécuter depuis $rootExpected (actuel: $root)"
}

function Ensure-FileUtf8($path, $content){
  $dir = Split-Path -Parent $path
  if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}

# --- test_cli_version_help.ps1 (fix string indexing) ---
$test1 = @'
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

Write-Host "✅ OK TEST CLI"
'@

# --- test_json_mode.ps1 (fix string indexing) ---
$test2 = @'
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
Assert ($j[0] -notmatch "=====") "json contaminé par bannière"

$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"

$je = @(& $exe --json --version | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
Assert ($je.Count -eq 1) "exe json --version doit produire 1 ligne, obtenu=$($je.Count)"
Assert ($je[0] -match '^\{') "exe json --version pas JSON: $($je[0])"
Assert ($je[0] -match '"ok"\s*:\s*true') "exe json ok:true absent: $($je[0])"

Write-Host "✅ OK TEST JSON"
'@

# --- test_backup_restore_verify.ps1 (do not hardcode unicode filename) ---
$test3 = @'
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
$f = Join-Path $src "échantillon.txt"
Set-Content -LiteralPath $f -Value "Bonjour`nAltiora ✅`n" -Encoding UTF8

$backupPath = Join-Path $out ("t1_" + [guid]::NewGuid().ToString("N") + ".altb")

& python "$root\altiora.py" backup $src $backupPath -p $pwd | Out-Null
Assert (Test-Path $backupPath) "backup non créé: $backupPath"

& python "$root\altiora.py" verify $backupPath -p $pwd | Out-Null
& python "$root\altiora.py" restore $backupPath $rst -p $pwd --force | Out-Null

# Find restored txt (do not assume exact unicode filename)
$txtFile = Get-ChildItem -LiteralPath $rst -Recurse -File -Filter "*.txt" -ErrorAction SilentlyContinue | Select-Object -First 1
Assert ($null -ne $txtFile) "aucun fichier .txt restauré trouvé sous: $rst"

$txt = Get-Content -LiteralPath $txtFile.FullName -Encoding UTF8 -Raw
Assert ($txt -match "Altiora") "contenu restauré inattendu dans $($txtFile.FullName)"

Write-Host "✅ OK TEST BACKUP/RESTORE/VERIFY"
'@

# --- test_free_limit_1gb.ps1 (keep failing, but clearer) ---
$test4 = @'
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
Assert (Test-Path $big) "big file non créé"

$out = Join-Path $tmp "big.altb"

& python "$root\altiora.py" backup $big $out -p $pwd 2>$null
$ec = $LASTEXITCODE

if($ec -eq 0){
  Fail "limite FREE 1GB NON appliquée: backup >1GB a réussi (exitcode=0)."
}

Write-Host "✅ OK TEST FREE LIMIT (échec attendu validé)"
'@

Ensure-FileUtf8 (Join-Path $root "tools\test_cli_version_help.ps1") $test1
Ensure-FileUtf8 (Join-Path $root "tools\test_json_mode.ps1")       $test2
Ensure-FileUtf8 (Join-Path $root "tools\test_backup_restore_verify.ps1") $test3
Ensure-FileUtf8 (Join-Path $root "tools\test_free_limit_1gb.ps1")  $test4

Write-Host "[PATCH] OK: tests v2 appliqués (CLI/JSON/RESTORE/FREE)"