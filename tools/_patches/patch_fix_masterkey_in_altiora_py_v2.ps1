$path = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# 1) Trouver bloc 'if args.command == "masterkey":' (mal injecté) et le supprimer
$start = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "masterkey":'){
    $start = $i
    break
  }
}

if($start -ge 0){
  $baseIndent = LeadingSpaces $lines[$start]
  $end = $lines.Count - 1

  for($j=$start+1; $j -lt $lines.Count; $j++){
    $ln = $lines[$j]
    if([string]::IsNullOrWhiteSpace($ln)){ continue }
    $ind = LeadingSpaces $ln

    # fin de bloc: on sort dès qu'on revient à indent <= baseIndent
    if($ind -le $baseIndent){
      $end = $j - 1
      break
    }
  }

  $out = New-Object System.Collections.Generic.List[string]
  for($k=0; $k -lt $lines.Count; $k++){
    if($k -ge $start -and $k -le $end){ continue }
    $out.Add($lines[$k])
  }
  $lines = $out.ToArray()
}

# 2) Ré-injecter la commande masterkey dans la création des subparsers (indent = 4 espaces typiquement)
# On injecte juste après la ligne contenant: subparsers = parser.add_subparsers(
$inject1 = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match 'subparsers\s*=\s*parser\.add_subparsers'){
    $inject1 = $i
    break
  }
}
if($inject1 -lt 0){ throw "ERROR: cannot find subparsers = parser.add_subparsers in altiora.py" }

# Eviter double-injection
$already = $false
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i] -match 'add_parser\("masterkey"'){ $already = $true; break }
}

if(-not $already){
  $ind = LeadingSpaces $lines[$inject1]
  $pad = (" " * $ind)

  $block = @(
    "$pad" + '# masterkey',
    "$pad" + 'p_mk = subparsers.add_parser("masterkey", help="Gerer la Master Key")',
    "$pad" + 'mk_sub = p_mk.add_subparsers(dest="mk_command", help="Actions Master Key")',
    "$pad" + '',
    "$pad" + 'mk_sub.add_parser("status", help="Verifier si la Master Key est initialisee")',
    "$pad" + 'mk_init = mk_sub.add_parser("init", help="Initialiser la Master Key (creer master_key.json)")',
    "$pad" + 'mk_init.add_argument("-p", "--password", required=True, help="Mot de passe Master Key")',
    "$pad" + '',
    "$pad" + 'mk_rot = mk_sub.add_parser("rotate", help="Changer le mot de passe (re-chiffre la master key)")',
    "$pad" + 'mk_rot.add_argument("--old", required=True, help="Ancien mot de passe")',
    "$pad" + 'mk_rot.add_argument("--new", required=True, help="Nouveau mot de passe")',
    "$pad" + ''
  )

  $out = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    $out.Add($lines[$i])
    if($i -eq $inject1){
      foreach($b in $block){ $out.Add($b) }
    }
  }
  $lines = $out.ToArray()
}

# 3) Injecter le dispatch masterkey au BON niveau: on repère un dispatch existant, ex: if args.command == "backup":
# puis on injecte juste APRES le bloc backup/restore/verify (avant list/stats ou fallback).
# Méthode robuste: trouver la première occurrence de 'if args.command == "backup":' et prendre son indent comme référence.
$ref = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "backup":'){
    $ref = $i
    break
  }
}
if($ref -lt 0){ throw 'ERROR: cannot find reference dispatch: if args.command == "backup":' }

$refIndent = LeadingSpaces $lines[$ref]
$padRef = (" " * $refIndent)

# trouver un point d'insertion: juste avant le bloc 'if args.command == "list":' si présent, sinon avant 'parser.print_help()'
$inject2 = -1
for($i=0; $i -lt $lines.Count; $i++){
  if($lines[$i].TrimStart() -eq 'if args.command == "list":'){
    $inject2 = $i
    break
  }
}
if($inject2 -lt 0){
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i].TrimStart() -match '^parser\.print_help\(\)'){
      $inject2 = $i
      break
    }
  }
}
if($inject2 -lt 0){ throw "ERROR: cannot find injection point for masterkey dispatch" }

# éviter double dispatch
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
    if($i -eq $inject2){
      foreach($b in $blk){ $out.Add($b) }
    }
    $out.Add($lines[$i])
  }
  $lines = $out.ToArray()
}

# 4) Write back UTF-8 no BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: masterkey repare (remove bad block + reinject correct)."
