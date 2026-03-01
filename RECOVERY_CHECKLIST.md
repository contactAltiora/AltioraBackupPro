\# ALTIORA — RECOVERY CHECKLIST

Author: Guy Mouyémè

Purpose: Restore a new computer as a full Altiora Backup Pro development and release system



------------------------------------------------------------

STEP 1 — BASE SYSTEM

------------------------------------------------------------



Install Windows 10 or 11

Run Windows Update completely



Restart



------------------------------------------------------------

STEP 2 — INSTALL CORE SOFTWARE

------------------------------------------------------------



Install Python 3.11+



https://www.python.org/downloads/



IMPORTANT:

check "Add Python to PATH"



verify:



python --version



------------------------------------------------------------



Install PowerShell 7 (recommended)



winget install Microsoft.PowerShell



verify:



pwsh



------------------------------------------------------------

STEP 3 — CONNECT RECOVERY DRIVE

------------------------------------------------------------



Plug external drive:



F:

or

H:



Verify:



F:\\ALTIORA\_RECOVERY



------------------------------------------------------------

STEP 4 — RUN FULL RESTORE

------------------------------------------------------------



Open PowerShell



Run:



powershell -ExecutionPolicy Bypass -File F:\\ALTIORA\_RECOVERY\\06\_PIPELINE\\FULL\_SYSTEM\_RESTORE.ps1 -InstallDeps



Wait until:



RESTORE COMPLETE



------------------------------------------------------------

STEP 5 — VERIFY SYSTEM

------------------------------------------------------------



Open:



C:\\Dev\\AltioraBackupPro



Verify:



STATE.md exists



keys\\altiora\_private\_key.pem exists



Run:



tools\\update\_state\_md.ps1



------------------------------------------------------------

STEP 6 — SYSTEM READY

------------------------------------------------------------



Altiora Backup Pro ready for:



development

release

signing

backup



------------------------------------------------------------

CRITICAL RULE

------------------------------------------------------------



Never lose:



altiora\_private\_key.pem



Without it, official releases cannot be signed.



------------------------------------------------------------

END

