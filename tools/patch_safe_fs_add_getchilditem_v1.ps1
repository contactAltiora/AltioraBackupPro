$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$target = Join-Path $root "tools\safe_fs.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "safe_fs.ps1 introuvable: $target" }

$txt = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if($txt -match "function\s+Safe-GetChildItem\s*\{"){
  "SKIP: Safe-GetChildItem déjà présent"
  exit 0
}

$append = @' 

function Safe-GetChildItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [switch]$File,
    [switch]$Directory,
    [switch]$Recurse
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath"
  if(!(Test-Path -LiteralPath $LiteralPath)){ throw "Introuvable: $LiteralPath" }

  $args = @{ LiteralPath = $LiteralPath }
  if($File){ $args["File"] = $true }
  if($Directory){ $args["Directory"] = $true }
  if($Recurse){ $args["Recurse"] = $true }
  return (Get-ChildItem @args)
}

'@

# Insert before final marker if present, else append
$marker = "# End of safe_fs.ps1"
if($txt -match [regex]::Escape($marker)){
  $new = $txt -replace [regex]::Escape($marker), ($append + "`r`n" + $marker)
} else {
  $new = $txt + "`r`n" + $append
}

Set-Content -LiteralPath $target -Value $new -Encoding UTF8

# Syntax check in clean PowerShell
$cmd = ". `"" + $target + "`"; 'SAFE_FS_OK'"
$p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd) -Wait -PassThru
if($p.ExitCode -ne 0){ throw "safe_fs.ps1 syntax check failed (ExitCode=$($p.ExitCode))" }

"PATCH OK: added Safe-GetChildItem -> $target"
