$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8

if($text -match "_abp_runtime_verify_or_die"){
  throw "Hook déjà présent dans altiora.py (abort pour éviter doublon)"
}

$hook = @"
# --- RUNTIME PROTECTION HOOK (fail-closed) ---
def _abp_runtime_verify_or_die():
    import os, sys, subprocess
    if os.environ.get('ALTIORA_PROTECTED','0') != '1':
        return
    # Selftest mode bypass for release pipeline only
    if os.environ.get('ABP_SELFTEST_MODE','0') == '1':
        return
    root = os.path.dirname(os.path.abspath(__file__))
    pub  = os.path.join(root, 'keys', 'altiora_public_key.pem')
    state = os.path.join(root, 'STATE.md')
    verifier = os.path.join(root, 'tools', 'verify_signature.py')
    if (not os.path.exists(pub)) or (not os.path.exists(state)) or (not os.path.exists(verifier)):
        print('FATAL: protected mode requires keys/altiora_public_key.pem + STATE.md + tools/verify_signature.py')
        sys.exit(101)
    cmd = [sys.executable, verifier, pub, state]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if (r.returncode != 0) or ('SIGNATURE VALID' not in (r.stdout or '')):
        print('FATAL: signature verification failed for STATE.md')
        if r.stdout: print(r.stdout.strip())
        if r.stderr: print(r.stderr.strip())
        sys.exit(102)

# Call protection hook as early as possible
_abp_runtime_verify_or_die()

"@

# Insert hook after the initial import block (safe + deterministic)
# Strategy: find first non-import/non-shebang line after leading header.
$lines = $text -split "`n", 0, "SimpleMatch"
$insertAt = -1

for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i].Trim()
  if($ln -eq ""){ continue }
  if($ln.StartsWith("#!")){ continue }
  if($ln.StartsWith("#")){ continue }
  # allow module docstring at top
  if($ln.StartsWith('"""') -or $ln.StartsWith("'''")){
    # skip until closing triple quote
    $q = $ln.Substring(0,3)
    for($j=$i+1; $j -lt $lines.Count; $j++){
      if($lines[$j].Contains($q)){
        $i = $j
        break
      }
    }
    continue
  }
  # now we are at code; advance through consecutive import/from lines
  $k = $i
  while($k -lt $lines.Count){
    $t = $lines[$k].Trim()
    if($t -eq ""){ $k++; continue }
    if($t.StartsWith("import ") -or $t.StartsWith("from ")){ $k++; continue }
    break
  }
  $insertAt = $k
  break
}

if($insertAt -lt 0){ throw "Insertion point not found (unexpected file layout)" }

$before = $lines[0..($insertAt-1)] -join "`n"
$after  = $lines[$insertAt..($lines.Count-1)] -join "`n"

$out = $before + "`n`n" + $hook + $after
Set-Content -LiteralPath $target -Value $out -Encoding UTF8

Write-Host "PATCH OK: runtime verify hook inserted (after imports)"
