$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$targets = @(
  (Join-Path $root "tools\release_build_and_backup.ps1"),
  (Join-Path $root "tools\release_finalize_and_state.ps1")
)

# Block to inject (no here-string, no expansion at creation time)
$blockLines = @(
  "# ================================",
  "# ABP_SAFEFS_FALLBACK_V3",
  "# Ensure Safe-GetChildItem exists in this runspace",
  "# ================================",
  "try {",
  "  `$safeFs = Join-Path `$PSScriptRoot ""safe_fs.ps1""",
  "  if(Test-Path -LiteralPath `$safeFs){ . `$safeFs }",
  "} catch { }",
  "",
  "if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){",
  "  function Safe-GetChildItem {",
  "    [CmdletBinding()]",
  "    param(",
  "      [Parameter(Mandatory=`$true)][string]`$LiteralPath,",
  "      [string]`$Filter,",
  "      [switch]`$Recurse,",
  "      [switch]`$File,",
  "      [switch]`$Directory",
  "    )",
  "    `$ea = `$ErrorActionPreference",
  "    `$ErrorActionPreference = ""Stop""",
  "    try {",
  "      if(!(Test-Path -LiteralPath `$LiteralPath)){ return @() }",
  "      `$args = @{ LiteralPath = `$LiteralPath; Force = `$true }",
  "      if(`$Filter){ `$args.Filter = `$Filter }",
  "      if(`$Recurse){ `$args.Recurse = `$true }",
  "      if(`$File){ `$args.File = `$true }",
  "      if(`$Directory){ `$args.Directory = `$true }",
  "      return @(Get-ChildItem @args)",
  "    } finally {",
  "      `$ErrorActionPreference = `$ea",
  "    }",
  "  }",
  "}",
  "",
  "if(-not (Get-Command Safe-GetChildItem -ErrorAction SilentlyContinue)){",
  "  throw ""FAIL-CLOSED: Safe-GetChildItem introuvable même après fallback.""",
  "}",
  ""
)

foreach($t in $targets){
  if(!(Test-Path -LiteralPath $t)){ throw "FAIL-CLOSED: script introuvable: $t" }

  $txt = Get-Content -LiteralPath $t -Encoding UTF8 -Raw
  if($txt -match "ABP_SAFEFS_FALLBACK_V3"){ Write-Host "Already patched (V3): $t"; continue }

  # Parse the target to locate ParamBlock (most reliable insertion point)
  $toks = $null; $errs = $null
  $ast  = [System.Management.Automation.Language.Parser]::ParseInput($txt, [ref]$toks, [ref]$errs)
  if($errs -and $errs.Count -gt 0){ throw ("FAIL-CLOSED: cible parse déjà en erreur: " + (Split-Path -Leaf $t) + ": " + $errs[0].Message) }

  $linesSrc = $txt -split "(\r?\n)"  # keep it simple; we will re-join ourselves
  # Rebuild as logical lines (remove the captured delimiters):
  $L = @()
  for($i=0; $i -lt $linesSrc.Count; $i+=2){ $L += $linesSrc[$i] }

  $insertAt = -1
  if($ast -and $ast.ParamBlock){
    # EndLineNumber is 1-based. We want to insert AFTER the param block end line.
    $insertAt = [Math]::Min($L.Count, $ast.ParamBlock.Extent.EndLineNumber)
  } else {
    # No ParamBlock: insert after initial comments/#requires/blank lines
    $insertAt = 0
    for($i=0; $i -lt $L.Count; $i++){
      $s = $L[$i].Trim()
      if($s -eq ""){ continue }
      if($s.StartsWith("#")){ continue }
      $insertAt = $i
      break
    }
  }
  if($insertAt -lt 0){ throw "FAIL-CLOSED: insertion point introuvable pour $t" }

  $out = @()
  if($insertAt -gt 0){ $out += $L[0..($insertAt-1)] }
  $out += ""
  $out += $blockLines
  if($insertAt -le ($L.Count-1)){ $out += $L[$insertAt..($L.Count-1)] }

  $txt2 = ($out -join "`r`n") + "`r`n"

  # Parse-check fail-closed after edit
  $toks2 = $null; $errs2 = $null
  $null = [System.Management.Automation.Language.Parser]::ParseInput($txt2, [ref]$toks2, [ref]$errs2)
  if($errs2 -and $errs2.Count -gt 0){ throw ("FAIL-CLOSED: parse check failed after patch for " + (Split-Path -Leaf $t) + ": " + $errs2[0].Message) }

  Set-Content -LiteralPath $t -Value $txt2 -Encoding UTF8
  Write-Host "OK: patched -> $t"
}

Write-Host "DONE: Safe-GetChildItem fallback injected (V3)."
