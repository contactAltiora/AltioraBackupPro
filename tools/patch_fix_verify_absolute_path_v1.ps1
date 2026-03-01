$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
 throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$file=Join-Path $root "altiora.py"

$src=Get-Content $file -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]

foreach($line in $src){

 if($line -match '^def _altiora_verify'){
  
  $out.Add("def _altiora_verify():")
  $out.Add(" import os,sys,subprocess")
  $out.Add(" repo=os.path.dirname(os.path.abspath(__file__))")
  $out.Add(" rel=os.path.abspath(os.path.join(repo,'_out','releases'))")
  $out.Add(" pub=os.path.abspath(os.path.join(repo,'keys','altiora_public_key.pem'))")
  $out.Add(" verify=os.path.abspath(os.path.join(repo,'tools','verify_signature.py'))")
  $out.Add("")
  $out.Add(" if not os.path.exists(pub): sys.exit(1)")
  $out.Add(" if not os.path.exists(rel): sys.exit(1)")
  $out.Add("")
  $out.Add(" files=os.listdir(rel)")
  $out.Add(" z=[f for f in files if f.endswith('_release.zip')]")
  $out.Add("")
  $out.Add(" if len(z)==0: sys.exit(1)")
  $out.Add("")
  $out.Add(" paths=[os.path.join(rel,f) for f in z]")
  $out.Add(" latest=max(paths,key=os.path.getmtime)")
  $out.Add("")
  $out.Add(" sig=latest+'.sig'")
  $out.Add(" if not os.path.exists(sig): sys.exit(1)")
  $out.Add("")
  $out.Add(" r=subprocess.run([sys.executable,verify,pub,latest])")
  $out.Add(" if r.returncode!=0: sys.exit(1)")
  
  continue
 }

 $out.Add($line)
}

$out | Set-Content $file -Encoding UTF8

Write-Host "VERIFY PATH FIXED"
