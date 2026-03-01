$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"

$src=Get-Content -LiteralPath $target -Encoding UTF8

# remove any previous hook
$clean=@()
foreach($line in $src){
    if($line -match "verify_official_release\(\)"){ continue }
    $clean+=$line
}

# find last import
$idx=0
for($i=0;$i -lt $clean.Count;$i++){
    if($clean[$i] -match '^import ' -or $clean[$i] -match '^from '){
        $idx=$i
    }
}

$block=@(
"",
"# ALTIO​RA CRYPTO VERIFY HOOK (FAIL-CLOSED)",
"def verify_official_release():",
"    import os,sys,subprocess",
"    repo=os.path.dirname(os.path.abspath(__file__))",
"    rel=os.path.join(repo,'_out','releases')",
"    pub=os.path.join(repo,'keys','altiora_public_key.pem')",
"    verify=os.path.join(repo,'tools','verify_signature.py')",
"",
"    if not os.path.exists(pub):",
"        sys.exit(1)",
"",
"    if not os.path.isdir(rel):",
"        sys.exit(1)",
"",
"    z=[f for f in os.listdir(rel) if f.endswith('_release.zip')]",
"",
"    if not z:",
"        sys.exit(1)",
"",
"    latest=max([os.path.join(rel,f) for f in z],key=os.path.getmtime)",
"",
"    if not os.path.exists(latest+'.sig'):",
"        sys.exit(1)",
"",
"    r=subprocess.run([sys.executable,verify,pub,latest])",
"",
"    if r.returncode!=0:",
"        sys.exit(1)",
"",
"verify_official_release()",
""
)

$new=@()
$new+=$clean[0..$idx]
$new+=$block
$new+=$clean[($idx+1)..($clean.Count-1)]

$new | Set-Content -LiteralPath $target -Encoding UTF8

Write-Host "TOP-LEVEL STRICT VERIFY INSTALLED"
