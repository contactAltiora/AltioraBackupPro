$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\selftest_crypto_nonce.ps1"
if(!(Test-Path $target)){ throw "selftest introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "selftest vide ou illisible" }
$raw = $raw0 -replace "`r`n", "`n"

# --- locate Extract-SaltNonce function block (robust)
$marker = "function Extract-SaltNonce"
$posFn = $raw.IndexOf($marker)
if($posFn -lt 0){ throw "Marqueur introuvable: $marker" }

$posBraceOpen = $raw.IndexOf("{", $posFn)
if($posBraceOpen -lt 0){ throw "Accolade d'ouverture introuvable après $marker" }

$depth = 0
$posBraceClose = -1
for($i=$posBraceOpen; $i -lt $raw.Length; $i++){
  $ch = $raw[$i]
  if($ch -eq "{"){ $depth++ }
  elseif($ch -eq "}"){
    $depth--
    if($depth -eq 0){ $posBraceClose = $i; break }
  }
}
if($posBraceClose -lt 0){ throw "Accolade de fermeture correspondante introuvable pour $marker" }

$posAfter = $raw.IndexOf("`n", $posBraceClose)
if($posAfter -lt 0){ $posAfter = $posBraceClose + 1 } else { $posAfter = $posAfter + 1 }

$newExtractLines = @(
'function Extract-SaltNonce([string]$path){',
'  if(!(Test-Path $path)){ Fail("Fichier introuvable: $path") }',
'',
'  $bytes = [System.IO.File]::ReadAllBytes($path)',
'  if($bytes.Length -lt 1){ Fail("Fichier vide: $path") }',
'',
'  # Trouver début JSON : premier ''{''',
'  $lb = [byte][char]''{''',
'  $rb = [byte][char]''}''',
'  $j0 = [Array]::IndexOf($bytes, $lb)',
'  if($j0 -lt 0){ Fail("JSON start { introuvable: $path") }',
'',
'  # Trouver une fin JSON valide en testant des ''}'' candidates (borné)',
'  $maxScan = 8192',
'  $scanEnd = [Math]::Min($bytes.Length - 1, $j0 + $maxScan)',
'  $j1 = -1',
'  $headerText = $null',
'',
'  for($k=$j0; $k -le $scanEnd; $k++){',
'    if($bytes[$k] -ne $rb){ continue }',
'    $tryBytes = $bytes[$j0..$k]',
'    $tryText  = [System.Text.Encoding]::UTF8.GetString($tryBytes)',
'    try { $null = $tryText | ConvertFrom-Json; $j1 = $k; $headerText = $tryText; break } catch { }',
'  }',
'',
'  if($j1 -lt 0){',
'    # diagnostic court',
'    $diagLen = [Math]::Min(120, $bytes.Length - $j0)',
'    if($diagLen -gt 0){',
'      $diagText = [System.Text.Encoding]::UTF8.GetString($bytes[$j0..($j0+$diagLen-1)])',
'      Fail("Header JSON introuvable (aucune fin valide dans $maxScan bytes). Début extrait: $diagText")',
'    } else {',
'      Fail("Header JSON introuvable (aucune fin valide dans $maxScan bytes).")',
'    }',
'  }',
'',
'  $off  = $j1 + 1',
'  $need = 16 + 12',
'  if(($off + $need) -gt $bytes.Length){',
'    Fail("Taille insuffisante pour SALT(16)+NONCE(12) après JSON: $path")',
'  }',
'',
'  $salt  = $bytes[$off..($off+15)]',
'  $nonce = $bytes[($off+16)..($off+27)]',
'',
'  $saltHex  = ([BitConverter]::ToString($salt)).Replace("-","").ToLowerInvariant()',
'  $nonceHex = ([BitConverter]::ToString($nonce)).Replace("-","").ToLowerInvariant()',
'',
'  return @($saltHex, $nonceHex)',
'}',
''
)
$newExtract = ($newExtractLines -join "`n")

$before = $raw.Substring(0, $posFn)
$after  = $raw.Substring($posAfter)
$raw2   = $before + $newExtract + $after

Set-Content -LiteralPath $target -Value $raw2 -Encoding UTF8
Write-Host "[PATCH] OK: Extract-SaltNonce remplacé (find valid JSON end, bounded)"
