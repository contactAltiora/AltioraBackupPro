$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Find the masterkey IF line
$mk = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^\s*if\s+args\.command\s*==\s*"masterkey"\s*:\s*$'){
    $mk = $i; break
  }
}
if($mk -lt 0){ throw "ERROR: cannot find: if args.command == ""masterkey"": (single-line)" }

$baseIndent = LeadingSpaces $lines[$mk]
$suiteIndent = $baseIndent + 4

# 2) Indent the suite until next sibling dispatch / fallback at same base indent
$changed = 0
for($i=$mk+1; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $sp = LeadingSpaces $ln
  $t  = $ln.TrimStart()

  # stop conditions: next dispatch sibling at same indent
  if($sp -le $baseIndent -and ($t -match '^(if|elif)\s+args\.command\s*==' -or $t -eq 'parser.print_help()')){
    break
  }

  # If line is at baseIndent (or less), push it under the if-suite
  if($sp -le $baseIndent){
    $lines[$i] = (" " * $suiteIndent) + $t
    $changed++
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: masterkey suite re-indented (changed=$changed) around line $($mk+1)."
