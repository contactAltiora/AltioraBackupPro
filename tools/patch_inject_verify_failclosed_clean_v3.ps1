$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
 throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$file=Join-Path $root "altiora.py"

$src=Get-Content $file -Encoding UTF8

# find last import
$idx=0
for($i=0;$i -lt $src.Count;$i++){
 if($src[$i] -match '^(import |from )'){
  $idx=$i
 }
}

$block=@(
"",
"def _altiora_verify():",
" import os,sys,subprocess",
" repo=os.path.dirname(os.path.abspath(__file__))",
" rel=os.path.join(repo,'_out','releases')",
" pub=os.path.join(repo,'keys','altiora_public_key.pem')",
" verify=os.path.join(repo,'tools','verify_signature.py')",
"",
" if not os.path.exists(pub): sys.exit(1)",
" if not os.path.isdir(rel): sys.exit(1)",
"",
" z=[f for f in os.listdir(rel) if f.endswith('_release.zip')]",
" if not z: sys.exit(1)",
"",
" latest=max([os.path.join(rel,f) for f in z],key=os.path.getmtime)",
"",
" if not os.path.exists(latest+'.sig'): sys.exit(1)",
"",
" r=subprocess.run([sys.executable,verify,pub,latest])",
" if r.returncode!=0: sys.exit(1)",
"",
"_altiora_verify()",
""
)

$new=@()

$new+=$src[0..$idx]
$new+=$block
$new+=$src[($idx+1)..($src.Count-1)]

$new | Set-Content $file -Encoding UTF8

Write-Host "FAIL-CLOSED VERIFY INSTALLED CLEAN"
