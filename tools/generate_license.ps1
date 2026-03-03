# ABP_LICENSE_GEN_V4
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string] $Email,

  [Parameter()]
  [int] $Days = 365,

  [Parameter()]
  [string] $OutDir = ".\_out\licenses",

  [Parameter()]
  [string] $PrivateKey = ".\keys\altiora_private_key.pem"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot | Out-Null

py .\tools\generate_license.py --email $Email --days $Days --out-dir $OutDir --private-key $PrivateKey
if($LASTEXITCODE -ne 0){
  throw "generate_license.py failed (exit=$LASTEXITCODE)"
}
