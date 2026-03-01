$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root   = (Get-Location).Path
$target = Join-Path $root "tools\release_build_and_backup.ps1"
if(!(Test-Path -LiteralPath $target)){ throw "introuvable: $target" }

$arr = Get-Content -LiteralPath $target -Encoding UTF8

# Find README block lines and update the "Fichiers :" section
$start = -1
$end   = -1

for($i=0; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*\$readme\s*=\s*@\"'){
    $start = $i
    break
  }
}
if($start -lt 0){ throw "readme here-string start not found" }

for($i=$start+1; $i -lt $arr.Count; $i++){
  if($arr[$i] -match '^\s*\"@\s*$'){
    $end = $i
    break
  }
}
if($end -lt 0){ throw "readme here-string end not found" }

# Build new block with minimal deterministic edits:
# After the existing file list, insert STATE + keys entries (if not already present)
$block = $arr[$start..$end]

$already = $false
foreach($l in $block){
  if($l -match 'STATE\.md'){ $already = $true; break }
}

if(-not $already){
  $newBlock = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $block.Count; $i++){
    [void]$newBlock.Add($block[$i])
    if($block[$i] -match '^\s*-\s*AltioraBackupPro_v\$ver\.sha256\s*$'){
      [void]$newBlock.Add('  - STATE.md')
      [void]$newBlock.Add('  - STATE.md.sig')
      [void]$newBlock.Add('  - keys\altiora_public_key.pem')
    }
  }

  # Replace in arr
  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $arr.Count; $i++){
    if($i -eq $start){
      foreach($l in $newBlock){ [void]$out.Add($l) }
      $i = $end
      continue
    }
    [void]$out.Add($arr[$i])
  }

  Set-Content -LiteralPath $target -Value $out -Encoding UTF8
}

# Self-check
$after = Get-Content -LiteralPath $target -Encoding UTF8
$ok = $false
for($i=0; $i -lt $after.Count; $i++){
  if($after[$i] -match 'keys\\altiora_public_key\.pem'){ $ok = $true; break }
}
if(-not $ok){ throw "Patch FAILED: README entries not found after write" }

Write-Host "OK: README release now lists STATE + key assets" -ForegroundColor Green
