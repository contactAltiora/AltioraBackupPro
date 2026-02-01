# tools\patch_audit_baseline_v1.ps1
# Patch SAFE: audit baseline (ne modifie rien)
# Exécution UNIQUEMENT via runner (ALTIORA_PATCH=1)

$ErrorActionPreference = "Stop"

if ($env:ALTIORA_PATCH -ne "1") {
  throw "Refus: ce script doit être exécuté via 'altiora patch --script ...' (ALTIORA_PATCH=1 requis)."
}

$root = (Get-Location).Path
$altiora = Join-Path $root "altiora.py"
$outDir  = Join-Path $root "_out"

if (!(Test-Path $altiora)) { throw "altiora.py introuvable dans: $root" }
New-Item -ItemType Directory -Force $outDir | Out-Null

$ts = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath  = Join-Path $outDir ("audit_baseline_{0}.log" -f $ts)
$jsonPath = Join-Path $outDir ("audit_baseline_{0}.json" -f $ts)

function Run-Cmd([string]$label, [ScriptBlock]$sb) {
  $start = Get-Date
  try {
    $output = & $sb 2>&1 | Out-String
    return [pscustomobject]@{
      label    = $label
      ok       = $true
      started  = $start.ToString("o")
      ended    = (Get-Date).ToString("o")
      output   = $output.TrimEnd()
    }
  } catch {
    $output = ($_ | Out-String).TrimEnd()
    return [pscustomobject]@{
      label    = $label
      ok       = $false
      started  = $start.ToString("o")
      ended    = (Get-Date).ToString("o")
      output   = $output
    }
  }
}

$items = New-Object System.Collections.Generic.List[object]

$hash  = (Get-FileHash -Algorithm SHA256 $altiora).Hash
$attrs = (Get-Item $altiora).Attributes.ToString()

$baseline = [ordered]@{
  timestamp_utc  = (Get-Date).ToUniversalTime().ToString("o")
  root           = $root
  altiora_py     = $altiora
  altiora_sha256 = $hash
  altiora_attrs  = $attrs
  python         = $null
  tests          = @()
}

$items.Add((Run-Cmd "python_version" { py --version }))
$items.Add((Run-Cmd "py_compile_altiora" { py -m py_compile $altiora }))
$items.Add((Run-Cmd "altiora_help" { py $altiora --help }))
$items.Add((Run-Cmd "altiora_patch_help" { py $altiora patch --help }))
$items.Add((Run-Cmd "altiora_about" { py $altiora about }))

$allOk = $true
foreach ($it in $items) { if (-not $it.ok) { $allOk = $false } }

$baseline.python = ($items | Where-Object {$_.label -eq "python_version"} | Select-Object -First 1).output
$baseline.tests  = $items

"=== ALTIORA BASELINE AUDIT ($ts) ===" | Out-File -FilePath $logPath -Encoding UTF8
("Root: {0}" -f $baseline.root) | Out-File -FilePath $logPath -Append -Encoding UTF8
("altiora.py: {0}" -f $baseline.altiora_py) | Out-File -FilePath $logPath -Append -Encoding UTF8
("SHA256: {0}" -f $baseline.altiora_sha256) | Out-File -FilePath $logPath -Append -Encoding UTF8
("Attributes: {0}" -f $baseline.altiora_attrs) | Out-File -FilePath $logPath -Append -Encoding UTF8
"" | Out-File -FilePath $logPath -Append -Encoding UTF8

foreach ($t in $baseline.tests) {
  ("--- {0} | OK={1}" -f $t.label, $t.ok) | Out-File -FilePath $logPath -Append -Encoding UTF8
  $t.output | Out-File -FilePath $logPath -Append -Encoding UTF8
  "" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

$baseline | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding UTF8

if (-not $allOk) {
  throw "Audit baseline: au moins un test a échoué. Voir: $logPath"
}

Write-Host "[OK] Audit baseline OK"
Write-Host "   Log : $logPath"
Write-Host "   JSON: $jsonPath"


