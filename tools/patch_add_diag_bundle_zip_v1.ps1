$ErrorActionPreference="Stop"
. "$PSScriptRoot\safe_fs.ps1"


if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_add_diag_bundle_zip_v1: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_add_diag_bundle_zip_v1: $m" }

$diagPath = Join-Path $root "tools\diag_bundle_zip.ps1"

$diag = @'
$ErrorActionPreference="Stop"

$root = "C:\Dev\AltioraBackupPro"
Set-Location $root

Write-Host "============================================================"
Write-Host "DIAG BUNDLE ZIP"
Write-Host "Root: $root"
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"
Write-Host "============================================================"

$outDir = Join-Path $root "_out"
Write-Host "[DIAG] _out: $outDir exists=$(Test-Path $outDir)"
if(Test-Path $outDir){
Safe-GetChildItem -LiteralPath $outDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
}

$staging = Join-Path $outDir "bundle_BACKUP_PRO_ALTIORA"
Write-Host "[DIAG] staging: $staging exists=$(Test-Path $staging)"
if(Test-Path $staging){
Safe-GetChildItem -LiteralPath $staging -Recurse -OnError SilentlyContinue |
    Select-Object -First 40 FullName,Length |
    Format-Table -AutoSize | Out-String | Write-Host
}

Write-Host "[DIAG] Test Add-Type System.IO.Compression.FileSystem..."
try{
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
  Write-Host "[DIAG] Add-Type OK"
}catch{
  Write-Host "[DIAG] Add-Type FAILED: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
}

Write-Host "[DIAG] Test zip minimal dans _out..."
$miniDir = Join-Path $outDir "_zip_test_dir"
$miniZip = Join-Path $outDir "_zip_test.zip"
if(Test-Path $miniDir){ Remove-Item -LiteralPath $miniDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $miniDir | Out-Null
Set-Content -LiteralPath (Join-Path $miniDir "hello.txt") -Value "hello" -Encoding UTF8
if(Test-Path $miniZip){ Remove-Item -LiteralPath $miniZip -Force }

try{
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
  [System.IO.Compression.ZipFile]::CreateFromDirectory($miniDir, $miniZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
  Write-Host "[DIAG] mini zip created: $miniZip exists=$(Test-Path $miniZip)"
}catch{
  Write-Host "[DIAG] mini zip FAILED: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
  throw
}

Write-Host "============================================================"
Write-Host "DIAG DONE"
Write-Host "============================================================"
'@

Set-Content -LiteralPath $diagPath -Value $diag -Encoding UTF8
Write-Host "[PATCH] OK: tools\diag_bundle_zip.ps1 créé"
