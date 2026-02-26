$ErrorActionPreference="Stop"

if($env:ALTIORA_PATCH -ne "1"){
 throw "ALTIORA_PATCH requis"
}

$root=(Get-Location).Path
$file=Join-Path $root "altiora.py"

$src=Get-Content $file -Encoding UTF8

$out=New-Object System.Collections.Generic.List[string]

$inserted=$false

foreach($line in $src){

 $out.Add($line)

 if(!$inserted -and $line -match "__name__\s*==\s*['""]__main__['""]"){

  $out.Add("    try:")
  $out.Add("        _altiora_verify()")
  $out.Add("    except Exception:")
  $out.Add("        import sys")
  $out.Add("        sys.exit(1)")

  $inserted=$true
 }
}

$out | Set-Content $file -Encoding UTF8

Write-Host "VERIFY CALL INSERTED INTO MAIN"
