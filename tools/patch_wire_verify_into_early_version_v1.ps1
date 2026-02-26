$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis" }

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"
if(!(Test-Path -LiteralPath $target)){ throw "altiora.py introuvable: $target" }

$src=Get-Content -LiteralPath $target -Encoding UTF8
$out=New-Object System.Collections.Generic.List[string]

# ---- helper function block (insert after VERSION_STR line) ----
$helper=@(
"",
"# ABP_RELEASE_VERIFY_V1: strict release signature verification (fail-closed)",
"def _abp_verify_release_if_protected():",
"    import os, sys, subprocess",
"    if os.environ.get('ALTIORA_PROTECTED','0') != '1':",
"        return",
"    repo = os.path.dirname(os.path.abspath(__file__))",
"    rel  = os.path.abspath(os.path.join(repo, '_out', 'releases'))",
"    pub  = os.path.abspath(os.path.join(repo, 'keys', 'altiora_public_key.pem'))",
"    ver  = os.path.abspath(os.path.join(repo, 'tools', 'verify_signature.py'))",
"    if not os.path.exists(pub):",
"        sys.exit(1)",
"    if not os.path.isdir(rel):",
"        sys.exit(1)",
"    z = [f for f in os.listdir(rel) if f.startswith('AltioraBackupPro_') and f.endswith('_release.zip')]",
"    if not z:",
"        sys.exit(1)",
"    paths = [os.path.join(rel, f) for f in z]",
"    latest = max(paths, key=os.path.getmtime)",
"    sig = latest + '.sig'",
"    if not os.path.exists(sig):",
"        sys.exit(1)",
"    r = subprocess.run([sys.executable, ver, pub, latest])",
"    if r.returncode != 0:",
"        sys.exit(1)",
""
)

$helperInserted=$false

# Tripwire removal state (remove the 3 lines we injected)
$skipTripwire=0

foreach($line in $src){

    # remove tripwire lines if present
    if($skipTripwire -gt 0){
        $skipTripwire--
        continue
    }

    if($line -match "TRIPWIRE: _altiora_verify called"){
        # also skip following two lines (import sys / sys.exit(99))
        $skipTripwire=2
        continue
    }

    # insert helper right after VERSION_STR definition (only once)
    $out.Add($line)
    if(-not $helperInserted -and $line -match '^VERSION_STR\s*=\s*"Altiora Backup Pro v'){
        foreach($h in $helper){ $out.Add($h) }
        $helperInserted=$true
        continue
    }

    # 1) JSON-only early exit block: inject call inside body (indent 8 spaces)
    if($line -match "^\s*if\s*\(\s*'--version'\s*in\s*sys\.argv\s*\)\s*or\s*\(\s*'-V'\s*in\s*sys\.argv\s*\)\s*:"){
        # next lines are body; we inject immediately after the if line
        $indent = ($line -replace "(\S.*)$","")  # leading whitespace
        $out.Add($indent + "    _abp_verify_release_if_protected()")
        continue
    }

    # 2) Top-level early --version block: inject inside body (indent 4 spaces)
    if($line -match "^\s*if\s*\(\s*\(\s*'--version'\s*in\s*sys\.argv\s*\)\s*or\s*\(\s*'-V'\s*in\s*sys\.argv\s*\)\s*\)\s*and\s*\(\s*'--json'\s*not\s*in\s*sys\.argv\s*\)\s*:"){
        $indent = ($line -replace "(\S.*)$","")
        $out.Add($indent + "    _abp_verify_release_if_protected()")
        continue
    }
}

# sanity: helper must exist
if(-not $helperInserted){
    throw "VERSION_STR line not found - cannot insert verifier"
}

$out | Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "Early --version hooks wired to strict verifier (ALTIORA_PROTECTED=1). Tripwire removed."
