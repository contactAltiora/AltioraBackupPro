$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"

$snapDir = Join-Path $root "_out\snapshots_weekly"
if(!(Test-Path -LiteralPath $snapDir)){ throw "snapshots_weekly introuvable: $snapDir" }

$zip = Get-ChildItem -LiteralPath $snapDir -Filter "AltioraBackupPro_WEEKLY_*.zip" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if(!$zip){ throw "Aucun snapshot weekly .zip trouvé dans: $snapDir" }

# Find altiora.py inside zip
Add-Type -AssemblyName System.IO.Compression.FileSystem

$foundEntry = $null
$z = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
try{
  foreach($e in $z.Entries){
    if($e.FullName -match '(^|/|\\)altiora\.py$'){
      $foundEntry = $e
      break
    }
  }
} finally {
  $z.Dispose()
}

if(!$foundEntry){
  throw "altiora.py introuvable dans le snapshot: $($zip.Name)"
}

$tmpDir = Join-Path $snapDir "_extract_altiora_tmp"
if(Test-Path $tmpDir){ Remove-Item $tmpDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

# Extract only the matched entry
$z = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
try{
  $destPath = Join-Path $tmpDir "altiora.py"
  $inStream  = $foundEntry.Open()
  $outStream = [System.IO.File]::Open($destPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
  try{
    $inStream.CopyTo($outStream)
  } finally {
    $inStream.Dispose()
    $outStream.Dispose()
  }

  Copy-Item -LiteralPath $destPath -Destination $target -Force

} finally {
  $z.Dispose()
}

Remove-Item $tmpDir -Recurse -Force

Write-Host "altiora.py restored from snapshot:"
Write-Host $zip.FullName
