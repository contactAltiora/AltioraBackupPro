$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$cli  = Join-Path $root "altiora.py"
if(!(Test-Path $cli)){ throw "altiora.py introuvable: $cli" }

# Lire bytes -> string (UTF-8 avec BOM si présent)
$bytes = [System.IO.File]::ReadAllBytes($cli)
$raw   = [System.Text.Encoding]::UTF8.GetString($bytes)

# Déjà OK ?
if($raw -match '(?m)^\s*args\s*=\s*None\s*\r?\n\s*args\s*=\s*parser\.parse_args\(\)\s*$'){
  Write-Host "Déjà OK (args=None avant parse_args)."
  exit 0
}

# Trouver la 1ère occurrence EXACTE de la ligne parse_args (on garde l'EOL existante)
$pattern = '(?m)^(?<indent>[ \t]*)args\s*=\s*parser\.parse_args\(\)\s*$'
$m = [regex]::Match($raw, $pattern)
if(-not $m.Success){
  throw "Cible introuvable: ligne 'args = parser.parse_args()'"
}

# Détecter le style EOL local (CRLF si présent juste après la ligne matchée, sinon LF)
$afterIndex = $m.Index + $m.Length
$eol = "`n"
if($afterIndex -lt $raw.Length){
  # si le caractère juste après la ligne matchée est \r ou \n, on déduit
  $next = $raw.Substring($afterIndex, [Math]::Min(2, $raw.Length - $afterIndex))
  if($next.StartsWith("`r`n")){ $eol="`r`n" }
  elseif($next.StartsWith("`n")){ $eol="`n" }
  elseif($next.StartsWith("`r")){ $eol="`r" } # rare
}

$indent = $m.Groups["indent"].Value
$insert = "${indent}args = None${eol}"

# Insérer juste avant la ligne
$patched = $raw.Substring(0, $m.Index) + $insert + $raw.Substring($m.Index)

# Écrire bytes UTF-8 (BOM conservé via U+FEFF si présent)
$outBytes = [System.Text.Encoding]::UTF8.GetBytes($patched)
[System.IO.File]::WriteAllBytes($cli, $outBytes)

python -m py_compile $cli
Write-Host "OK patch appliqué: insertion args=None uniquement (sans normaliser EOL/BOM)."
