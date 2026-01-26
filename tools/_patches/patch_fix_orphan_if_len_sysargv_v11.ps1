$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}
function IsBlank([string]$s){
  return [string]::IsNullOrWhiteSpace($s)
}

# 1) Locate: if len(sys.argv) == 1:
$idx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].Trim() -eq 'if len(sys.argv) == 1:'){
    $idx = $i; break
  }
}
if($idx -lt 0){ throw "ERROR: cannot find 'if len(sys.argv) == 1:'" }

$baseIndent = LeadingSpaces $lines[$idx]
$suiteIndent = $baseIndent + 4
$padSuite = " " * $suiteIndent

# 2) Find next non-blank line after idx
$j = $idx + 1
while($j -lt $lines.Count -and IsBlank $lines[$j]){ $j++ }
if($j -ge $lines.Count){ throw "ERROR: file ends after orphan if" }

$nextIndent = LeadingSpaces $lines[$j]

# 3) If next line is NOT indented deeper => insert suite
if($nextIndent -le $baseIndent){
  $insert = @(
    ($padSuite + 'parser.print_help()'),
    ($padSuite + 'return 0'),
    ''
  )

  $out = New-Object System.Collections.Generic.List[string]
  for($k=0; $k -lt $lines.Count; $k++){
    $out.Add($lines[$k])
    if($k -eq $idx){
      foreach($x in $insert){ $out.Add($x) }
    }
  }
  $lines = $out.ToArray()
  $changed = 1
} else {
  $changed = 0
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: orphan if len(sys.argv)==1 fixed (changed=$changed) at line $($idx+1)."
