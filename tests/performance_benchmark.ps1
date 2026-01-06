$ErrorActionPreference = "Stop"

Write-Host "=== Performance benchmark (backup/verify/restore) ==="

# Repo root
$repoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Repo root introuvable" }
Set-Location $repoRoot
Write-Host "Repo root: $(Get-Location)"

# Python venv si dispo
$PY = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $PY)) { $PY = "python" }

if (-not (Test-Path ".\altiora.py")) { throw "altiora.py introuvable" }

# Workspace
$work = Join-Path $env:TEMP ("altiora_perf_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

$outdir = Join-Path $work "out"
New-Item -ItemType Directory -Path $outdir | Out-Null

$pwd = "Tr3sF0rt!P@ssw0rd#2025"

# Tailles (bytes)
$sizes = @(
  @{ Name="1MB";   Bytes=1MB },
  @{ Name="50MB";  Bytes=50MB },
  @{ Name="200MB"; Bytes=200MB }
)

$csv = Join-Path $repoRoot ".\artifacts\audit\perf_benchmark.csv"
"case,size_bytes,backup_s,verify_s,restore_s,backup_file_bytes" | Set-Content -Encoding UTF8 $csv

function Measure-Cmd([scriptblock]$cmd) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  & $cmd
  $sw.Stop()
  return [Math]::Round($sw.Elapsed.TotalSeconds, 3)
}

foreach ($s in $sizes) {
  $plain = Join-Path $work ("file_" + $s.Name + ".bin")
  $bk    = Join-Path $work ("backup_" + $s.Name + ".altb")
  $restoreOut = Join-Path $outdir ("restore_" + $s.Name)
  New-Item -ItemType Directory -Force -Path $restoreOut | Out-Null

  Write-Host "`n--- CASE: $($s.Name) ($($s.Bytes) bytes) ---"

  # Génère un fichier binaire pseudo-aléatoire (rapide + reproductible)
  $rng = New-Object System.Random 123
  $buffer = New-Object byte[] 1048576
  $fs = [System.IO.File]::Open($plain, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
  try {
    $remaining = [int64]$s.Bytes
    while ($remaining -gt 0) {
      $rng.NextBytes($buffer)
      $toWrite = [int]([Math]::Min($buffer.Length, $remaining))
      $fs.Write($buffer, 0, $toWrite)
      $remaining -= $toWrite
    }
  } finally { $fs.Close() }

  $tBackup = Measure-Cmd { & $PY .\altiora.py backup  $plain $bk -p $pwd | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "backup échoué ($($s.Name))" }

  $tVerify = Measure-Cmd { & $PY .\altiora.py verify  $bk -p $pwd | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "verify échoué ($($s.Name))" }

  $tRestore = Measure-Cmd { & $PY .\altiora.py restore $bk $restoreOut -p $pwd --force | Out-Null }
  if ($LASTEXITCODE -ne 0) { throw "restore échoué ($($s.Name))" }

  $restored = Join-Path $restoreOut ([System.IO.Path]::GetFileName($plain))
  if (-not (Test-Path $restored)) { throw "restored manquant ($($s.Name))" }

  # Check taille identique
  $a = (Get-Item $plain).Length
  $b = (Get-Item $restored).Length
  if ($a -ne $b) { throw "taille restaurée différente: $a vs $b ($($s.Name))" }

  $bkSize = (Get-Item $bk).Length

  "$($s.Name),$($s.Bytes),$tBackup,$tVerify,$tRestore,$bkSize" | Add-Content -Encoding UTF8 $csv

  Write-Host "✅ OK $($s.Name) | backup=$tBackup s | verify=$tVerify s | restore=$tRestore s | altb=$bkSize bytes"
}

Write-Host "`n✅ PERF BENCH DONE → $csv"
