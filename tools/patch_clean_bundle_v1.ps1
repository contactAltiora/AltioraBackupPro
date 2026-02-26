$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis (utiliser patch_runner.ps1)"
}

$rootExpected = "C:\Dev\AltioraBackupPro"
$root = (Get-Location).Path
if($root.TrimEnd('\') -ne $rootExpected){
  throw "patch_clean_bundle_v1: exécuter depuis $rootExpected (actuel: $root)"
}

function Fail($m){ throw "patch_clean_bundle_v1: $m" }

$bundlePath = Join-Path $root "tools\bundle_BACKUP_PRO_ALTIORA.ps1"
if(!(Test-Path $bundlePath)){
  Fail "bundle script introuvable: $bundlePath"
}

$raw = Get-Content -LiteralPath $bundlePath -Encoding UTF8 -Raw

$marker = "# --- DIAG staging ---"
$idx = $raw.IndexOf($marker)
if($idx -lt 0){
  Fail "marker introuvable dans bundle script: $marker"
}

# Idempotence: si déjà patché, on ne fait rien
if($raw -match "(?m)^\s*#\s*---\s*CLEAN\s*source_repo\s*---\s*$"){
  Write-Host "[PATCH] clean bundle déjà présent (skip)"
  return
}

$cleanBlock = @'
# --- CLEAN source_repo ---
# On nettoie uniquement les artefacts inutiles dans source_repo (pycache/pyc/bak/old)
$srcRepo = Join-Path $staging "source_repo"
if(Test-Path $srcRepo){
  # 1) dossiers __pycache__
  Get-ChildItem -LiteralPath $srcRepo -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ieq "__pycache__" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }

  # 2) fichiers *.pyc
  Get-ChildItem -LiteralPath $srcRepo -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq ".pyc" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }

  # 3) fichiers *.bak / *.old (souvent du bruit dans les bundles)
  Get-ChildItem -LiteralPath $srcRepo -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -ieq ".bak" -or $_.Extension -ieq ".old" } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
}
'@

# Insérer juste avant le marker
$before = $raw.Substring(0, $idx)
$after  = $raw.Substring($idx)

# Assurer une ligne vide propre avant insertion
if(-not $before.EndsWith("`n")){ $before += "`n" }
$patched = $before + $cleanBlock + "`n" + $after

Set-Content -LiteralPath $bundlePath -Value $patched -Encoding UTF8
Write-Host "[PATCH] OK: bundle_BACKUP_PRO_ALTIORA.ps1 -> ajout CLEAN source_repo (pycache/pyc/bak/old)"