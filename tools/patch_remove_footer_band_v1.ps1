$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$candidates = @(
  (Join-Path $root "altiora.py"),
  (Join-Path $root "src\altiora_cli.py"),
  (Join-Path $root "src\cli_ui.py"),
  (Join-Path $root "src\ui_banner.py")
) | Where-Object { Test-Path $_ }

if($candidates.Count -eq 0){
  throw "Aucun fichier candidat trouvé (altiora.py / src\altiora_cli.py / src\cli_ui.py / src\ui_banner.py)"
}

# Lignes/segments à retirer (footer band)
$needles = @(
  "support@altiora-backup.com",
  "📞 Support:",
  "💰 Prix:",
  "Prix:",
  "⚖️ Garantie 30 jours",
  "Garantie 30 jours",
  "🚀 Altiora Backup Pro v1.0",
  "Altiora Backup Pro v1.0"
)

$changed = 0

foreach($f in $candidates){
  $lines = Get-Content -LiteralPath $f -Encoding UTF8

  $new = New-Object System.Collections.Generic.List[string]
  foreach($ln in $lines){
    $hit = $false
    foreach($n in $needles){
      if($ln -like "*$n*"){ $hit = $true; break }
    }
    if(-not $hit){ $new.Add($ln) }
  }

  $oldText = ($lines -join "`n")
  $newText = ($new.ToArray() -join "`n")

  if($newText -ne $oldText){
    Set-Content -LiteralPath $f -Value $newText -Encoding UTF8
    Write-Host "[PATCH] updated: $f"
    $changed++
  }
}

if($changed -eq 0){
  Write-Host "[PATCH] OK: aucun footer band trouvé (rien à modifier)"
} else {
  Write-Host "[PATCH] OK: footer band supprimé dans $changed fichier(s)"
}
