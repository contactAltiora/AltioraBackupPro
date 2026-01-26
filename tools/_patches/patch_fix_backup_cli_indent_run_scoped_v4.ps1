$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function CountSpacesPrefix([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

# 1) trouver "def run(self):"
$run = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq "def run(self):"){
    $run = $i; break
  }
}
if($run -lt 0){ throw "ERROR: def run(self): not found" }

# 2) trouver la ligne "parser = argparse.ArgumentParser(" après run()
$parserLine = -1
for($i=$run; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith("parser = argparse.ArgumentParser(")){
    $parserLine = $i; break
  }
}
if($parserLine -lt 0){ throw "ERROR: parser = argparse.ArgumentParser( not found" }

$indentRun = CountSpacesPrefix($lines[$parserLine])
$pad = (" " * $indentRun)

# 3) trouver le premier "parser.add_argument(" au niveau 0 (bug)
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].StartsWith("parser.add_argument(")){
    $start = $i; break
  }
}
if($start -lt 0){ throw "ERROR: top-level parser.add_argument( not found" }

# 4) fin du bloc: avant "if __name__" (au niveau 0) ou EOF
$end = $lines.Count - 1
for($i=$start; $i -lt $lines.Count; $i++){
  if($lines[$i].StartsWith("if __name__")){
    $end = $i - 1; break
  }
}

# 5) appliquer: ajouter $pad devant TOUTES les lignes du bloc (sauf vides)
# MAIS on conserve l'indent interne : on préfixe simplement (donc if-body reste plus profond)
for($i=$start; $i -le $end; $i++){
  if([string]::IsNullOrWhiteSpace($lines[$i])){ continue }
  $lines[$i] = $pad + $lines[$i]
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: bloc déplacé dans run() avec indent=$indentRun (lignes $($start+1)-$($end+1))"
