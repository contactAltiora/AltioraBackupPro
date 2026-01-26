$path  = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# Find def run(self):
$run = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].Trim() -eq "def run(self):"){ $run = $i; break }
}
if($run -lt 0){ throw "ERROR: def run(self): not found" }

# Find end of run(): next "def " at indent 4 OR EOF
$end = $lines.Count - 1
for($i=$run+1; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^[ ]{4}def\b'){
    $end = $i - 1
    break
  }
}

$pad = "        "  # 8 spaces
$changed = 0
$changedLines = New-Object System.Collections.Generic.List[string]

for($i=$run+1; $i -le $end; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  if((LeadingSpaces $ln) -eq 0){
    $lines[$i] = $pad + $ln
    $changed++
    $changedLines.Add(("line {0}: {1}" -f ($i+1), $ln.Trim()))
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: run() dedent corrigé (lignes indentées: $changed) ; bloc run=$($run+1)-$($end+1)"
if($changed -gt 0){
  Write-Host "---- lignes corrigées ----"
  $changedLines | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
  if($changedLines.Count -gt 20){ Write-Host "... ($($changedLines.Count-20) autres)" }
}
