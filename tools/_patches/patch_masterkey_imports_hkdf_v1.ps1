$ErrorActionPreference = "Stop"

$root = "C:\Dev\AltioraBackupPro"
$mk   = Join-Path $root "src\master_key.py"
if(-not (Test-Path $mk)) { throw "ERROR: missing file: $mk" }

function WriteUtf8NoBom([string]$path, [string]$text){
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

$txt = Get-Content -Path $mk -Raw -Encoding UTF8

$need1 = ($txt -notmatch 'from\s+cryptography\.hazmat\.primitives\.kdf\.hkdf\s+import\s+HKDF')
$need2 = ($txt -notmatch 'from\s+cryptography\.hazmat\.primitives\s+import\s+hashes')

if(-not $need1 -and -not $need2){
  Write-Host "INFO: HKDF/hashes imports already present."
  py -m py_compile $mk
  Write-Host "OK: py_compile master_key.py"
  exit 0
}

# insertion anchor: juste après l'import Scrypt si possible, sinon après la première ligne d'import cryptography
$anchor = "from cryptography.hazmat.primitives.kdf.scrypt import Scrypt"
$ins = ""

if($need1){ $ins += "from cryptography.hazmat.primitives.kdf.hkdf import HKDF`r`n" }
if($need2){ $ins += "from cryptography.hazmat.primitives import hashes`r`n" }
$ins += "`r`n"

if($txt.Contains($anchor)){
  $txt2 = $txt.Replace($anchor + "`r`n", $anchor + "`r`n" + $ins)
} else {
  # fallback: cherche une ligne "from cryptography" et insère juste après la première occurrence
  $lines = $txt -split "`r`n", 0, "SimpleMatch"
  $idx = -1
  for($i=0; $i -lt $lines.Length; $i++){
    if($lines[$i] -like "from cryptography*"){ $idx = $i; break }
  }
  if($idx -lt 0){ throw "ERROR: cannot find any 'from cryptography...' import line to insert after." }

  $before = ($lines[0..$idx] -join "`r`n") + "`r`n"
  $after  = ($lines[($idx+1)..($lines.Length-1)] -join "`r`n")
  $txt2   = $before + $ins + $after
}

WriteUtf8NoBom $mk $txt2
Write-Host "OK: master_key.py imports patched."

py -m py_compile $mk
Write-Host "OK: py_compile master_key.py"
