$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Find masterkey dispatch start
$mkStart = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "masterkey":'){
    $mkStart = $i; break
  }
}
if($mkStart -lt 0){ throw "ERROR: masterkey dispatch not found" }

$mkIndent = LeadingSpaces $lines[$mkStart]

# 2) Find end of block: stop after we meet a sibling "parser.print_help()" at same indent or another 'if/elif args.command'
$mkEnd = -1
for($i=$mkStart+1; $i -lt $lines.Count; $i++){
  if([string]::IsNullOrWhiteSpace($lines[$i])){ continue }
  $sp = LeadingSpaces $lines[$i]
  $t  = $lines[$i].TrimStart()

  if($sp -le $mkIndent -and ($t -eq "parser.print_help()" -or $t -match '^(if|elif)\s+args\.command\s*==')){
    $mkEnd = $i-1
    break
  }
}
if($mkEnd -lt 0){ $mkEnd = [Math]::Min($lines.Count-1, $mkStart+80) }

# 3) Remove old masterkey block
$out = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  if($i -ge $mkStart -and $i -le $mkEnd){ continue }
  $out.Add($lines[$i])
}
$lines = $out.ToArray()

# 4) Find args = parser.parse_args() line (inject after it)
$parseIdx = -1
for($i=0; $i -lt $lines.Count; $i++){
  $t = $lines[$i].TrimStart()
  if($t -eq 'args = parser.parse_args()' -or $t -match '^args\s*=\s*parser\.parse_args\('){
    $parseIdx = $i; break
  }
}
if($parseIdx -lt 0){ throw "ERROR: cannot find args = parser.parse_args()" }

$baseIndent = LeadingSpaces $lines[$parseIdx]
$pad = " " * $baseIndent

# 5) Build clean masterkey block (correct indentation)
$blk = @(
  "",
  ($pad + 'if args.command == "masterkey":'),
  ($pad + '    try:'),
  ($pad + '        from src.master_key import MasterKeyManager, MasterKeyError'),
  ($pad + '    except Exception:'),
  ($pad + '        from master_key import MasterKeyManager, MasterKeyError  # type: ignore'),
  "",
  ($pad + '    mgr = MasterKeyManager()'),
  "",
  ($pad + '    if getattr(args, "mk_command", None) == "status":'),
  ($pad + '        print("OK" if mgr.exists() else "NOT_INITIALIZED")'),
  ($pad + '        return 0'),
  "",
  ($pad + '    if args.mk_command == "init":'),
  ($pad + '        try:'),
  ($pad + '            p = mgr.init(args.password)'),
  ($pad + '            print(str(p))'),
  ($pad + '            return 0'),
  ($pad + '        except MasterKeyError as e:'),
  ($pad + '            print(f"ERROR: {e}")'),
  ($pad + '            return 2'),
  "",
  ($pad + '    if args.mk_command == "rotate":'),
  ($pad + '        try:'),
  ($pad + '            mgr.rotate(args.old, args.new)'),
  ($pad + '            print("OK")'),
  ($pad + '            return 0'),
  ($pad + '        except MasterKeyError as e:'),
  ($pad + '            print(f"ERROR: {e}")'),
  ($pad + '            return 2'),
  "",
  ($pad + '    parser.print_help()'),
  ($pad + '    return 2'),
  ""
)

# 6) Inject block after parse_args
$out2 = New-Object System.Collections.Generic.List[string]
for($i=0; $i -lt $lines.Count; $i++){
  $out2.Add($lines[$i])
  if($i -eq $parseIdx){
    foreach($b in $blk){ $out2.Add($b) }
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $out2.ToArray(), $utf8NoBom)

Write-Host "OK: masterkey dispatch rebuilt (old block removed lines $($mkStart+1)-$($mkEnd+1), reinjected after parse_args line $($parseIdx+1))."
