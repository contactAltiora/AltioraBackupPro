# tools\patch_version_bytes_v9b_SAFE.ps1
$ErrorActionPreference = "Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$altiora = Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $altiora)){ throw "altiora.py introuvable: $altiora" }

$targetVersion = "1.0.17-dev"

# Safety: must not run on main
$branch = (& git branch --show-current 2>$null).Trim()
if([string]::IsNullOrWhiteSpace($branch)){ throw "Impossible de détecter la branche git." }
if($branch -eq "main"){ throw "Refus: tu es sur 'main'. Passe sur dev_v1.0.17." }

function Find-Bytes([byte[]]$haystack, [byte[]]$needle){
  if($needle.Length -eq 0){ return -1 }
  for($i=0; $i -le $haystack.Length - $needle.Length; $i++){
    $ok = $true
    for($j=0; $j -lt $needle.Length; $j++){
      if($haystack[$i+$j] -ne $needle[$j]){ $ok = $false; break }
    }
    if($ok){ return $i }
  }
  return -1
}

function Replace-BytesOnce([byte[]]$data, [byte[]]$old, [byte[]]$new){
  $pos = Find-Bytes $data $old
  if($pos -lt 0){ return @{ ok=$false; data=$data; pos=-1 } }

  $out = New-Object byte[] ($data.Length - $old.Length + $new.Length)

  if($pos -gt 0){
    [Buffer]::BlockCopy($data, 0, $out, 0, $pos)
  }
  [Buffer]::BlockCopy($new, 0, $out, $pos, $new.Length)

  $afterStart = $pos + $old.Length
  $afterLen = $data.Length - $afterStart
  if($afterLen -gt 0){
    [Buffer]::BlockCopy($data, $afterStart, $out, $pos + $new.Length, $afterLen)
  }

  return @{ ok=$true; data=$out; pos=$pos }
}

$bytes = [System.IO.File]::ReadAllBytes($altiora)

# Quick sanity: ensure file contains 1.0.16 at all
$needleSan = [System.Text.Encoding]::UTF8.GetBytes('1.0.16')
if((Find-Bytes $bytes $needleSan) -lt 0){
  throw "Fail-closed: altiora.py ne contient pas '1.0.16' en bytes (inattendu)."
}

# EXACT sequences (as in your grep output)
$old1 = [System.Text.Encoding]::UTF8.GetBytes('VERSION_STR = "Altiora Backup Pro v1.0.16"')
$new1 = [System.Text.Encoding]::UTF8.GetBytes(('VERSION_STR = "Altiora Backup Pro v' + $targetVersion + '"'))

$old2 = [System.Text.Encoding]::UTF8.GetBytes('__version__ = "1.0.16"')
$new2 = [System.Text.Encoding]::UTF8.GetBytes(('__version__ = "' + $targetVersion + '"'))

$old3 = [System.Text.Encoding]::UTF8.GetBytes('sys.stdout.write(''{"ok": true, "version": "Altiora Backup Pro v1.0.16"}\n'')')
$new3 = [System.Text.Encoding]::UTF8.GetBytes(('sys.stdout.write(''{"ok": true, "version": "Altiora Backup Pro v' + $targetVersion + '"}\n'')'))

$r1 = Replace-BytesOnce $bytes $old1 $new1
if(-not $r1.ok){ throw "Fail-closed: motif VERSION_STR exact introuvable." }
$bytes = $r1.data

$r2 = Replace-BytesOnce $bytes $old2 $new2
if(-not $r2.ok){ throw "Fail-closed: motif __version__ exact introuvable." }
$bytes = $r2.data

$r3 = Replace-BytesOnce $bytes $old3 $new3
if(-not $r3.ok){ throw "Fail-closed: motif JSON early exact introuvable." }
$bytes = $r3.data

# Safety: ensure 1.0.16 is gone (strict)
if((Find-Bytes $bytes $needleSan) -ge 0){
  throw "Fail-closed: '1.0.16' est encore présent après remplacement bytes."
}

[System.IO.File]::WriteAllBytes($altiora, $bytes)

& py -c "import py_compile; py_compile.compile('altiora.py', doraise=True); print('py_compile: OK')"

$verOut = (& py altiora.py --version) 2>&1
if($verOut -notmatch [regex]::Escape($targetVersion)){
  Write-Host $verOut
  throw "Smoke FAIL: --version n'affiche pas $targetVersion"
}

$jsonOut = (& py altiora.py --version --json) 2>&1
if($jsonOut -notmatch [regex]::Escape($targetVersion)){
  Write-Host $jsonOut
  throw "Smoke FAIL: --version --json n'affiche pas $targetVersion"
}

Write-Host "PATCH OK v9b (byte-level): $verOut"
Write-Host "PATCH OK v9b JSON: $jsonOut"
