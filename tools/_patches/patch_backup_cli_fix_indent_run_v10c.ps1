$path  = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Locate def run(self):
$run = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].Trim() -eq "def run(self):"){ $run = $i; break }
}
if($run -lt 0){ throw "ERROR: def run(self): not found" }

# 2) Locate def main(): (top-level) to determine end of run()
$main = -1
for($i=$run+1; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith("def main():")){
    $main = $i
    break
  }
}
if($main -lt 0){ throw "ERROR: def main(): not found (needed to bound run())" }

# 3) Force def main() and if __name__ to indent 0 (strip any leading spaces)
for($i=$main; $i -lt $lines.Count; $i++){
  $t = $lines[$i].TrimStart()
  if($t.StartsWith("def main():") -or $t.StartsWith('if __name__ == "__main__":')){
    $lines[$i] = $t
  }
}

# 4) Normalize indentation inside run(): lines (run+1 .. main-1)
# Rules:
# - non-empty lines must have at least 8 spaces
# - indentation must be a multiple of 4 (pad upward)
$minIndent = 8
$changed = 0

for($i=$run+1; $i -le ($main-1); $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $sp = LeadingSpaces $ln

  # Ensure minimum indent
  if($sp -lt $minIndent){
    $add = $minIndent - $sp
    $lines[$i] = (" " * $add) + $ln
    $sp = $minIndent
    $changed++
  }

  # Ensure multiple of 4
  $mod = $sp % 4
  if($mod -ne 0){
    $add = 4 - $mod
    $lines[$i] = (" " * $add) + $lines[$i]
    $changed++
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: indentation normalisée dans run() (modifs: $changed) ; run=$($run+1)-$($main) ; main line=$($main+1)"
