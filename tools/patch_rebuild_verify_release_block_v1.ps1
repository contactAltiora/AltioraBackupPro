$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"

if(!(Test-Path $target)){
    throw "altiora.py introuvable"
}

$src = Get-Content $target -Encoding UTF8

$out = New-Object System.Collections.Generic.List[string]

$inside = $false

foreach($line in $src){

    if($line -match '^def verify_official_release'){
        $inside = $true

        $out.Add('def verify_official_release():')
        $out.Add('    try:')
        $out.Add('        repo_root = os.path.dirname(os.path.abspath(__file__))')
        $out.Add('        releases_dir = os.path.join(repo_root, "_out", "releases")')
        $out.Add('        pub_key = os.path.join(repo_root, "keys", "altiora_public_key.pem")')
        $out.Add('        verify_script = os.path.join(repo_root, "tools", "verify_signature.py")')
        $out.Add('')
        $out.Add('        if not os.path.exists(pub_key):')
        $out.Add('            print("WARNING: public key missing")')
        $out.Add('            return')
        $out.Add('')
        $out.Add('        if not os.path.isdir(releases_dir):')
        $out.Add('            print("WARNING: releases directory missing")')
        $out.Add('            return')
        $out.Add('')
        $out.Add('        zips = [')
        $out.Add('            f for f in os.listdir(releases_dir)')
        $out.Add('            if f.startswith("AltioraBackupPro_") and f.endswith("_release.zip")')
        $out.Add('        ]')
        $out.Add('')
        $out.Add('        if not zips:')
        $out.Add('            print("WARNING: no release zip found")')
        $out.Add('            return')
        $out.Add('')
        $out.Add('        paths = [os.path.join(releases_dir, f) for f in zips]')
        $out.Add('        zip_path = max(paths, key=os.path.getmtime)')
        $out.Add('')
        $out.Add('        result = subprocess.run([')
        $out.Add('            sys.executable, verify_script, pub_key, zip_path')
        $out.Add('        ], capture_output=True)')
        $out.Add('')
        $out.Add('        if result.returncode != 0:')
        $out.Add('            print("FATAL: release signature invalid")')
        $out.Add('            sys.exit(1)')
        $out.Add('')
        $out.Add('    except Exception as e:')
        $out.Add('        print("FATAL: release signature verification error")')
        $out.Add('        print(str(e))')
        $out.Add('        sys.exit(1)')
        $out.Add('')
        continue
    }

    if($inside){
        if($line -match '^def '){
            $inside = $false
            $out.Add($line)
        }
        continue
    }

    $out.Add($line)
}

$out | Set-Content $target -Encoding UTF8

Write-Host "verify_official_release block rebuilt cleanly"
