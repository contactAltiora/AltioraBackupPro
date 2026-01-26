$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Trouver le bloc "# masterkey" (argparse section)
$mk = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq "# masterkey"){ $mk = $i; break }
}
if($mk -lt 0){ throw "ERROR: '# masterkey' not found in altiora.py" }

# 2) Trouver une référence d'indentation juste avant (stats/list/verify)
$ref = -1
for($i=$mk; $i -ge 0; $i--){
  $t = $lines[$i].TrimStart()
  if($t.StartsWith('subparsers.add_parser("stats"') -or
     $t.StartsWith('subparsers.add_parser("list"')  -or
     $t.StartsWith('p_verify = subparsers.add_parser("verify"') -or
     $t.StartsWith('p_restore = subparsers.add_parser("restore"') -or
     $t.StartsWith('p_backup = subparsers.add_parser("backup"')){
    $ref = $i; break
  }
}
if($ref -lt 0){ throw "ERROR: could not find an argparse reference line to infer indentation" }

$targetIndent = LeadingSpaces $lines[$ref]
$pad = " " * $targetIndent

# 3) Déterminer fin du bloc masterkey : on s'arrête au premier marqueur "hors argparse"
$end = $lines.Count - 1
for($i=$mk+1; $i -lt $lines.Count; $i++){
  $t = $lines[$i].TrimStart()

  if($t -match '^(args\s*=\s*parser\.parse_args|if\s+args\.command|try:|except|return\b|def\s+|class\s+)'){
    $end = $i - 1
    break
  }

  # sécurité : si on retombe sur un autre bloc de commandes connu
  if($t.StartsWith('# Parse arguments') -or $t.StartsWith('# Dispatch') ){
    $end = $i - 1
    break
  }
}

# 4) Ré-indenter uniformément le bloc [mk..end] au niveau des autres add_parser
$changed = 0
for($i=$mk; $i -le $end; $i++){
  if([string]::IsNullOrWhiteSpace($lines[$i])){ continue }
  $lines[$i] = $pad + $lines[$i].TrimStart()
  $changed++
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: masterkey argparse indent normalized (lines $($mk+1)-$($end+1), changed=$changed, indent=$targetIndent)"
