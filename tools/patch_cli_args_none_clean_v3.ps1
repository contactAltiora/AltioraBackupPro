$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$cli  = Join-Path $root "altiora.py"
if(!(Test-Path $cli)){ throw "altiora.py introuvable: $cli" }

# Lire en binaire -> décoder UTF-8
$bytes = [System.IO.File]::ReadAllBytes($cli)
$raw   = [System.Text.Encoding]::UTF8.GetString($bytes)

# 1) Normaliser EOL en LF d'abord
$raw = $raw -replace "`r`n", "`n"
$raw = $raw -replace "`r", "`n"

# 2) Enlever toute ligne args=None existante
$raw = [regex]::Replace($raw, '(?m)^\s*args\s*=\s*None\s*$\n', '')

# 3) Injecter args=None avant la 1ère occurrence de parse_args()
$patched = [regex]::Replace(
  $raw,
  '(?m)^(?<indent>\s*)args\s*=\s*parser\.parse_args\(\)\s*$',
  { param($m) $m.Groups['indent'].Value + "args = None`n" + $m.Value },
  1
)

if($patched -eq $raw){
  throw "Cible introuvable: args = parser.parse_args()"
}

# 4) Nettoyer fin de fichier => 1 newline LF
$patched = $patched.TrimEnd("`n"," ","`t") + "`n"

# 5) Reconvertir en CRLF (Windows) propre
$patched = $patched -replace "`n", "`r`n"

# Écrire en binaire UTF-8 (sans laisser PowerShell toucher aux EOL)
$outBytes = [System.Text.Encoding]::UTF8.GetBytes($patched)
[System.IO.File]::WriteAllBytes($cli, $outBytes)

python -m py_compile $cli
Write-Host "OK patch appliqué: EOL CRLF propre + args=None clean (no ^M)."
