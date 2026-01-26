$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

# Find the 'elif args.command == "stats":' line
$idx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith('elif args.command == "stats":')){
    $idx = $i; break
  }
}
if($idx -lt 0){ throw 'ERROR: cannot find elif args.command == "stats":' }

$base = LeadingSpaces $lines[$idx]   # expected 8
$need = $base + 4                    # expected 12

$changed = 0
for($j=$idx+1; $j -lt $lines.Count; $j++){
  $ln = $lines[$j]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $trim = $ln.TrimStart()
  $sp = LeadingSpaces $ln

  # Stop when we hit next sibling branch at same level
  if($sp -eq $base -and ($trim.StartsWith("elif ") -or $trim.StartsWith("else:"))){
    break
  }

  # Force minimum indent for stats-body
  if($sp -lt $need){
    $add = $need - $sp
    $lines[$j] = (" " * $add) + $ln
    $changed++
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: bloc stats forcé à indent>=${need} (lignes modifiées: $changed) base=$base"
