$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

$fixed = 0
for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  if([string]::IsNullOrWhiteSpace($ln)){ continue }

  $n = LeadingSpaces $ln
  if($n -gt 0){
    $mod = $n % 4
    if($mod -ne 0){
      $add = 4 - $mod
      $lines[$i] = (" " * $add) + $ln
      $fixed++
    }
  }
}

Set-Content -Path $path -Value $lines -Encoding UTF8
Write-Host "OK: indents corrigés vers multiple de 4 (lignes modifiées: $fixed)"
