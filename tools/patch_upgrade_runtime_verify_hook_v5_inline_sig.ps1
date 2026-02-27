$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$target = Join-Path (Get-Location).Path "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8

# replace whole hook block deterministically
$pattern = '(?s)# --- RUNTIME PROTECTION HOOK \(fail-closed\) ---\s*def _abp_runtime_verify_or_die\(\):.*?# Call protection hook as early as possible\s*_abp_runtime_verify_or_die\(\)\s*'
if($text -notmatch $pattern){ throw "Bloc hook introuvable via pattern borné (abort)" }

$replacement = @"
# --- RUNTIME PROTECTION HOOK (fail-closed) ---
def _abp_runtime_verify_or_die():
    import os, sys, hashlib

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

    pub_pem  = os.path.join(root, 'keys', 'altiora_public_key.pem')
    state    = os.path.join(root, 'STATE.md')
    state_sig= os.path.join(root, 'STATE.md.sig')
    state_h  = os.path.join(root, 'STATE.md.sha256')

    if (not os.path.exists(pub_pem)) or (not os.path.exists(state)) or (not os.path.exists(state_sig)):
        print('FATAL: protected mode requires keys/altiora_public_key.pem + STATE.md + STATE.md.sig')
        sys.exit(101)

    def _sha256_file(p):
        h = hashlib.sha256()
        with open(p, 'rb') as f:
            for chunk in iter(lambda: f.read(1024*1024), b''):
                h.update(chunk)
        return h.hexdigest().upper()

    def _read_expected_sha(p):
        # accept "HASH  filename" or just "HASH"
        s = open(p, 'r', encoding='utf-8').read().strip()
        if not s:
            return ""
        return s.split()[0].upper()

    def _verify_ed25519(pub_pem_path, file_path, sig_path):
        # inline verify: avoids subprocess recursion in PyInstaller EXE
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

        pub_bytes = open(pub_pem_path, 'rb').read()
        pub = serialization.load_pem_public_key(pub_bytes)
        if not isinstance(pub, Ed25519PublicKey):
            raise ValueError("Public key is not Ed25519")

        data = open(file_path, 'rb').read()
        sig  = open(sig_path, 'rb').read()
        pub.verify(sig, data)
        return True

    # 1) Signature verification of STATE.md
    try:
        _verify_ed25519(pub_pem, state, state_sig)
    except Exception as e:
        print('FATAL: signature verification failed for STATE.md')
        try:
            print(str(e))
        except Exception:
            pass
        sys.exit(102)

    # 2) SHA256 verification of STATE.md (if STATE.md.sha256 exists)
    if os.path.exists(state_h):
        expected = _read_expected_sha(state_h)
        got = _sha256_file(state)
        if expected and got != expected:
            print('FATAL: STATE.md sha256 mismatch')
            print('EXPECTED:', expected)
            print('GOT     :', got)
            sys.exit(103)

    # 3) Release ZIP sha256 verification (if release sha exists)
    def _abp_get_version_safe():
        try:
            v = globals().get('__version__')
            if isinstance(v, str) and v.strip():
                return v.strip()
        except Exception:
            pass
        return None

    ver = _abp_get_version_safe()
    if ver:
        rel_sha = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.sha256')
        rel_zip = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.zip')
        if os.path.exists(rel_sha) and os.path.exists(rel_zip):
            expected = _read_expected_sha(rel_sha)
            got = _sha256_file(rel_zip)
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
Write-Host "PATCH OK: runtime hook v5 inline Ed25519 verify (no subprocess, EXE-safe)"
