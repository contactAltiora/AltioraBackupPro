$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function IndentLen([string]$s){
  $n=0
  while($n -lt $s.Length){
    $ch = $s[$n]
    if($ch -eq ' '){ $n++ }
    elseif($ch -eq "`t"){ $n += 4 } # approx: tab = 4
    else { break }
  }
  return $n
}

# Start: first parser.add_argument( (any indent)
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith("parser.add_argument(")){
    $start = $i; break
  }
}
if($start -lt 0){ throw "ERROR: cannot find 'parser.add_argument(' in backup_cli.py" }

# End: before next top-level def/class/if __name__ (any indent)
$end = $lines.Count - 1
for($i=$start; $i -lt $lines.Count; $i++){
  $t = $lines[$i].TrimStart()
  if($i -gt $start -and ($t.StartsWith("if __name__") -or $t.StartsWith("class ") -or $t.StartsWith("def "))){
    $end = $i - 1; break
  }
}

# Shift: ensure base indent >= 8, but preserve deeper blocks
# Rule: if line is non-empty AND current indent < 8 => add 8 spaces in front
$pad = "        "  # 8 spaces

for($i=$start; $i -le $end; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $cur = IndentLen $ln
  if($cur -lt 8){
    $lines[$i] = $pad + $ln
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: bloc shifté (indent<8 => +8) dans backup_cli.py (lignes $($start+1)-$($end+1))"
