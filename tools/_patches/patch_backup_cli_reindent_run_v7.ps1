$path = "C:\Dev\AltioraBackupPro\src\backup_cli.py"
$lines = Get-Content $path -Encoding UTF8

function IsCommentOrEmpty([string]$s){
  return [string]::IsNullOrWhiteSpace($s) -or $s.TrimStart().StartsWith("#")
}

# Find def run(self):
$run = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].Trim() -eq "def run(self):"){ $run = $i; break }
}
if($run -lt 0){ throw "ERROR: def run(self): not found" }

# Find end of run(): next line that starts at indent 4 with 'def ' OR 'class ' (same class scope)
$runIndent = 4
$end = $lines.Count - 1
for($i=$run+1; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^[ ]{4}(def|class)\b'){
    $end = $i - 1
    break
  }
}

# Reindent region (run body) using simple block rules
$out = @()
$out += $lines[0..$run]  # include def run line unchanged

$level = 1  # inside run()
$inTriple = $false
$tripleDelim = ""

for($i=$run+1; $i -le $end; $i++){
  $raw = $lines[$i]
  $t = $raw.TrimStart()

  # Preserve triple-quoted docstrings blocks as-is but normalize leading indent
  if(-not $inTriple){
    if($t -match "^(\"\"\"|''')"){
      $inTriple = $true
      $tripleDelim = $Matches[1]
      $out += (" " * ($runIndent + 4*$level)) + $t
      continue
    }
  } else {
    # inside triple quote
    $out += (" " * ($runIndent + 4*$level)) + $t
    if($t.Contains($tripleDelim) -and $t.Length -gt 3){
      $inTriple = $false
      $tripleDelim = ""
    }
    continue
  }

  if(IsCommentOrEmpty($raw)){
    $out += ""  # normalize empty/comment lines to empty (avoid weird spaces)
    continue
  }

  # Dedent keywords
  if($t -match '^(elif|else|except|finally)\b'){
    if($level -gt 1){ $level-- }
  }

  # Apply indent for current line
  $out += (" " * ($runIndent + 4*$level)) + $t

  # Increase indent after block openers ending with :
  # Avoid increasing for one-liners like: "if x: return 0"
  if($t.EndsWith(":") -and ($t -notmatch ':\s*\S')){
    $level++
  }

  # Dedent on explicit return/break/continue/pass? -> no, Python doesn't dedent automatically; leave.
}

# Append remainder
if($end+1 -le $lines.Count-1){
  $out += $lines[($end+1)..($lines.Count-1)]
}

Set-Content -Path $path -Value $out -Encoding UTF8
Write-Host "OK: run() ré-indenté (lignes $($run+1)-$($end+1))"
