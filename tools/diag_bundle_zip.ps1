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
  Get-ChildItem -LiteralPath $outDir | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize | Out-String | Write-Host
}

$staging = Join-Path $outDir "bundle_BACKUP_PRO_ALTIORA"
Write-Host "[DIAG] staging: $staging exists=$(Test-Path $staging)"
if(Test-Path $staging){
  Get-ChildItem -LiteralPath $staging -Recurse -ErrorAction SilentlyContinue |
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
