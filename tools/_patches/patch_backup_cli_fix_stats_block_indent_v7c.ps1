$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

# 1) trouver la ligne "elif args.command == "stats":"
$idx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith('elif args.command == "stats":')){
    $idx = $i; break
  }
}
if($idx -lt 0){ throw 'ERROR: cannot find elif args.command == "stats":' }

$base = LeadingSpaces $lines[$idx]          # indent du elif
$need = $base + 4                           # indent attendu du corps
$changed = 0

# 2) indenter les lignes suivantes jusqu'au prochain elif/else au même niveau (ou EOF)
for($j=$idx+1; $j -lt $lines.Count; $j++){
  $ln = $lines[$j]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $trim = $ln.TrimStart()
  $sp = LeadingSpaces $ln

  # stop si on retrouve un elif/else au même niveau que le base
  if($sp -eq $base -and ($trim.StartsWith("elif ") -or $trim.StartsWith("else:"))){
    break
  }

  # stop si on revient clairement au niveau run() (indent 4) ou class (0) -> sécurité
  if($sp -lt $base){
    break
  }

  # si la ligne n'est pas assez indentée pour être dans le bloc stats, on la pousse
  if($sp -lt $need){
    $add = $need - $sp
    $lines[$j] = (" " * $add) + $ln
    $changed++
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: bloc stats indenté (lignes modifiées: $changed) base=$base need=$need"
