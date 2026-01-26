$path  = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

function IsBlankOrComment([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return $true }
  return $s.TrimStart().StartsWith("#")
}

# Locate def run(self):
$run = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].Trim() -eq "def run(self):"){ $run = $i; break }
}
if($run -lt 0){ throw "ERROR: def run(self): not found" }

# Locate def main():
$main = -1
for($i=$run+1; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart().StartsWith("def main():")){
    $main = $i; break
  }
}
if($main -lt 0){ throw "ERROR: def main(): not found" }

# Block openers that require an indented suite (line ends with :)
# (we keep it simple: if line ends with ":" and starts with one of these keywords)
$kw = @("if","elif","else","for","while","try","except","finally","with","def","class")

$out = New-Object System.Collections.Generic.List[string]
$inserted = 0

for($i=0; $i -lt $lines.Count; $i++){
  $out.Add($lines[$i])

  # only operate inside run() body
  if($i -le $run -or $i -ge ($main-1)){ continue }

  $cur = $lines[$i]
  if([string]::IsNullOrWhiteSpace($cur)){ continue }

  $trim = $cur.TrimStart()
  $curIndent = LeadingSpaces $cur

  # must end with ":" (block opener)
  if(-not $trim.EndsWith(":")){ continue }

  # must start with a known opener keyword
  $isOpener = $false
  foreach($k in $kw){
    if($trim -match ("^" + [regex]::Escape($k) + "\b")){ $isOpener = $true; break }
  }
  if(-not $isOpener){ continue }

  # find next significant line
  $j = $i + 1
  while($j -lt $lines.Count -and IsBlankOrComment($lines[$j])){ $j++ }
  if($j -ge $lines.Count){
    $out.Add((" " * ($curIndent + 4)) + "pass")
    $inserted++
    continue
  }

  $nextIndent = LeadingSpaces $lines[$j]
  if($nextIndent -le $curIndent){
    $out.Add((" " * ($curIndent + 4)) + "pass")
    $inserted++
  }
}

Set-Content -Path $path -Value $out.ToArray() -Encoding UTF8
Write-Host "OK: autopass run() appliqué (pass ajoutés: $inserted)"
