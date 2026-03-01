$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$target = Join-Path (Get-Location).Path "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8

# bounded pattern: replace the whole hook block up to the call
$pattern = '(?s)# --- RUNTIME PROTECTION HOOK \(fail-closed\) ---\s*def _abp_runtime_verify_or_die\(\):.*?# Call protection hook as early as possible\s*_abp_runtime_verify_or_die\(\)\s*'
if($text -notmatch $pattern){ throw "Bloc hook introuvable via pattern borné (abort)" }

$replacement = @"
# --- RUNTIME PROTECTION HOOK (fail-closed) ---
def _abp_runtime_verify_or_die():
    import os, sys, subprocess, hashlib

    if os.environ.get('ALTIORA_PROTECTED','0') != '1':
        return
    # Selftest mode bypass for release pipeline only
    if os.environ.get('ABP_SELFTEST_MODE','0') == '1':
        return

    # Determine application root (supports PyInstaller onefile EXE)
    if getattr(sys, 'frozen', False):
        root = os.path.dirname(os.path.abspath(sys.executable))
    else:
        root = os.path.dirname(os.path.abspath(__file__))

    pub      = os.path.join(root, 'keys', 'altiora_public_key.pem')
    state    = os.path.join(root, 'STATE.md')
    state_h  = os.path.join(root, 'STATE.md.sha256')
    verifier = os.path.join(root, 'tools', 'verify_signature.py')

    if (not os.path.exists(pub)) or (not os.path.exists(state)) or (not os.path.exists(verifier)):
        print('FATAL: protected mode requires keys/altiora_public_key.pem + STATE.md + tools/verify_signature.py')
        sys.exit(101)

    # 1) Signature verification of STATE.md
    cmd = [sys.executable, verifier, pub, state]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if (r.returncode != 0) or ('SIGNATURE VALID' not in (r.stdout or '')):
        print('FATAL: signature verification failed for STATE.md')
        if r.stdout: print(r.stdout.strip())
        if r.stderr: print(r.stderr.strip())
        sys.exit(102)

    # 2) SHA256 verification of STATE.md (if STATE.md.sha256 exists)
    if os.path.exists(state_h):
        expected = open(state_h, 'r', encoding='utf-8').read().strip().split()[0].upper()
        h = hashlib.sha256()
        with open(state, 'rb') as f:
            for chunk in iter(lambda: f.read(1024*1024), b''):
                h.update(chunk)
        got = h.hexdigest().upper()
        if expected and got != expected:
            print('FATAL: STATE.md sha256 mismatch')
            print('EXPECTED:', expected)
            print('GOT     :', got)
            sys.exit(103)

    # 3) Release ZIP sha256 verification (if release sha exists)
    # Version-agnostic: if release artifacts for current version exist, verify them.
    def _abp_get_version_safe():
        try:
            v = globals().get('__version__')
            if isinstance(v, str) and v.strip():
                return v.strip()
        except Exception:
            pass
        return None

    ver = _abp_get_version_safe()
    rel_sha = None
    rel_zip = None
    if ver:
        rel_sha = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.sha256')
        rel_zip = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.zip')

    if rel_sha and rel_zip and os.path.exists(rel_sha) and os.path.exists(rel_zip):
        expected = open(rel_sha, 'r', encoding='utf-8').read().strip().split()[0].upper()
        h = hashlib.sha256()
        with open(rel_zip, 'rb') as f:
            for chunk in iter(lambda: f.read(1024*1024), b''):
                h.update(chunk)
        got = h.hexdigest().upper()
        if expected and got != expected:
            print('FATAL: release ZIP sha256 mismatch')
            print('EXPECTED:', expected)
            print('GOT     :', got)
            sys.exit(104)

# Call protection hook as early as possible
_abp_runtime_verify_or_die()

"@

$text2 = [regex]::Replace($text, $pattern, $replacement)
Set-Content -LiteralPath $target -Value $text2 -Encoding UTF8
Write-Host "PATCH OK: runtime hook block repaired (v4 exe-aware, indentation clean)"
