$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

# A) supprimer le bloc parasite top-level: parser.add_argument( au niveau 0 jusqu'à la reprise indent>=8
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].StartsWith("parser.add_argument(")){ $start = $i; break }
}
if($start -ge 0){
  $end = -1
  for($i=$start+1; $i -lt $lines.Count; $i++){
    if($lines[$i] -match '^[ ]{8}\S'){ $end = $i - 1; break }
  }
  if($end -lt 0){ throw "ERROR: cannot find end of top-level block after parser.add_argument(" }

  $out = @()
  if($start -gt 0){ $out += $lines[0..($start-1)] }
  if($end+1 -le $lines.Count-1){ $out += $lines[($end+1)..($lines.Count-1)] }
  $lines = $out
}

# B) normaliser indent -> multiple de 4 (seulement espaces)
for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }
  $n = LeadingSpaces $ln
  if($n -gt 0){
    $mod = $n % 4
    if($mod -ne 0){
      $add = 4 - $mod
      $lines[$i] = (" " * $add) + $ln
    }
  }
}

# C) Forcer le corps du bloc stats si déindenté:
# trouver 'elif args.command == "stats":' et pousser les lignes suivantes à indent >= base+4 jusqu'au prochain elif/else au même base
$idx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith('elif args.command == "stats":')){ $idx = $i; break }
}
if($idx -ge 0){
  $base = LeadingSpaces $lines[$idx]
  $need = $base + 4
  for($j=$idx+1; $j -lt $lines.Count; $j++){
    $ln = $lines[$j]
    if([string]::IsNullOrWhiteSpace($ln)){ continue }
    $trim = $ln.TrimStart()
    $sp = LeadingSpaces $ln
    if($sp -eq $base -and ($trim.StartsWith("elif ") -or $trim.StartsWith("else:"))){ break }
    if($sp -lt $need){ $lines[$j] = (" " * ($need - $sp)) + $ln }
  }
}

# D) Sécurité: tout 'def ...:' qui n'a pas de ligne suivante indentée -> insérer 'pass'
# (évite l'erreur line 86/87)
$out2 = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  $out2.Add($lines[$i])
  $t = $lines[$i].TrimStart()

  # détecter def ...:
  if($t -match '^def\s+\w+\s*\(.*\)\s*:\s*$'){
    $curIndent = LeadingSpaces $lines[$i]
    $nextIdx = $i + 1
    if($nextIdx -lt $lines.Count){
      $next = $lines[$nextIdx]
      $nextIndent = LeadingSpaces $next
      $nextTrim = $next.Trim()
      # si prochaine ligne vide ou indent <= curIndent => pas de corps
      if([string]::IsNullOrWhiteSpace($next) -or ($nextIndent -le $curIndent)){
        $out2.Add((" " * ($curIndent + 4)) + "pass")
      }
    } else {
      $out2.Add((" " * ($curIndent + 4)) + "pass")
    }
  }
}

Set-Content -Path $path -Value $out2.ToArray() -Encoding UTF8
Write-Host "OK: backup_cli.py réparé (v8)."
