$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\safe_fs.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "introuvable: $target" }

$arr = Get-Content -LiteralPath $target -Encoding UTF8

# Remove any [CmdletBinding(...)] line to avoid duplicate common parameter ErrorAction
$new = New-Object System.Collections.Generic.List[string]
$removed = 0
foreach($l in $arr){
  if($l -match '^\s*\[CmdletBinding\b'){
    $removed++
    continue
  }
  [void]$new.Add($l)
}

if($removed -lt 1){
  throw "Patch: aucune ligne [CmdletBinding] trouvée dans tools\safe_fs.ps1 (déjà patché ?)"
}

Set-Content -LiteralPath $target -Value $new -Encoding UTF8

# Self-check: ensure Safe-GetChildItem still exists and no CmdletBinding remains
$after = Get-Content -LiteralPath $target -Encoding UTF8
if(($after | Select-String -Pattern '^\s*\[CmdletBinding\b' -Quiet)){
  throw "Patch FAILED: CmdletBinding encore présent"
}
if(-not ($after | Select-String -Pattern 'function\s+Safe-GetChildItem\b' -Quiet)){
  throw "Patch FAILED: Safe-GetChildItem introuvable après patch"
}

Write-Host "OK: removed CmdletBinding from tools\safe_fs.ps1 (prevents duplicate -ErrorAction)" -ForegroundColor Green
