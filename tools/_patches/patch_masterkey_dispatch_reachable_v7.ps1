$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Trouver le bloc masterkey
$mk = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^\s*if\s+args\.command\s*==\s*"masterkey"\s*:'){
    $mk = $i; break
  }
}
if($mk -lt 0){ throw "ERROR: cannot find masterkey dispatch block" }

$mkIndent = LeadingSpaces $lines[$mk]

# 2) Le convertir en ELIF si on est dans une chaîne de dispatch
# On cherche un "if args.command ==" avant, au même indent
$hasChain = $false
for($i=$mk-1; $i -ge 0; $i--){
  if(LeadingSpaces $lines[$i] -ne $mkIndent){ continue }
  if($lines[$i] -match '^\s*(if|elif)\s+args\.command\s*=='){
    $hasChain = $true
    break
  }
}
if($hasChain){
  $lines[$mk] = $lines[$mk] -replace '^\s*if\s+args\.command', (' ' * $mkIndent) + 'elif args.command'
}

# 3) Si le bloc est placé après un return "final", on le remonte avant le dernier fallback parser.print_help()/return
# Heuristique safe: on repère "parser.print_help()" le plus bas au même indent, et on place le bloc juste avant.
$inject = -1
for($i=$lines.Count-1; $i -ge 0; $i--){
  if(LeadingSpaces $lines[$i] -eq $mkIndent -and $lines[$i].Trim() -eq "parser.print_help()"){
    $inject = $i
    break
  }
}

# Extraire le bloc masterkey (jusqu'à retour indent < mkIndent)
$end = $lines.Count-1
for($i=$mk+1; $i -lt $lines.Count; $i++){
  if(-not [string]::IsNullOrWhiteSpace($lines[$i]) -and (LeadingSpaces $lines[$i]) -lt $mkIndent){
    $end = $i-1; break
  }
}

$block = $lines[$mk..$end]

# Supprimer l'ancien emplacement
$out = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  if($i -ge $mk -and $i -le $end){ continue }
  $out.Add($lines[$i])
}
$lines2 = $out.ToArray()

if($inject -gt 0){
  # Recalculer l'index d'injection sur le nouveau tableau
  $inj2 = -1
  for($i=$lines2.Count-1; $i -ge 0; $i--){
    if((LeadingSpaces $lines2[$i]) -eq ($mkIndent - 0) -and $lines2[$i].Trim() -eq "parser.print_help()"){
      $inj2 = $i
      break
    }
  }
  if($inj2 -gt 0){
    $out2 = New-Object System.Collections.Generic.List[string]
    for($i=0; $i -lt $lines2.Count; $i++){
      if($i -eq $inj2){
        foreach($b in $block){ $out2.Add($b) }
        $out2.Add("") 
      }
      $out2.Add($lines2[$i])
    }
    $lines2 = $out2.ToArray()
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines2, $utf8NoBom)

Write-Host "OK: v7 dispatch masterkey reachable (block moved and/or if->elif)."
