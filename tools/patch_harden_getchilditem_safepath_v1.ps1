$ErrorActionPreference="Stop"
. "$PSScriptRoot\safe_fs.ps1"

if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root  = (Get-Location).Path
$tools = Join-Path $root "tools"
if(!(Test-Path -LiteralPath $tools)){ throw "tools/ introuvable: $tools" }

# 1) Create common helper: tools\safe_fs.ps1
$safeFs = Join-Path $tools "safe_fs.ps1"
if(!(Test-Path -LiteralPath $safeFs)){
@"
`$ErrorActionPreference="Stop"

function Assert-SafePath {
  param([Parameter(Mandatory=`$true)][string]`$Path)
  if([string]::IsNullOrWhiteSpace(`$Path)){ throw "SafePath: path vide/refuse" }

  `$p = `$Path.Trim()

  if(`$p -match '^[A-Za-z]:\\?$'){ throw "SafePath: racine disque interdite: `$p" }
  if(`$p -eq "\"){ throw "SafePath: racine FS interdite: `$p" }

  if(!(Test-Path -LiteralPath `$p)){ throw "SafePath: chemin introuvable: `$p" }
}

function Safe-GetChildItem {
  [CmdletBinding(DefaultParameterSetName="Path")]
  param(
    [Parameter(Mandatory=`$true, ParameterSetName="Path")]   [string]`$Path,
    [Parameter(Mandatory=`$true, ParameterSetName="Literal")] [string]`$LiteralPath,
    [switch]`$Recurse,
    [switch]`$File,
    [string]`$Filter,
    [ValidateSet("SilentlyContinue","Continue","Stop","Ignore","Inquire","Suspend")]
    [string]`$ErrorAction = "Stop"
  )

  `$splat = @{ ErrorAction = `$ErrorAction }

  if(`$PSCmdlet.ParameterSetName -eq "Literal"){
    Assert-SafePath -Path `$LiteralPath
    `$splat["LiteralPath"] = `$LiteralPath
  } else {
    Assert-SafePath -Path `$Path
    `$splat["Path"] = `$Path
  }

  if(`$Recurse){ `$splat["Recurse"] = `$true }
  if(`$File){    `$splat["File"]    = `$true }
  if(`$Filter){  `$splat["Filter"]  = `$Filter }

  return Get-ChildItem @splat
}
"@ | Set-Content -LiteralPath $safeFs -Encoding UTF8

  Write-Host "OK: created tools\safe_fs.ps1" -ForegroundColor Green
}else{
  Write-Host "OK: tools\safe_fs.ps1 already exists" -ForegroundColor DarkGreen
}

function Ensure-DotSourceSafeFs([string[]]$lines){
  $needle = '. "$PSScriptRoot\safe_fs.ps1"'
  foreach($l in $lines){ if($l.Trim() -eq $needle){ return ,$lines } }

  $out = New-Object System.Collections.Generic.List[string]
  $inserted = $false
  for($i=0; $i -lt $lines.Count; $i++){
    [void]$out.Add($lines[$i])
    if(-not $inserted -and $lines[$i] -match '^\s*\$ErrorActionPreference\s*=\s*"?Stop"?\s*$'){
      [void]$out.Add($needle)
      [void]$out.Add('')
      $inserted = $true
    }
  }
  if(-not $inserted){
    $out2 = New-Object System.Collections.Generic.List[string]
    [void]$out2.Add($needle)
    [void]$out2.Add('')
    foreach($l in $out){ [void]$out2.Add($l) }
    return ,$out2.ToArray()
  }
  return ,$out.ToArray()
}

function Harden-GetChildItemLines([string[]]$lines){
  $out = New-Object System.Collections.Generic.List[string]
  foreach($line in $lines){
    $l = $line
    if($l -match '^\s*Get-ChildItem\b' -and $l -match '\s-Recurse\b'){
      if($l -match '^\s*Get-ChildItem\s+-Path\s+(.+?)\s+-Recurse\b'){
        $l = $l -replace '^\s*Get-ChildItem\b', 'Safe-GetChildItem'
      } elseif($l -match '^\s*Get-ChildItem\s+-LiteralPath\s+(.+?)\s+-Recurse\b'){
        $l = $l -replace '^\s*Get-ChildItem\b', 'Safe-GetChildItem'
      } elseif($l -match '^\s*Get-ChildItem\s+"[^"]+"\s+-Recurse\b'){
        $l = $l -replace '^\s*Get-ChildItem\s+("([^"]+)")\s+', 'Safe-GetChildItem -LiteralPath $1 '
      } elseif($l -match '^\s*Get-ChildItem\s+\$[A-Za-z_][A-Za-z0-9_]*\s+-Recurse\b'){
        $l = $l -replace '^\s*Get-ChildItem\s+(\$[A-Za-z_][A-Za-z0-9_]*)\s+', 'Safe-GetChildItem -LiteralPath $1 '
      }
    }
    [void]$out.Add($l)
  }
  return ,$out.ToArray()
}

# 2) Target scripts
$targets = New-Object System.Collections.Generic.List[string]
$targets.Add((Join-Path $tools "release_build_and_backup.ps1"))

$finalize = Join-Path $tools "release_finalize_and_state.ps1"
if(Test-Path -LiteralPath $finalize){ $targets.Add($finalize) }

Safe-GetChildItem -LiteralPath $tools -File -Filter "snapshot*.ps1" -OnError SilentlyContinue | ForEach-Object {
  $targets.Add($_.FullName)
}

$uniq = @{}
$targets = $targets | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | ForEach-Object {
  if(-not $uniq.ContainsKey($_)){ $uniq[$_] = $true; $_ }
}

if($targets.Count -eq 0){
  throw "Aucun script cible trouvé dans $tools (release_build_and_backup.ps1 manquant ?)"
}

foreach($t in $targets){
  $before = Get-Content -LiteralPath $t -Encoding UTF8
  $arr = $before
  $arr = Ensure-DotSourceSafeFs -lines $arr
  $arr = Harden-GetChildItemLines -lines $arr
  Set-Content -LiteralPath $t -Value $arr -Encoding UTF8

  $after = Get-Content -LiteralPath $t -Encoding UTF8
  $hasDot = $false
  foreach($l in $after){ if($l.Trim() -eq '. "$PSScriptRoot\safe_fs.ps1"'){ $hasDot = $true; break } }
  if(-not $hasDot){ throw "Patch failed: dot-source missing in $t" }

  Write-Host "OK: hardened $t" -ForegroundColor Green
}

Write-Host "OK: hardening complete (safe_fs + dot-source + conservative replacements)" -ForegroundColor Green
