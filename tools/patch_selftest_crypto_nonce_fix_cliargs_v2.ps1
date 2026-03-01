$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)"
}

$root   = (Get-Location).Path
$target = Join-Path $root "tools\selftest_crypto_nonce.ps1"
if(!(Test-Path $target)){ throw "selftest introuvable: $target" }

$raw = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($raw)){ throw "selftest vide ou illisible" }

function Replace-Once([string]$s, [string]$a, [string]$b, [string]$label){
  $i = $s.IndexOf($a)
  if($i -lt 0){ throw "Pattern introuvable: $label" }
  return $s.Substring(0,$i) + $b + $s.Substring($i + $a.Length)
}

# --- Inject outFile before args block (we locate the line containing '$args = @(' with 2 spaces prefix)
$markerArgsLine = "  `$args = @("
$posArgsLine = $raw.IndexOf($markerArgsLine)
if($posArgsLine -lt 0){ throw "Ligne args introuvable: $markerArgsLine" }

$insert = "  `$outFile = Join-Path `$OutDir (""selftest_"" + `$i.ToString(""0000"") + ""_"" + [Guid]::NewGuid().ToString(""N"") + "".altb"")`n"
if($raw.IndexOf("`$outFile = Join-Path") -ge 0){
  throw "outFile semble déjà présent (patch déjà appliqué ?)"
}

$raw = $raw.Substring(0,$posArgsLine) + $insert + $raw.Substring($posArgsLine)

# --- Replace args block (from '  $args = @(' up to the closing '  )' on its own line)
$start = $raw.IndexOf("  `$args = @(")
if($start -lt 0){ throw "Début bloc args introuvable après insertion" }
$end = $raw.IndexOf("  )`n", $start)
if($end -lt 0){ throw "Fin bloc args introuvable (ligne '  )')" }
$end = $end + ("  )`n").Length

$newArgs =
"  `$args = @(`n" +
"    `$AltioraPy,`n" +
"    ""backup"",`n" +
"    `$SourceDir,`n" +
"    `$outFile,`n" +
"    ""-p"", `$Password`n" +
"  )`n"

$raw = $raw.Substring(0,$start) + $newArgs + $raw.Substring($end)

# --- Replace latest block: the 3-line pipeline ending with Select-Object -Last 1
$oldLatest =
"  `$latest = Get-ChildItem -LiteralPath `$OutDir -File |`n" +
"            Sort-Object LastWriteTimeUtc |`n" +
"            Select-Object -Last 1`n"

$newLatest = "  `$latest = Get-Item -LiteralPath `$outFile`n"

$raw = Replace-Once $raw $oldLatest $newLatest "bloc latest Get-ChildItem"

Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: selftest mis à jour (args positionnels + outFile)"
