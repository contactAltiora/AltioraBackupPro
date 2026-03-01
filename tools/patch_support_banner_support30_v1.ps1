$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$root = (Get-Location).Path
$cli  = Join-Path $root "altiora.py"
if(!(Test-Path $cli)){ throw "altiora.py introuvable: $cli" }

$raw = Get-Content $cli -Encoding UTF8 -Raw

$old = "✅ Succès — Support: garantie 30 jours"
$new = "✅ Succès — Support inclus : 30 jours"

# Compte occurrences (doit être 1, sinon on refuse)
$cnt = ([regex]::Matches($raw, [regex]::Escape($old))).Count
if($cnt -eq 0){
  throw "Bandeau introuvable (0 match): '$old'"
}
if($cnt -ne 1){
  throw "Bandeau ambigu ($cnt matchs) — refuse de patcher"
}

$patched = $raw.Replace($old, $new)

if($patched -eq $raw){ throw "Patch no-op inattendu" }

Set-Content -Path $cli -Value $patched -Encoding UTF8

# sécurité: compilation
python -m py_compile $cli

Write-Host "OK patch appliqué: '$old' -> '$new'"
