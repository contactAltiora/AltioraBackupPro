$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$target = Join-Path $root "tools\safe_fs.ps1"
if(!(Test-Path (Split-Path $target))){ throw "Dossier tools introuvable: $(Split-Path $target)" }

# Rewrite tools\safe_fs.ps1 -> known-good v3 (compat -Filter, -OnError)
$content = @' 
# Altiora Backup Pro — safe_fs.ps1 (known-good v3)
# Helpers filesystem déterministes (PowerShell only)
Set-StrictMode -Version Latest

function _SafeThrow {
  param([string]$OnError, [string]$DefaultMessage)
  if([string]::IsNullOrWhiteSpace($OnError)){ throw $DefaultMessage }
  throw $OnError
}

function Assert-NotNullOrWhiteSpace {
  param(
    [Parameter(Mandatory=$true)][string]$Value,
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$OnError
  )
  if([string]::IsNullOrWhiteSpace($Value)){ _SafeThrow -OnError $OnError -DefaultMessage "$Name est NULL/empty" }
}

function Safe-JoinPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$ChildPath,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $Path -Name "Path" -OnError $OnError
  Assert-NotNullOrWhiteSpace -Value $ChildPath -Name "ChildPath" -OnError $OnError
  return (Join-Path -Path $Path -ChildPath $ChildPath)
}

function Safe-TestPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  return (Test-Path -LiteralPath $LiteralPath)
}

function Safe-GetItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  if(!(Test-Path -LiteralPath $LiteralPath)){ _SafeThrow -OnError $OnError -DefaultMessage "Introuvable: $LiteralPath" }
  return (Get-Item -LiteralPath $LiteralPath)
}

function Safe-GetChildItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$Filter,
    [switch]$File,
    [switch]$Directory,
    [switch]$Recurse,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  if(!(Test-Path -LiteralPath $LiteralPath)){ _SafeThrow -OnError $OnError -DefaultMessage "Introuvable: $LiteralPath" }

  $args = @{ LiteralPath = $LiteralPath }
  if($Filter){ $args["Filter"] = $Filter }
  if($File){ $args["File"] = $true }
  if($Directory){ $args["Directory"] = $true }
  if($Recurse){ $args["Recurse"] = $true }
  return (Get-ChildItem @args)
}

function Safe-ReadAllText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  if(!(Test-Path -LiteralPath $LiteralPath)){ _SafeThrow -OnError $OnError -DefaultMessage "Introuvable: $LiteralPath" }
  return (Get-Content -LiteralPath $LiteralPath -Encoding UTF8 -Raw)
}

function Safe-WriteAllText {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [Parameter(Mandatory=$true)][string]$Text,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  if($null -eq $Text){ _SafeThrow -OnError $OnError -DefaultMessage "Text est NULL" }
  $dir = Split-Path -Path $LiteralPath -Parent
  if([string]::IsNullOrWhiteSpace($dir)){ _SafeThrow -OnError $OnError -DefaultMessage "Impossible de déterminer le dossier parent" }
  New-Item -ItemType Directory -Force $dir | Out-Null
  Set-Content -LiteralPath $LiteralPath -Value $Text -Encoding UTF8
}

function Safe-AssertFileExists {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$OnError
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath" -OnError $OnError
  if(!(Test-Path -LiteralPath $LiteralPath)){ _SafeThrow -OnError $OnError -DefaultMessage "Fichier introuvable: $LiteralPath" }
}

# End of safe_fs.ps1
'@

Set-Content -LiteralPath $target -Value $content -Encoding UTF8

# Syntax check in clean PowerShell
$cmd = ". `"" + $target + "`"; 'SAFE_FS_OK'"
$p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd) -Wait -PassThru
if($p.ExitCode -ne 0){ throw "safe_fs.ps1 syntax check failed (ExitCode=$($p.ExitCode))" }

"PATCH OK: rewritten -> $target"
