$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
    throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$target=Join-Path $root "altiora.py"

$src=Get-Content -LiteralPath $target -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]

$inside=$false

foreach($line in $src){

    if($line -match '^def verify_official_release'){
        $inside=$true

        $out.Add("def verify_official_release():")
        $out.Add("    import os,sys,subprocess")
        $out.Add("")
        $out.Add("    repo=os.path.dirname(os.path.abspath(__file__))")
        $out.Add("    rel=os.path.join(repo,'_out','releases')")
        $out.Add("    pub=os.path.join(repo,'keys','altiora_public_key.pem')")
        $out.Add("    verify=os.path.join(repo,'tools','verify_signature.py')")
        $out.Add("")
        $out.Add("    if not os.path.exists(pub):")
        $out.Add("        print('FATAL: public key missing')")
        $out.Add("        sys.exit(1)")
        $out.Add("")
        $out.Add("    if not os.path.isdir(rel):")
        $out.Add("        print('FATAL: releases directory missing')")
        $out.Add("        sys.exit(1)")
        $out.Add("")
        $out.Add("    z=[f for f in os.listdir(rel) if f.endswith('_release.zip')]")
        $out.Add("")
        $out.Add("    if not z:")
        $out.Add("        print('FATAL: no release found')")
        $out.Add("        sys.exit(1)")
        $out.Add("")
        $out.Add("    paths=[os.path.join(rel,f) for f in z]")
        $out.Add("    latest=max(paths,key=os.path.getmtime)")
        $out.Add("")
        $out.Add("    sig=latest+'.sig'")
        $out.Add("")
        $out.Add("    if not os.path.exists(sig):")
        $out.Add("        print('FATAL: signature missing')")
        $out.Add("        sys.exit(1)")
        $out.Add("")
        $out.Add("    r=subprocess.run([sys.executable,verify,pub,latest])")
        $out.Add("")
        $out.Add("    if r.returncode!=0:")
        $out.Add("        print('FATAL: signature invalid')")
        $out.Add("        sys.exit(1)")
        $out.Add("")
        continue
    }

    if($inside){
        if($line -match '^def '){
            $inside=$false
            $out.Add($line)
        }
        continue
    }

    $out.Add($line)
}

$out | Set-Content -LiteralPath $target -Encoding UTF8

Write-Host "STRICT release verification installed"
