$path  = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq ' '){ $n++ }
  return $n
}

function IsBlank([string]$s){ return [string]::IsNullOrWhiteSpace($s) }

# Block openers we want to protect
function IsBlockOpenerLine([string]$trim){
  # must end with ":" and have nothing after ":" (avoid one-liners like "if x: return 0")
  if(-not $trim.EndsWith(":")){ return $false }
  if($trim -match ':\s*\S'){ return $false }

  # keywords
  if($trim -match '^(if|elif|else|for|while|try|except|finally|with)\b'){ return $true }
  if($trim -match '^def\s+\w+\s*\(.*\)\s*:\s*$'){ return $true }
  if($trim -match '^class\s+\w+(\(.*\))?\s*:\s*$'){ return $true }
  return $false
}

# Build new file with inserted pass where needed
$out = New-Object System.Collections.Generic.List[string]
$inserted = 0

for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  $out.Add($ln)

  $trim = $ln.TrimStart()
  if(-not (IsBlockOpenerLine $trim)){ continue }

  $curIndent = LeadingSpaces $ln
  $needIndent = $curIndent + 4

  # Find next non-blank line (without consuming it)
  $k = $i + 1
  while($k -lt $lines.Count -and (IsBlank $lines[$k])){ $k++ }

  if($k -ge $lines.Count){
    # EOF => block is empty
    $out.Add((" " * $needIndent) + "pass")
    $inserted++
    continue
  }

  $nextIndent = LeadingSpaces $lines[$k]

  # If next significant line is not more indented, then current block has no body
  if($nextIndent -le $curIndent){
    $out.Add((" " * $needIndent) + "pass")
    $inserted++
  }
}

Set-Content -Path $path -Value $out.ToArray() -Encoding UTF8
Write-Host "OK: autopass appliqué (pass ajoutés: $inserted)"
