$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\selftest_crypto_nonce.ps1"
if(!(Test-Path $target)){ throw "selftest introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "selftest vide ou illisible" }

$raw = $raw0 -replace "`r`n", "`n"

$startNeedle = "function Extract-SaltNonce([string]$path){"
$pos = $raw.IndexOf($startNeedle)
if($pos -lt 0){ throw "Fonction Extract-SaltNonce introuvable" }

$endPos = $raw.IndexOf("`n}`n", $pos)
if($endPos -lt 0){ throw "Fin de fonction Extract-SaltNonce introuvable" }
$endPos = $endPos + ("`n}`n").Length

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
'  # Trouver fin JSON : première ''}'' après j0',
'  # Hypothèse ABP: header JSON plat (pas d''accolades imbriquées)',
'  $j1 = -1',
'  for($k=$j0; $k -lt $bytes.Length; $k++){',
'    if($bytes[$k] -eq $rb){ $j1 = $k; break }',
'  }',
'  if($j1 -lt 0){ Fail("Fin JSON } introuvable: $path") }',
'',
'  $headerBytes = $bytes[$j0..$j1]',
'  $headerText  = [System.Text.Encoding]::UTF8.GetString($headerBytes)',
'',
'  try { $null = $headerText | ConvertFrom-Json } catch {',
'    Fail("Header non-JSON ou JSON invalide en tête de fichier: $path")',
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

$before = $raw.Substring(0, $pos)
$after  = $raw.Substring($endPos)
$raw    = $before + $newExtract + $after

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: Extract-SaltNonce = parse JSON bounds (no LF)"
