$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

# Helper: find first line index that matches exact start (trim-left sensitive)
function FindLineExactStart($arr, $startIdx, $prefix){
  for($i=$startIdx; $i -lt $arr.Count; $i++){
    if($arr[$i].StartsWith($prefix)){ return $i }
  }
  return -1
}

# 1) repérer le début du bloc mal indenté : "parser.add_argument(" au niveau 0
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].StartsWith("parser.add_argument(")){
    $start = $i
    break
  }
}
if($start -lt 0){ throw "ERROR: cannot find top-level 'parser.add_argument(' in backup_cli.py" }

# 2) repérer fin du bloc à re-indenter :
# on s'arrête avant un éventuel top-level 'if __name__' OU avant une nouvelle 'class ' OU EOF
$end = $lines.Count - 1
for($i=$start; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  if($i -gt $start -and ($ln.StartsWith("if __name__") -or $ln.StartsWith("class ") -or $ln.StartsWith("def "))){
    $end = $i - 1
    break
  }
}

# 3) appliquer indent 8 espaces à chaque ligne non vide du bloc (et conserver les lignes déjà indentées)
$indent = "        "  # 8 spaces
for($i=$start; $i -le $end; $i++){
  if([string]::IsNullOrWhiteSpace($lines[$i])){ continue }
  if($lines[$i] -match '^\s'){ 
    # déjà indenté (ex: 4 espaces) -> on ajoute pour entrer dans run()
    $lines[$i] = $indent + $lines[$i]
  } else {
    # top-level -> on indente
    $lines[$i] = $indent + $lines[$i]
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: bloc re-indenté dans backup_cli.py (lignes $($start+1)-$($end+1))"
