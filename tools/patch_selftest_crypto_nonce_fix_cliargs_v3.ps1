$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)"
}

$root   = (Get-Location).Path
$target = Join-Path $root "tools\selftest_crypto_nonce.ps1"
if(!(Test-Path $target)){ throw "selftest introuvable: $target" }

$raw0 = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if([string]::IsNullOrWhiteSpace($raw0)){ throw "selftest vide ou illisible" }

# Normaliser les fins de ligne pour matcher de façon stable
$raw = $raw0 -replace "`r`n", "`n"

function Replace-Once([string]$s, [string]$a, [string]$b, [string]$label){
  $i = $s.IndexOf($a)
  if($i -lt 0){ throw "Pattern introuvable: $label" }
  return $s.Substring(0,$i) + $b + $s.Substring($i + $a.Length)
}

# 1) Injecter $outFile juste avant la ligne "  $args = @("
$needleArgsLine = "`n  `$args = @(`n"
if($raw.IndexOf("`n  `$outFile = Join-Path") -ge 0){
  throw "outFile semble déjà présent (patch déjà appliqué ?)"
}

$insert = "`n  `$outFile = Join-Path `$OutDir (""selftest_"" + `$i.ToString(""0000"") + ""_"" + [Guid]::NewGuid().ToString(""N"") + "".altb"")`n"
$raw = Replace-Once $raw $needleArgsLine ($insert + "  `$args = @(`n") "injection outFile avant args"

# 2) Remplacer le bloc args actuel (celui avec --source/--out/--password)
$oldArgs =
"  `$args = @(`n" +
"    `$AltioraPy,`n" +
"    ""backup"",`n" +
"    ""--source"", `$SourceDir,`n" +
"    ""--out"", `$OutDir,`n" +
"    ""--password"", `$Password`n" +
"  )`n"

$newArgs =
"  `$args = @(`n" +
"    `$AltioraPy,`n" +
"    ""backup"",`n" +
"    `$SourceDir,`n" +
"    `$outFile,`n" +
"    ""-p"", `$Password`n" +
"  )`n"

$raw = Replace-Once $raw $oldArgs $newArgs "remplacement bloc args (--source/--out/--password -> positionnels + -p)"

# 3) Remplacer le bloc latest actuel (dernier fichier du dossier) par Get-Item $outFile
$oldLatest =
"  `$latest = Get-ChildItem -LiteralPath `$OutDir -File |`n" +
"            Sort-Object LastWriteTimeUtc |`n" +
"            Select-Object -Last 1`n"

$newLatest = "  `$latest = Get-Item -LiteralPath `$outFile`n"

$raw = Replace-Once $raw $oldLatest $newLatest "remplacement bloc latest"

# Réécrire en UTF-8 (sans BOM)
Set-Content -LiteralPath $target -Value $raw -Encoding UTF8
Write-Host "[PATCH] OK: selftest corrigé (outFile + args positionnels + -p)"
