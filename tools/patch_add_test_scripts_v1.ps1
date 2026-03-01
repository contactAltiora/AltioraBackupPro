$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_add_test_scripts_v1: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_add_test_scripts_v1: $m" }

function Ensure-FileUtf8($path, $content){
  $dir = Split-Path -Parent $path
  if(!(Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -LiteralPath $path -Value $content -Encoding UTF8
}

# --- Common helpers embedded in each script (kept minimal) ---

$test1 = @'
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-CLI: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST CLI (altiora.py + exe) ==="

# Pre-check: syntax
python -m py_compile "$root\altiora.py"

# 1) altiora.py --version (must be ONLY version line)
$v = (python "$root\altiora.py" --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($v.Count -eq 1) "altiora.py --version doit produire 1 ligne, obtenu=$($v.Count)"
Assert ($v[0] -match "^Altiora Backup Pro v\d+\.\d+\.\d+$") "format version inattendu: $($v[0])"

# 2) -V idem
$v2 = (python "$root\altiora.py" -V) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($v2.Count -eq 1) "altiora.py -V doit produire 1 ligne, obtenu=$($v2.Count)"
Assert ($v2[0] -eq $v[0]) "-V != --version"

# 3) --help doit contenir --version et -V
$h = (python "$root\altiora.py" --help) | Out-String
Assert ($h -match "--version") "help: --version absent"
Assert ($h -match "\-V") "help: -V absent"

# 4) exe présent ?
$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"

# 5) exe --version output 1 line
$ev = (& $exe --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($ev.Count -eq 1) "exe --version doit produire 1 ligne, obtenu=$($ev.Count)"
Assert ($ev[0] -eq $v[0]) "exe version != python version ($($ev[0]) vs $($v[0]))"

Write-Host "✅ OK TEST CLI"
'@

$test2 = @'
$ErrorActionPreference="Stop"
$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

function Fail($m){ throw "TEST-JSON: $m" }
function Assert($cond,$m){ if(-not $cond){ Fail $m } }

Write-Host "=== TEST JSON MODE ==="

# JSON + version must be pure JSON, no banner
$j = (python "$root\altiora.py" --json --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($j.Count -eq 1) "json --version doit produire 1 ligne JSON, obtenu=$($j.Count)"
Assert ($j[0] -match '^\{') "json --version pas JSON: $($j[0])"
Assert ($j[0] -match '"ok"\s*:\s*true') "json ok:true absent"
Assert ($j[0] -match '"version"\s*:\s*"Altiora Backup Pro v\d+\.\d+\.\d+"') "json version absent/inattendu"

# JSON mode should not contain banner separators
Assert ($j[0] -notmatch "=====") "json contaminé par bannière"

# Same for EXE
$exe = "$root\dist\AltioraBackupPro.exe"
Assert (Test-Path $exe) "EXE absent: $exe"
$je = (& $exe --json --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($je.Count -eq 1) "exe json --version doit produire 1 ligne, obtenu=$($je.Count)"
Assert ($je[0] -match '^\{') "exe json --version pas JSON"
Assert ($je[0] -match '"ok"\s*:\s*true') "exe json ok:true absent"

Write-Host "✅ OK TEST JSON"
'@

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

# Create fixture file with unicode + multiline
$f = Join-Path $src "échantillon.txt"
Set-Content -LiteralPath $f -Value "Bonjour`nAltiora ✅`n" -Encoding UTF8

$backupPath = Join-Path $out ("t1_" + [guid]::NewGuid().ToString("N") + ".altb")

# backup
& python "$root\altiora.py" backup $src $backupPath -p $pwd | Out-Null
Assert (Test-Path $backupPath) "backup non créé: $backupPath"

# verify
& python "$root\altiora.py" verify $backupPath -p $pwd | Out-Null

# restore
& python "$root\altiora.py" restore $backupPath $rst -p $pwd --force | Out-Null

$restoredFile = Join-Path $rst "src\échantillon.txt"
Assert (Test-Path $restoredFile) "fichier restauré absent: $restoredFile"

$txt = Get-Content -LiteralPath $restoredFile -Encoding UTF8 -Raw
Assert ($txt -match "Altiora") "contenu restauré inattendu"

Write-Host "✅ OK TEST BACKUP/RESTORE/VERIFY"
'@

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

# On génère un fichier >1GB sans l'écrire réellement (FS sparse) : fsutil
$tmp = Join-Path $env:TEMP ("abp_free_1gb_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$big = Join-Path $tmp "big_1p2gb.bin"

# 1.2 GB = 1288490188 bytes (1.2*1024^3 approx). On met 1300000000 pour être >1GB.
& fsutil file createnew $big 1300000000 | Out-Null
Assert (Test-Path $big) "big file non créé"

$out = Join-Path $tmp "big.altb"

# On s'attend à un refus en mode FREE (message d'erreur non strict), mais exitcode != 0
$cmd = @("backup",$big,$out,"-p",$pwd)
& python "$root\altiora.py" @cmd 2>$null
$ec = $LASTEXITCODE
Assert ($ec -ne 0) "backup >1GB devrait échouer en FREE (exitcode=0)"

Write-Host "✅ OK TEST FREE LIMIT (échec attendu validé)"
'@

$test5 = @'
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

# exe --json --version doit être JSON pur
$je = (& $exe --json --version) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
Assert ($je.Count -eq 1) "exe json --version doit produire 1 ligne"
Assert ($je[0] -match '^\{') "exe json --version pas JSON"

Write-Host "✅ OK TEST EXE SMOKE"
'@

Ensure-FileUtf8 (Join-Path $root "tools\test_cli_version_help.ps1") $test1
Ensure-FileUtf8 (Join-Path $root "tools\test_json_mode.ps1")       $test2
Ensure-FileUtf8 (Join-Path $root "tools\test_backup_restore_verify.ps1") $test3
Ensure-FileUtf8 (Join-Path $root "tools\test_free_limit_1gb.ps1")  $test4
Ensure-FileUtf8 (Join-Path $root "tools\test_release_smoke_exe.ps1") $test5

Write-Host "[PATCH] OK: tools\test_*.ps1 créés"