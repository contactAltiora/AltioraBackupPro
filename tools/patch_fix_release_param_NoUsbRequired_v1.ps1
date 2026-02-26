$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path $target)){ throw "release_build_and_backup.ps1 introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "release_build_and_backup.ps1 vide ou illisible" }
$raw = $raw0 -replace "`r`n","`n"

$assignLine = '$__ABP_NO_USB_REQUIRED = $NoUsbRequired'

# --- Locate param( ... ) block
$m = [regex]::Match($raw, '\bparam\s*\(')
if(-not $m.Success){ throw "param( introuvable: je ne peux pas réparer automatiquement" }

$start = $m.Index
$open  = $raw.IndexOf("(", $start)
if($open -lt 0){ throw "Accolade '(' introuvable après param" }

# Find matching ')'
$depth = 0
$close = -1
for($i=$open; $i -lt $raw.Length; $i++){
  $ch = $raw[$i]
  if($ch -eq "("){ $depth++ }
  elseif($ch -eq ")"){
    $depth--
    if($depth -eq 0){ $close = $i; break }
  }
}
if($close -lt 0){ throw "Fin du bloc param(...) introuvable" }

$paramBlock = $raw.Substring($start, ($close - $start + 1))

# --- Remove any assignment line INSIDE param block (this is the bug)
$paramFixed = $paramBlock -replace "(?m)^\Q$assignLine\E\s*\n?", ""

# Ensure NoUsbRequired is present as a parameter
if($paramFixed -notmatch '\$NoUsbRequired\b'){
  # Insert right after "param("
  $paramFixed = [regex]::Replace(
    $paramFixed,
    '\bparam\s*\(',
    'param([switch]$NoUsbRequired, ',
    1
  )
}

# Replace param block in raw
$raw = $raw.Substring(0,$start) + $paramFixed + $raw.Substring($close+1)

# --- Ensure assignment exists AFTER param block (idempotent)
if($raw -notmatch [regex]::Escape($assignLine)){
  # Find end of param block again, then insert after line end
  $m2 = [regex]::Match($raw, '\bparam\s*\(')
  if(-not $m2.Success){ throw "param( introuvable après modification (inattendu)" }

  $start2 = $m2.Index
  $open2  = $raw.IndexOf("(", $start2)

  $depth2 = 0
  $close2 = -1
  for($i=$open2; $i -lt $raw.Length; $i++){
    $ch = $raw[$i]
    if($ch -eq "("){ $depth2++ }
    elseif($ch -eq ")"){
      $depth2--
      if($depth2 -eq 0){ $close2 = $i; break }
    }
  }
  if($close2 -lt 0){ throw "Fin param(...) introuvable après modification (inattendu)" }

  $afterParenEol = $raw.IndexOf("`n", $close2)
  if($afterParenEol -lt 0){ $afterParenEol = $close2 + 1 } else { $afterParenEol = $afterParenEol + 1 }

  $raw = $raw.Substring(0,$afterParenEol) + $assignLine + "`n" + $raw.Substring($afterParenEol)
}

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: param() réparé + NoUsbRequired OK + assign déplacé hors param()"
