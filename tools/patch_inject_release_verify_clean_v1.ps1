$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH requis"
}

$root = (Get-Location).Path
$target = Join-Path $root "altiora.py"

$src = Get-Content $target -Encoding UTF8

if($src -match "verify_official_release"){
    Write-Host "verify_official_release already present"
    exit 0
}

$insertIndex = 0

for($i=0;$i -lt $src.Count;$i++){
    if($src[$i] -match "^import "){
        $insertIndex = $i
    }
}

$block = @(
"",
"# Altiora release signature verification",
"def verify_official_release():",
"    import os, sys, subprocess",
"    repo_root = os.path.dirname(os.path.abspath(__file__))",
"    releases_dir = os.path.join(repo_root, '_out', 'releases')",
"    pub = os.path.join(repo_root, 'keys', 'altiora_public_key.pem')",
"    verify = os.path.join(repo_root, 'tools', 'verify_signature.py')",
"",
"    if not os.path.exists(pub):",
"        return",
"",
"    if not os.path.isdir(releases_dir):",
"        return",
"",
"    zips = [f for f in os.listdir(releases_dir) if f.endswith('_release.zip')]",
"",
"    if not zips:",
"        return",
"",
"    paths = [os.path.join(releases_dir,f) for f in zips]",
"    latest = max(paths, key=os.path.getmtime)",
"",
"    r = subprocess.run([sys.executable, verify, pub, latest])",
"",
"    if r.returncode != 0:",
"        sys.exit(1)",
"",
"verify_official_release()",
""
)

$new = @()

$new += $src[0..$insertIndex]
$new += $block
$new += $src[($insertIndex+1)..($src.Count-1)]

$new | Set-Content $target -Encoding UTF8

Write-Host "release verify injected cleanly"
