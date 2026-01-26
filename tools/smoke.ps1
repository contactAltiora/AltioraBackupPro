$ErrorActionPreference="Stop"
Set-Location "C:\Dev\AltioraBackupPro"

py -m py_compile .\altiora.py
py -m py_compile .\src\backup_core.py
py -m py_compile .\src\backup_cli.py
py -m py_compile .\src\master_key.py

# Vérifs rapides CLI (ne doit pas planter)
py -X utf8 .\altiora.py --help | Out-Null
py -X utf8 .\altiora.py list   | Out-Null

Write-Host "OK: smoke passed"
