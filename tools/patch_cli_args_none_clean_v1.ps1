$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$cli  = Join-Path $root "altiora.py"
if(!(Test-Path $cli)){ throw "altiora.py introuvable: $cli" }

$raw = Get-Content $cli -Encoding UTF8 -Raw

# 1) Supprime toute ligne 'args = None' déjà présente (pour repartir clean)
# (au cas où elle contient un CR parasite)
$raw2 = [regex]::Replace($raw, '(?m)^\s*args\s*=\s*None\s*\r?\n', '')

# 2) Injecte args=None juste avant la première occurrence de args = parser.parse_args()
$patched = [regex]::Replace(
  $raw2,
  '(?m)^(?<indent>\s*)args\s*=\s*parser\.parse_args\(\)\s*$',
  { param($m) $m.Groups['indent'].Value + "args = None`r`n" + $m.Value },
  1
)

if($patched -eq $raw2){
  throw "Cible introuvable: args = parser.parse_args()"
}

Set-Content -Path $cli -Value $patched -Encoding UTF8

python -m py_compile $cli

Write-Host "OK patch appliqué: args=None (clean) avant parse_args()"
