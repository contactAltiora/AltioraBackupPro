$path  = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

$before = $lines.Count
$removed = 0

$out = New-Object System.Collections.Generic.List[string]

for($i=0; $i -lt $lines.Count; $i++){
  $ln = $lines[$i]

  # Kill the broken one-liner masterkey dispatch
  if($ln -match 'if\s+args\.command\s*==\s*"masterkey"\s*:' -and $ln -match 'from\s+src\.master_key'){
    $removed++
    continue
  }

  $out.Add($ln)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($path, $out.ToArray(), $utf8NoBom)

Write-Host "OK: purge one-liner masterkey (removed=$removed) lines=$before->$($out.Count)"
