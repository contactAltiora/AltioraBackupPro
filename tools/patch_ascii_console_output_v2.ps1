# tools/patch_ascii_console_output_v2.ps1
# v2 - 100% ASCII. Remplace emojis/unicode ET leurs versions mojibake (cp1252).
$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw ("patch_ascii_console_output_v2: executer depuis " + $rootExpected + " (actuel: " + $root + ")")
}

function Fail($m){ throw ("patch_ascii_console_output_v2: " + $m) }

function MojibakeFromUtf8Bytes([byte[]]$b){
  # UTF-8 bytes mal lus en CP1252 -> chaine "âœ…" etc.
  return [System.Text.Encoding]::GetEncoding(1252).GetString($b)
}

function ReplaceBoth([string]$s, [byte[]]$utf8Bytes, [string]$replacement){
  $good = [System.Text.Encoding]::UTF8.GetString($utf8Bytes)
  $bad  = MojibakeFromUtf8Bytes $utf8Bytes
  $s = $s.Replace($good, $replacement)
  $s = $s.Replace($bad,  $replacement)
  return $s
}

# -----------------------------
# A) Patch src\backup_core.py
# -----------------------------
$bcPath = Join-Path $root "src\backup_core.py"
if(!(Test-Path $bcPath)){ Fail ("introuvable: " + $bcPath) }

$raw = Get-Content -LiteralPath $bcPath -Encoding UTF8 -Raw

if($raw -notmatch "ABP_ASCII_OUTPUT_V2"){
  $raw2 = $raw

  # Symboles / ponctuation
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x9B,0x94)) "!"     # U+26D4 NO ENTRY (souvent affiché comme "⛔")
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x9C,0x85)) "OK"    # U+2705 WHITE HEAVY CHECK MARK
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x9D,0x8C)) "ERROR" # U+274C CROSS MARK
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x9E,0x94)) "->"    # U+2794 HEAVY WIDE-HEADED RIGHTWARDS ARROW
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x86,0x92)) "->"    # U+2192 RIGHTWARDS ARROW
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x80,0x94)) "-"     # U+2014 EM DASH
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xE2,0x80,0x99)) "'"     # U+2019 RIGHT SINGLE QUOTATION MARK

  # Emoji "pointing finger" -> "->"
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xF0,0x9F,0x91,0x89)) "->" # U+1F449

  # Accents FR (remplacement ASCII)
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xA9)) "e"  # é
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xA8)) "e"  # è
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xAA)) "e"  # ê
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xAB)) "e"  # ë
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xA0)) "a"  # à
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xA2)) "a"  # â
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xAE)) "i"  # î
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xAF)) "i"  # ï
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xB4)) "o"  # ô
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xB6)) "o"  # ö
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xB9)) "u"  # ù
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xBB)) "u"  # û
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0xA7)) "c"  # ç
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0x89)) "E"  # É
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0x80)) "A"  # À
  $raw2 = ReplaceBoth $raw2 ([byte[]](0xC3,0x87)) "C"  # Ç

  # Marqueur idempotent
  $raw2 = "# ABP_ASCII_OUTPUT_V2`n" + $raw2

  if($raw2 -ne $raw){
    Set-Content -LiteralPath $bcPath -Value $raw2 -Encoding UTF8
    Write-Host "[PATCH] ASCII v2: src\backup_core.py patched (ASCII output)."
  } else {
    Write-Host "[PATCH] ASCII v2: no change needed in backup_core.py."
  }
} else {
  Write-Host "[PATCH] ASCII v2: backup_core.py already patched."
}

# --------------------------------
# B) Patch tools\test_*.ps1
# --------------------------------
$toolsDir = Join-Path $root "tools"
if(!(Test-Path $toolsDir)){ Fail ("introuvable: " + $toolsDir) }

$tests = @(Get-ChildItem -LiteralPath $toolsDir -Filter "test_*.ps1" -File -ErrorAction SilentlyContinue)
if(-not $tests -or $tests.Count -eq 0){
  Write-Host "[PATCH] ASCII v2: no tools\test_*.ps1 found (skip)."
} else {
  foreach($t in $tests){
    $traw = Get-Content -LiteralPath $t.FullName -Encoding UTF8 -Raw
    if($traw -match "ABP_ASCII_OUTPUT_V2"){ continue }

    $t2 = $traw
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x9C,0x85)) "OK"
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x9D,0x8C)) "ERROR"
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x9E,0x94)) "->"
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x86,0x92)) "->"
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x80,0x94)) "-"
    $t2 = ReplaceBoth $t2 ([byte[]](0xE2,0x80,0x99)) "'"
    $t2 = ReplaceBoth $t2 ([byte[]](0xF0,0x9F,0x91,0x89)) "->"

    # Accents frequents
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xA9)) "e"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xA8)) "e"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xAA)) "e"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xA0)) "a"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xA7)) "c"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xB4)) "o"
    $t2 = ReplaceBoth $t2 ([byte[]](0xC3,0xAE)) "i"

    if($t2 -ne $traw){
      $t2 = "# ABP_ASCII_OUTPUT_V2`n" + $t2
      Set-Content -LiteralPath $t.FullName -Value $t2 -Encoding UTF8
      Write-Host ("[PATCH] ASCII v2: patched " + $t.Name)
    }
  }
}

Write-Host "[PATCH] ASCII v2: OK"
