$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\safe_fs.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "safe_fs.ps1 introuvable: $target" }

$txt = Get-Content -LiteralPath $target -Encoding UTF8 -Raw
if($txt -notmatch "function\s+Safe-GetChildItem\s*\{"){ throw "Safe-GetChildItem introuvable dans safe_fs.ps1" }

# Replace the Safe-GetChildItem function block with an updated version that supports -Filter
$pattern = "(?s)function\s+Safe-GetChildItem\s*\{.*?\r?\n\}"

$replacement = @' 
function Safe-GetChildItem {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LiteralPath,
    [string]$Filter,
    [switch]$File,
    [switch]$Directory,
    [switch]$Recurse
  )
  Assert-NotNullOrWhiteSpace -Value $LiteralPath -Name "LiteralPath"
  if(!(Test-Path -LiteralPath $LiteralPath)){ throw "Introuvable: $LiteralPath" }

  $args = @{ LiteralPath = $LiteralPath }
  if($Filter){ $args["Filter"] = $Filter }
  if($File){ $args["File"] = $true }
  if($Directory){ $args["Directory"] = $true }
  if($Recurse){ $args["Recurse"] = $true }
  return (Get-ChildItem @args)
}
'@

$new = [regex]::Replace($txt, $pattern, $replacement, 1)
Set-Content -LiteralPath $target -Value $new -Encoding UTF8

# Syntax check in clean PowerShell
$cmd = ". `"" + $target + "`"; 'SAFE_FS_OK'"
$p = Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-Command",$cmd) -Wait -PassThru
if($p.ExitCode -ne 0){ throw "safe_fs.ps1 syntax check failed (ExitCode=$($p.ExitCode))" }

"PATCH OK: Safe-GetChildItem now supports -Filter"
