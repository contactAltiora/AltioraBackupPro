$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# ------------------------------------------------------------
# 1) Extraire le bloc masterkey existant (celui qui commence par if args.command == "masterkey":)
# ------------------------------------------------------------
$mkStart = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^\s*if\s+args\.command\s*==\s*"masterkey"\s*:'){
    $mkStart = $i; break
  }
}
if($mkStart -lt 0){ throw "ERROR: masterkey block not found" }

$mkIndent = LeadingSpaces $lines[$mkStart]

$mkEnd = $lines.Count - 1
for($i=$mkStart+1; $i -lt $lines.Count; $i++){
  if(-not [string]::IsNullOrWhiteSpace($lines[$i]) -and (LeadingSpaces $lines[$i]) -lt $mkIndent){
    $mkEnd = $i-1; break
  }
}

$mkBlock = $lines[$mkStart..$mkEnd]

# ------------------------------------------------------------
# 2) Supprimer ce bloc de son emplacement actuel
# ------------------------------------------------------------
$out = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  if($i -ge $mkStart -and $i -le $mkEnd){ continue }
  $out.Add($lines[$i])
}
$lines = $out.ToArray()

# ------------------------------------------------------------
# 3) Trouver la ligne "args = parser.parse_args()" (ou "args = parser.parse_args(") et injecter juste APRES
# ------------------------------------------------------------
$parseIdx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -match '^args\s*=\s*parser\.parse_args\(' -or $lines[$i].TrimStart() -eq 'args = parser.parse_args()'){
    $parseIdx = $i; break
  }
}
if($parseIdx -lt 0){ throw "ERROR: cannot find args = parser.parse_args() line" }

$parseIndent = LeadingSpaces $lines[$parseIdx]
$pad = " " * $parseIndent

# On réindente le bloc masterkey au même niveau que les autres dispatch (même indent que args=... ou juste après parse)
$fixedBlock = @()
foreach($ln in $mkBlock){
  if([string]::IsNullOrWhiteSpace($ln)){
    $fixedBlock += $ln
  } else {
    $fixedBlock += ($pad + $ln.TrimStart())
  }
}

$out2 = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  $out2.Add($lines[$i])
  if($i -eq $parseIdx){
    $out2.Add("") 
    foreach($b in $fixedBlock){ $out2.Add($b) }
    $out2.Add("")
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $out2.ToArray(), $utf8NoBom)

Write-Host "OK: masterkey dispatch moved after parse_args (block $($mkStart+1)-$($mkEnd+1) -> after line $($parseIdx+1))."
