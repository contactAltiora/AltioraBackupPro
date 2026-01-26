$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$alt  = Join-Path $root "altiora.py"

if(-not (Test-Path $alt)) { throw "ERROR: missing file: $alt" }

function WriteUtf8NoBom([string]$path, [string]$text){
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

$txt = Get-Content -Path $alt -Raw -Encoding UTF8

# --- Replace backup call ---
$old1 = 'ok = core.backup(args.source, args.output, args.password, iterations=iterations, no_compress=no_compress)'
$new1 = 'ok = core.create_backup(args.source, args.output, args.password, iterations=iterations, compress=(not no_compress))'

if($txt.IndexOf($old1) -lt 0){
  throw "ERROR: cannot find expected backup dispatch line in altiora.py."
}
$txt = $txt.Replace($old1, $new1)

# --- Replace restore call ---
$old2 = 'ok = core.restore(args.backup, args.output, args.password)'
$new2 = 'ok = core.restore_backup(args.backup, args.output, args.password)'

if($txt.IndexOf($old2) -lt 0){
  throw "ERROR: cannot find expected restore dispatch line in altiora.py."
}
$txt = $txt.Replace($old2, $new2)

WriteUtf8NoBom $alt $txt
Write-Host "OK: altiora.py dispatch mapped to BackupCore (create_backup/restore_backup)."

py -m py_compile $alt
Write-Host "OK: py_compile altiora.py"
