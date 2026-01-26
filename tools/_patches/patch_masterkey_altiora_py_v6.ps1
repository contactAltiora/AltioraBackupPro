$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

function LeadingSpaces([string]$s){
  $n=0
  while($n -lt $s.Length -and $s[$n] -eq " "){ $n++ }
  return $n
}

# ------------------------------------------------------------
# A) PURGE bloc orphelin "Import local..." (indent unexpected)
# ------------------------------------------------------------
$removed = 0
$out = New-Object System.Collections.Generic.List[string]

$inOrphan = $false
$orphanIndent = 0

for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]
  $t  = $ln.TrimStart()
  $sp = LeadingSpaces $ln

  # Déclencheur : le commentaire exact que tu as en ligne 522
  if(-not $inOrphan -and $t -eq "# Import local pour eviter de charger si non utilise"){
    $inOrphan = $true
    $orphanIndent = $sp
    $removed++
    continue
  }

  if($inOrphan){
    # on sort du bloc orphelin dès qu'on remonte à un indent strictement inférieur
    if(-not [string]::IsNullOrWhiteSpace($ln) -and $sp -lt $orphanIndent){
      $inOrphan = $false
      # on retombe sur une ligne "régulière" => on la garde
      $out.Add($ln)
    } else {
      $removed++
    }
    continue
  }

  $out.Add($ln)
}

$lines = $out.ToArray()

# ------------------------------------------------------------
# B) AJOUT argparse: subparser "masterkey" (si absent)
# ------------------------------------------------------------
$txtJoined = ($lines -join "`n")
if($txtJoined -notmatch 'add_parser\("masterkey"'){
  # trouver une ligne "subparsers = parser.add_subparsers("
  $spIdx = -1
  for($i=0; $i -lt $lines.Count; $i++){
    if($lines[$i].TrimStart() -match '^subparsers\s*=\s*parser\.add_subparsers\('){
      $spIdx = $i; break
    }
  }
  if($spIdx -lt 0){ throw "ERROR: cannot find subparsers = parser.add_subparsers(...)" }

  $baseIndent = LeadingSpaces $lines[$spIdx]
  $pad = " " * $baseIndent

  $insert = @(
    "",
    ($pad + "# masterkey"),
    ($pad + 'p_mk = subparsers.add_parser("masterkey", help="Gerer la Master Key")'),
    ($pad + 'mk_sub = p_mk.add_subparsers(dest="mk_command", help="Actions Master Key")'),
    "",
    ($pad + 'mk_sub.add_parser("status", help="Verifier si la Master Key est initialisee")'),
    ($pad + 'mk_init = mk_sub.add_parser("init", help="Initialiser la Master Key (creer master_key.json)")'),
    ($pad + 'mk_init.add_argument("-p", "--password", required=True, help="Mot de passe Master Key")'),
    "",
    ($pad + 'mk_rot = mk_sub.add_parser("rotate", help="Changer le mot de passe (re-chiffre la master key)")'),
    ($pad + 'mk_rot.add_argument("--old", required=True, help="Ancien mot de passe")'),
    ($pad + 'mk_rot.add_argument("--new", required=True, help="Nouveau mot de passe")'),
    ""
  )

  $out2 = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    $out2.Add($lines[$i])
    if($i -eq $spIdx){
      foreach($x in $insert){ $out2.Add($x) }
    }
  }
  $lines = $out2.ToArray()
}

# ------------------------------------------------------------
# C) AJOUT dispatch masterkey (si absent)
# ------------------------------------------------------------
$txtJoined = ($lines -join "`n")
if($txtJoined -notmatch 'if\s+args\.command\s*==\s*"masterkey"\s*:'){
  # On cherche un point d'injection : juste avant le fallback final "parser.print_help()"
  # (on prend le dernier parser.print_help() du fichier, dans le handler CLI)
  $inject = -1
  for($i=$lines.Count-1; $i -ge 0; $i--){
    if($lines[$i].Trim() -eq "parser.print_help()"){
      $inject = $i
      break
    }
  }
  if($inject -lt 0){ throw "ERROR: cannot find parser.print_help() injection point" }

  # indentation de la zone (ligne parser.print_help())
  $refIndent = LeadingSpaces $lines[$inject]
  $pad = " " * $refIndent

  $blk = @(
    "",
    ($pad + 'if args.command == "masterkey":'),
    ($pad + '    # Import local pour eviter de charger si non utilise'),
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

  $out3 = New-Object System.Collections.Generic.List[string]
  for($i=0; $i -lt $lines.Count; $i++){
    if($i -eq $inject){
      foreach($x in $blk){ $out3.Add($x) }
    }
    $out3.Add($lines[$i])
  }
  $lines = $out3.ToArray()
}

# Write back (UTF-8 no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $lines, $utf8NoBom)

Write-Host "OK: v6 applied (orphan_removed=$removed)."
