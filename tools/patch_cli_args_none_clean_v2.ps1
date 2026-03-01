$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$cli  = Join-Path $root "altiora.py"
if(!(Test-Path $cli)){ throw "altiora.py introuvable: $cli" }

$raw = Get-Content $cli -Encoding UTF8 -Raw

# 0) Supprimer les CR orphelins (le vrai coupable des ^M dans le diff)
#    (on garde les vrais CRLF, mais on enlève les \r qui ne précèdent pas \n)
$raw = [regex]::Replace($raw, "`r(?!`n)", "")

# 1) Enlever toute ligne args = None existante (pour repartir clean)
$raw = [regex]::Replace($raw, '(?m)^\s*args\s*=\s*None\s*$\n', '')

# 2) Injecter args=None juste avant la première occurrence de args = parser.parse_args()
$patched = [regex]::Replace(
  $raw,
  '(?m)^(?<indent>\s*)args\s*=\s*parser\.parse_args\(\)\s*$',
  { param($m) $m.Groups['indent'].Value + "args = None`n" + $m.Value },
  1
)

if($patched -eq $raw){
  throw "Cible introuvable: args = parser.parse_args()"
}

# 3) Normaliser toutes les fins de ligne en CRLF (Windows clean)
#    a) convertir CRLF -> LF
$patched = $patched -replace "`r`n", "`n"
#    b) split + join en CRLF
$lines = $patched -split "`n", 0
$patched = [string]::Join("`r`n", $lines)

# 4) Nettoyer les lignes vides finales: garder exactement 1 newline en fin de fichier
#    - retire les espaces/retours en fin, puis rajoute CRLF
$patched = $patched.TrimEnd("`r","`n"," ","`t") + "`r`n"

Set-Content -Path $cli -Value $patched -Encoding UTF8

python -m py_compile $cli

Write-Host "OK patch appliqué: args=None clean + EOL CRLF + EOF clean (no ^M)."
