$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$root = (Get-Location).Path
$target = Join-Path $root "altiora.py"
if(!(Test-Path $target)){ throw "altiora.py introuvable: $target" }

$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8
if($text -notmatch "_abp_runtime_verify_or_die"){ throw "Hook introuvable (abort)" }

# Replace only the v1.0.13 hardcoded release block with a versioned one (bounded)
$pattern = '(?s)\s*# 3\) Release ZIP sha256 verification \(if release sha exists\)\s*rel_sha = .*?sys\.exit\(104\)\s*'
if($text -notmatch $pattern){ throw "Bloc release sha v2 introuvable (abort)" }

$replacement = @"
    # 3) Release ZIP sha256 verification (if release sha exists)
    # Version-agnostic: if release artifacts for current version exist, verify them.
    def _abp_get_version_safe():
        try:
            # Prefer src/__init__.py convention if present in project
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

    # fallback: do nothing if versioned artifacts are not found
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

"@

$text2 = [regex]::Replace($text, $pattern, $replacement)
Set-Content -LiteralPath $target -Value $text2 -Encoding UTF8
Write-Host "PATCH OK: runtime verify hook v3 (versioned release sha verification)"
