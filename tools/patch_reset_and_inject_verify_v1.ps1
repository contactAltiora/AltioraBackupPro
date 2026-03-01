$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH=1 requis"
}

$root   = (Get-Location).Path
$target = Join-Path $root "altiora.py"

if(!(Test-Path $target)){
    throw "altiora.py introuvable"
}

# reset via git (source de vérité)
if(Get-Command git -ErrorAction SilentlyContinue){

    git restore --source=HEAD -- $target

}else{

    throw "git requis pour reset sécurisé"
}

# reload clean file
$src = Get-Content $target -Encoding UTF8

$out = New-Object System.Collections.Generic.List[string]

$inserted = $false

foreach($line in $src){

    $out.Add($line)

    if(-not $inserted -and $line -match '^import '){

        # wait until last import
        continue
    }

}

# inject after imports
$importsEnd = 0
for($i=0;$i -lt $src.Count;$i++){
    if($src[$i] -match '^import '){
        $importsEnd = $i
    }
}

$verify = @(
"",
"# Altiora official release verification",
"def verify_official_release():",
"    try:",
"        import os, sys, subprocess",
"        repo_root = os.path.dirname(os.path.abspath(__file__))",
"        releases_dir = os.path.join(repo_root, '_out', 'releases')",
"        pub_key = os.path.join(repo_root, 'keys', 'altiora_public_key.pem')",
"        verify_script = os.path.join(repo_root, 'tools', 'verify_signature.py')",
"",
"        if not os.path.exists(pub_key):",
"            return",
"",
"        if not os.path.isdir(releases_dir):",
"            return",
"",
"        zips = [f for f in os.listdir(releases_dir) if f.endswith('_release.zip')]",
"",
"        if not zips:",
"            return",
"",
"        paths = [os.path.join(releases_dir,f) for f in zips]",
"        zip_path = max(paths, key=os.path.getmtime)",
"",
"        r = subprocess.run([sys.executable, verify_script, pub_key, zip_path])",
"",
"        if r.returncode != 0:",
"            sys.exit(1)",
"",
"    except Exception:",
"        sys.exit(1)",
"",
"verify_official_release()",
""
)

$new = @()

$new += $src[0..$importsEnd]
$new += $verify
$new += $src[($importsEnd+1)..($src.Count-1)]

$new | Set-Content $target -Encoding UTF8

Write-Host "altiora.py reset and verify hook injected cleanly"
