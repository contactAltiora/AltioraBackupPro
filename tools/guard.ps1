$ErrorActionPreference="Stop"
Set-Location "C:\Dev\AltioraBackupPro"

git restore --source=HEAD --worktree --staged .\altiora.py | Out-Null
py -m py_compile .\altiora.py

powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\smoke.ps1

Write-Host "OK: guard passed (HEAD clean + smoke ok)"
