$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Remove any existing masterkey dispatch (even if collapsed into one line)
# We remove from the line containing `if args.command == "masterkey":` until we hit a sibling dispatch
# or a parser.print_help() fallback at the same indent, or until blank line boundary after it.
$idx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match '^\s*if\s+args\.command\s*==\s*"masterkey"\s*:'){
    $idx = $i; break
  }
}

if($idx -ge 0){
  $baseIndent = LeadingSpaces $lines[$idx]
  $end = $lines.Count - 1

  for($j=$idx+1; $j -lt $lines.Count; $j++){
    $ln = $lines[$j]
    if([string]::IsNullOrWhiteSpace($ln)){ 
      # allow one blank, but if we already passed some content, stop at first blank
      $end = $j
      break
    }
    $ind = LeadingSpaces $ln
    $trim = $ln.TrimStart()

    # stop when we hit a sibling dispatch / fallback at same indent
    if($ind -le $baseIndent -and $j -gt $idx){
      $end = $j - 1
      break
    }
    if($ind -eq $baseIndent -and ($trim -match '^(if\s+args\.command\s*==|parser\.print_help\(\))')){
      $end = $j - 1
      break
    }
  }

  $out = New-Object System.Collections.Generic.List[string]
  for($k=0; $k -lt $lines.Count; $k++){
    if($k -ge $idx -and $k -le $end){ continue }
    $out.Add($lines[$k])
  }
  $lines = $out.ToArray()
}

# 2) Ensure masterkey subparser exists (inject after subparsers = parser.add_subparsers)
$subIdx = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match 'subparsers\s*=\s*parser\.add_subparsers'){
    $subIdx = $i; break
  }
}
if($subIdx -lt 0){ throw "ERROR: cannot find subparsers = parser.add_subparsers(...)" }

$hasSub = $false
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match 'add_parser\("masterkey"'){ $hasSub = $true; break }
}

if(-not $hasSub){
  $ind = LeadingSpaces $lines[$subIdx]
  $pad = (" " * $ind)

  $block = @(
    "$pad# masterkey",
    "$pad" + 'p_mk = subparsers.add_parser("masterkey", help="Gerer la Master Key")',
    "$pad" + 'mk_sub = p_mk.add_subparsers(dest="mk_command", help="Actions Master Key")',
    "$pad",
    "$pad" + 'mk_sub.add_parser("status", help="Verifier si la Master Key est initialisee")',
    "$pad" + 'mk_init = mk_sub.add_parser("init", help="Initialiser la Master Key (creer master_key.json)")',
    "$pad" + 'mk_init.add_argument("-p", "--password", required=True, help="Mot de passe Master Key")',
    "$pad",
    "$pad" + 'mk_rot = mk_sub.add_parser("rotate", help="Changer le mot de passe (re-chiffre la master key)")',
    "$pad" + 'mk_rot.add_argument("--old", required=True, help="Ancien mot de passe")',
    "$pad" + 'mk_rot.add_argument("--new", required=True, help="Nouveau mot de passe")',
    "$pad"
  )

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    $out.Add($lines[$i])
    if($i -eq $subIdx){
      foreach($b in $block){ $out.Add($b) }
    }
  }
  $lines = $out.ToArray()
}

# 3) Inject dispatch block at correct indent, before list dispatch if possible
$ref = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "backup":'){ $ref = $i; break }
}
if($ref -lt 0){ throw 'ERROR: cannot find reference dispatch if args.command == "backup":' }

$refIndent = LeadingSpaces $lines[$ref]
$padRef = (" " * $refIndent)

$ins = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "list":'){ $ins = $i; break }
}
if($ins -lt 0){
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i].TrimStart() -match '^parser\.print_help\(\)'){ $ins = $i; break }
  }
}
if($ins -lt 0){ throw "ERROR: cannot find insertion point (list or parser.print_help)" }

# prevent duplicates
$hasDispatch = $false
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "masterkey":'){ $hasDispatch = $true; break }
}

if(-not $hasDispatch){
  $blk = @(
    "$padRef" + 'if args.command == "masterkey":',
    "$padRef" + '    from src.master_key import MasterKeyManager, MasterKeyError',
    "$padRef" + '    mgr = MasterKeyManager()',
    "$padRef" + '',
    "$padRef" + '    if getattr(args, "mk_command", None) == "status":',
    "$padRef" + '        print("OK" if mgr.exists() else "NOT_INITIALIZED")',
    "$padRef" + '        return 0',
    "$padRef" + '',
    "$padRef" + '    if args.mk_command == "init":',
    "$padRef" + '        try:',
    "$padRef" + '            p = mgr.init(args.password)',
    "$padRef" + '            print(str(p))',
    "$padRef" + '            return 0',
    "$padRef" + '        except MasterKeyError as e:',
    "$padRef" + '            print(f"ERROR: {e}")',
    "$padRef" + '            return 2',
    "$padRef" + '',
    "$padRef" + '    if args.mk_command == "rotate":',
    "$padRef" + '        try:',
    "$padRef" + '            mgr.rotate(args.old, args.new)',
    "$padRef" + '            print("OK")',
    "$padRef" + '            return 0',
    "$padRef" + '        except MasterKeyError as e:',
    "$padRef" + '            print(f"ERROR: {e}")',
    "$padRef" + '            return 2',
    "$padRef" + '',
    "$padRef" + '    parser.print_help()',
    "$padRef" + '    return 2',
    "$padRef" + ''
  )

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    if($i -eq $ins){
      foreach($b in $blk){ $out.Add($b) }
    }
    $out.Add($lines[$i])
  }
  $lines = $out.ToArray()
}

# 4) Write back UTF-8 no BOM, true lines
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: masterkey fixed v3 (no one-liner)."
