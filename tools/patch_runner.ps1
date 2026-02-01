param(
  [Parameter(Mandatory=$true)]
  [string]$Script,

  [switch]$NoUsbRequired,

  [switch]$IUnderstandRisks,



  [switch]$UpdateBaselineLock,
  [string]$UsbRoot = "F:\"
)

$ErrorActionPreference = "Stop"

# --- Force UTF-8 (parent process) ---
try { chcp 65001 > $null } catch {}
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}


$root = (Get-Location).Path

# _out (logs, snapshots temporaires, baks)
$outDir = Join-Path $root "_out"
New-Item -ItemType Directory -Force $outDir | Out-Null

# Baseline lock: empeche toute derive des fichiers core hors process
$altioraLockPath = Join-Path $outDir "baseline_lock.json"

function Get-Sha256([string]$p){
  if (!(Test-Path -LiteralPath $p)) { return $null }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash
}

# Liste des fichiers a verrouiller (relatifs au root)
$lockRelPaths = @(
  "altiora.py",
  "src\backup_core.py",
  "src\master_key.py",
  "tools\patch_runner.ps1",
  "tools\patch_audit_baseline_v2.ps1"
)

# Construit le dictionnaire files{relPath: sha}
$files = [ordered]@{}
foreach ($rel in $lockRelPaths) {
  $abs = Join-Path $root $rel
  if (Test-Path -LiteralPath $abs) {
    $files[$rel] = (Get-Sha256 $abs)
  }
}

if ($files.Count -gt 0) {

  if (Test-Path -LiteralPath $altioraLockPath) {

    # Guard: baseline_lock.json doit etre lisible et coherent
    try {
      $lock = Get-Content -LiteralPath $altioraLockPath -Encoding UTF8 -Raw | ConvertFrom-Json
    } catch {
      throw "Baseline lock invalide/corrompu: $altioraLockPath. Regenere avec -UpdateBaselineLock."
    }

    if (-not $lock.root -or ($lock.root -ne $root)) {
      throw "Baseline lock incoherent: root mismatch. lock.root='$($lock.root)' current='$root'. Regenere avec -UpdateBaselineLock."
    }

    if (-not $lock.files) {
      throw "Baseline lock invalide: champ 'files' manquant. Regenere avec -UpdateBaselineLock."
    }

    if ($UpdateBaselineLock) {
      $newLock = [ordered]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
        root          = $root
        files         = $files
      }
      $newLock | ConvertTo-Json -Depth 8 | Out-File -FilePath $altioraLockPath -Encoding UTF8
      Write-Host "BASELINE LOCK: updated -> $altioraLockPath"
    } else {

      foreach ($k in $files.Keys) {
        $expected = $lock.files.PSObject.Properties | Where-Object { $_.Name -eq $k } | Select-Object -First 1 -ExpandProperty Value
        $cur = $files[$k]

        if ($null -eq $expected) {
          throw "CORE DRIFT DETECTED: '$k' absent du baseline lock. Refus patch. (Use -UpdateBaselineLock ONLY if intentional)"
        }
        if ($expected -ne $cur) {
          throw "CORE DRIFT DETECTED: '$k' SHA256 different du baseline lock. Refus patch. (Use -UpdateBaselineLock ONLY if intentional)"
        }
      }

    }

  } else {

    $initLock = [ordered]@{
      timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
      root          = $root
      files         = $files
    }
    $initLock | ConvertTo-Json -Depth 8 | Out-File -FilePath $altioraLockPath -Encoding UTF8
    Write-Host "BASELINE LOCK: created -> $altioraLockPath"

  }

}
