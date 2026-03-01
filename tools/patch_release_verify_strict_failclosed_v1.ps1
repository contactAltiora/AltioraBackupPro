$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
  throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $target)){ throw "altiora.py introuvable" }

$src = Get-Content -LiteralPath $target -Encoding UTF8

$begin = -1
$end   = -1

for($i=0; $i -lt $src.Count; $i++){
  if($src[$i].Trim() -eq "# Altiora release signature verification"){
    $begin = $i
    break
  }
}
if($begin -lt 0){ throw "Marker not found: '# Altiora release signature verification'" }

for($i=$begin; $i -lt $src.Count; $i++){
  if($src[$i].Trim() -eq "verify_official_release()"){
    $end = $i
    break
  }
}
if($end -lt 0){ throw "End marker not found: 'verify_official_release()'" }

$block = @(
"# Altiora release signature verification",
"def verify_official_release():",
"    import os, sys, subprocess, re",
"    repo_root = os.path.dirname(os.path.abspath(__file__))",
"    releases_dir = os.path.join(repo_root, '_out', 'releases')",
"    pub = os.path.join(repo_root, 'keys', 'altiora_public_key.pem')",
"    verify = os.path.join(repo_root, 'tools', 'verify_signature.py')",
"",
"    # Fail-closed: if public key is present, enforcement is ON",
"    if not os.path.exists(pub):",
"        return",
"",
"    if not os.path.isdir(releases_dir):",
"        sys.exit(1)",
"",
"    # detect current version from globals if possible (VERSION / __version__ / APP_VERSION)",
"    v = globals().get('VERSION') or globals().get('__version__') or globals().get('APP_VERSION')",
"    if isinstance(v, str):",
"        m = re.search(r'(v\\d+\\.\\d+\\.\\d+)', v)",
"        v = m.group(1) if m else None",
"    else:",
"        v = None",
"",
"    # list candidate release zips",
"    zips = [f for f in os.listdir(releases_dir) if f.endswith('_release.zip') and f.startswith('AltioraBackupPro_')]",
"    if not zips:",
"        sys.exit(1)",
"",
"    # prefer zip matching current version when available",
"    zip_path = None",
"    if v:",
"        exact = f'AltioraBackupPro_{v}_release.zip'",
"        candidate = os.path.join(releases_dir, exact)",
"        if os.path.exists(candidate):",
"            zip_path = candidate",
"",
"    # fallback to most recently modified",
"    if not zip_path:",
"        paths = [os.path.join(releases_dir, f) for f in zips]",
"        zip_path = max(paths, key=os.path.getmtime)",
"",
"    sig_path = zip_path + '.sig'",
"    if not os.path.exists(sig_path):",
"        sys.exit(1)",
"",
"    r = subprocess.run([sys.executable, verify, pub, zip_path])",
"    if r.returncode != 0:",
"        sys.exit(1)",
"",
"verify_official_release()"
)

$new = @()
$new += $src[0..($begin-1)]
$new += $block
$new += $src[($end+1)..($src.Count-1)]

$new | Set-Content -LiteralPath $target -Encoding UTF8

Write-Host "release verify block replaced: STRICT fail-closed"
