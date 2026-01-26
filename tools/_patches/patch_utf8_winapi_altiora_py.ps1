$path = "C:\Dev\AltioraBackupPro\altiora.py"
$s = Get-Content $path -Raw -Encoding UTF8

$inject = @"
# --- UTF-8 console hardening (Windows) ---
import os, sys
os.environ.setdefault("PYTHONUTF8", "1")
os.environ.setdefault("PYTHONIOENCODING", "utf-8")

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

try:
    if os.name == "nt":
        import ctypes
        k32 = ctypes.windll.kernel32
        k32.SetConsoleOutputCP(65001)
        k32.SetConsoleCP(65001)
except Exception:
    pass
# -----------------------------------------
"@

# Insertion après le premier double saut de ligne après le premier 'import'
$idx = $s.IndexOf("import")
if ($idx -lt 0) { throw "ERROR: cannot find import in altiora.py" }
$after = $s.IndexOf("`n`n", $idx)
if ($after -lt 0) { throw "ERROR: cannot locate import block end" }

$out = $s.Substring(0, $after+2) + $inject + $s.Substring($after+2)
Set-Content -Path $path -Value $out -Encoding UTF8

Write-Host "OK: patch UTF-8 WinAPI injecté dans altiora.py"
