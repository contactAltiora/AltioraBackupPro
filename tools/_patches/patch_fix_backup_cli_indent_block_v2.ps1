$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

# On repart du même bloc : celui qui commence par parser.add_argument(
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith("parser.add_argument(")){
    # IMPORTANT : on cible la première occurrence DANS run() en regardant le contenu, même si déjà indentée
    $start = $i
    break
  }
}
if($start -lt 0){ throw "ERROR: cannot find 'parser.add_argument(' in backup_cli.py" }

# Fin du bloc : même logique qu'avant
$end = $lines.Count - 1
for($i=$start; $i -lt $lines.Count; $i++){
  $t = $lines[$i].TrimStart()
  if($i -gt $start -and ($t.StartsWith("if __name__") -or $t.StartsWith("class ") -or $t.StartsWith("def "))){
    $end = $i - 1
    break
  }
}

$target = "        "  # 8 spaces

for($i=$start; $i -le $end; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  # On enlève toute indentation existante, puis on met exactement 8 espaces
  $code = $ln.TrimStart()

  # On garde les commentaires/strings tels quels, mais à indent 8
  $lines[$i] = $target + $code
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: indentation normalisée à 8 espaces dans backup_cli.py (lignes $($start+1)-$($end+1))"
