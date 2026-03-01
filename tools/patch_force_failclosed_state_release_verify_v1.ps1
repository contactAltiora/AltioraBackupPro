$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $target)){ throw "altiora.py introuvable" }

$src = Get-Content -LiteralPath $target -Encoding UTF8

$out = New-Object System.Collections.Generic.List[string]

$inside = $false
$replaced = $false

foreach($line in $src){

  if($line -match '^def verify_official_release\(\)\s*:'){
    $inside = $true
    $replaced = $true

    $out.Add("# Altiora release signature verification (STRICT fail-closed; STATE.md source of truth)")
    $out.Add("def verify_official_release():")
    $out.Add("    import os, sys, subprocess, re")
    $out.Add("    repo_root = os.path.dirname(os.path.abspath(__file__))")
    $out.Add("    releases_dir = os.path.join(repo_root, '_out', 'releases')")
    $out.Add("    pub = os.path.join(repo_root, 'keys', 'altiora_public_key.pem')")
    $out.Add("    verify = os.path.join(repo_root, 'tools', 'verify_signature.py')")
    $out.Add("    state_path = os.path.join(repo_root, 'STATE.md')")
    $out.Add("")
    $out.Add("    # Enforcement ON only if public key exists")
    $out.Add("    if not os.path.exists(pub):")
    $out.Add("        return")
    $out.Add("")
    $out.Add("    if not os.path.isdir(releases_dir):")
    $out.Add("        sys.exit(1)")
    $out.Add("")
    $out.Add("    if not os.path.exists(state_path):")
    $out.Add("        sys.exit(1)")
    $out.Add("")
    $out.Add("    txt = open(state_path, 'r', encoding='utf-8', errors='ignore').read()")
    $out.Add("    m = re.search(r'\\bv\\d+\\.\\d+\\.\\d+\\b', txt)")
    $out.Add("    if not m:")
    $out.Add("        sys.exit(1)")
    $out.Add("    v = m.group(0)")
    $out.Add("")
    $out.Add("    zip_name = f'AltioraBackupPro_{v}_release.zip'")
    $out.Add("    zip_path = os.path.join(releases_dir, zip_name)")
    $out.Add("    if not os.path.exists(zip_path):")
    $out.Add("        sys.exit(1)")
    $out.Add("")
    $out.Add("    sig_path = zip_path + '.sig'")
    $out.Add("    if not os.path.exists(sig_path):")
    $out.Add("        sys.exit(1)")
    $out.Add("")
    $out.Add("    r = subprocess.run([sys.executable, verify, pub, zip_path])")
    $out.Add("    if r.returncode != 0:")
    $out.Add("        sys.exit(1)")
    $out.Add("")
    continue
  }

  if($inside){
    # stop skipping when next top-level def starts
    if($line -match '^def\s+'){
      $inside = $false
      $out.Add($line)
    }
    continue
  }

  # remove any stray duplicate call lines; we will add one clean call later
  if($line -match '^verify_official_release\(\)\s*$'){
    continue
  }

  $out.Add($line)
}

if(-not $replaced){
  # if function didn't exist, inject at top after imports (simple safe inject)
  $inject = New-Object System.Collections.Generic.List[string]
  $idx = -1
  for($i=0;$i -lt $out.Count;$i++){
    if($out[$i] -match '^import '){ $idx = $i }
  }
  if($idx -lt 0){ $idx = 0 }

  $head = @()
  for($i=0;$i -le $idx;$i++){ $head += $out[$i] }
  $tail = @()
  for($i=$idx+1;$i -lt $out.Count;$i++){ $tail += $out[$i] }

  $out2 = New-Object System.Collections.Generic.List[string]
  foreach($l in $head){ $out2.Add($l) }

  $out2.Add("")
  $out2.Add("# Altiora release signature verification (STRICT fail-closed; STATE.md source of truth)")
  $out2.Add("def verify_official_release():")
  $out2.Add("    import os, sys, subprocess, re")
  $out2.Add("    repo_root = os.path.dirname(os.path.abspath(__file__))")
  $out2.Add("    releases_dir = os.path.join(repo_root, '_out', 'releases')")
  $out2.Add("    pub = os.path.join(repo_root, 'keys', 'altiora_public_key.pem')")
  $out2.Add("    verify = os.path.join(repo_root, 'tools', 'verify_signature.py')")
  $out2.Add("    state_path = os.path.join(repo_root, 'STATE.md')")
  $out2.Add("    if not os.path.exists(pub): return")
  $out2.Add("    if not os.path.isdir(releases_dir): sys.exit(1)")
  $out2.Add("    if not os.path.exists(state_path): sys.exit(1)")
  $out2.Add("    txt = open(state_path,'r',encoding='utf-8',errors='ignore').read()")
  $out2.Add("    m = re.search(r'\\bv\\d+\\.\\d+\\.\\d+\\b', txt)")
  $out2.Add("    if not m: sys.exit(1)")
  $out2.Add("    v = m.group(0)")
  $out2.Add("    zip_path = os.path.join(releases_dir, f'AltioraBackupPro_{v}_release.zip')")
  $out2.Add("    if not os.path.exists(zip_path): sys.exit(1)")
  $out2.Add("    if not os.path.exists(zip_path + '.sig'): sys.exit(1)")
  $out2.Add("    r = subprocess.run([sys.executable, verify, pub, zip_path])")
  $out2.Add("    if r.returncode != 0: sys.exit(1)")
  $out2.Add("")

  foreach($l in $tail){ $out2.Add($l) }
  $out = $out2
}

# append ONE clean call at end (ensures it always executes)
$out.Add("")
$out.Add("verify_official_release()")
$out.Add("")

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "verify_official_release forced to STRICT fail-closed (STATE.md) and single-call appended"
