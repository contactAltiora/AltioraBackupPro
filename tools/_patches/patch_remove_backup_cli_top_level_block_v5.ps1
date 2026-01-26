$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

# 1) trouver le début: une ligne EXACTEMENT au niveau 0 qui commence par "parser.add_argument("
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].StartsWith("parser.add_argument(")){
    $start = $i; break
  }
}
if($start -lt 0){
  Write-Host "INFO: aucun bloc top-level parser.add_argument trouvé (rien à supprimer)."
  exit 0
}

# 2) trouver la fin: la première ligne après start qui est indentée à 8 espaces
# (le vrai code dans run() reprend à ce niveau)
$end = -1
for($i=$start+1; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^[ ]{8}\S'){
    $end = $i - 1
    break
  }
}
if($end -lt 0){
  throw "ERROR: impossible de déterminer la fin du bloc top-level (pas de reprise indent=8 trouvée)."
}

# 3) supprimer le bloc [start..end]
$beforeCount = $lines.Count
$out = @()
if($start -gt 0){ $out += $lines[0..($start-1)] }
if($end+1 -le $lines.Count-1){ $out += $lines[($end+1)..($lines.Count-1)] }

Set-Content -Path $path -Value $out -Encoding UTF8
Write-Host "OK: bloc top-level supprimé (lignes $($start+1)-$($end+1)), total $beforeCount -> $($out.Count)"
