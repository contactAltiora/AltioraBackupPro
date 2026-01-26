$path = "C:\Dev\AltioraBackupPro\altiora.py"
$lines = Get-Content $path -Encoding UTF8

$inject = @(
"# --- UTF-8 console hardening (Windows) ---",
"import os, sys",
"os.environ.setdefault('PYTHONUTF8', '1')",
"os.environ.setdefault('PYTHONIOENCODING', 'utf-8')",
"",
"try:",
"    if hasattr(sys.stdout, 'reconfigure'):",
"        sys.stdout.reconfigure(encoding='utf-8', errors='replace')",
"    if hasattr(sys.stderr, 'reconfigure'):",
"        sys.stderr.reconfigure(encoding='utf-8', errors='replace')",
"except Exception:",
"    pass",
"",
"try:",
"    if os.name == 'nt':",
"        import ctypes",
"        k32 = ctypes.windll.kernel32",
"        k32.SetConsoleOutputCP(65001)",
"        k32.SetConsoleCP(65001)",
"except Exception:",
"    pass",
"# -----------------------------------------",
""
)

# Calcul point d'insertion :
# - on saute un éventuel shebang (#!...)
# - on saute une éventuelle déclaration d'encodage (# -*- coding: ... -*-)
# - on saute une docstring de module (''' ... ''' ou """ ... """)
$i = 0

# shebang
if ($lines.Count -gt 0 -and $lines[0] -match '^\s*#!') { $i = 1 }

# coding
if ($i -lt $lines.Count -and $lines[$i] -match 'coding[:=]\s*[-\w.]+') { $i++ }

# docstring module (début direct)
if ($i -lt $lines.Count -and $lines[$i] -match '^\s*(\'\'\'|""")') {
    $q = $Matches[1]
    $i++
    while ($i -lt $lines.Count) {
        if ($lines[$i] -match [regex]::Escape($q)) { $i++; break }
        $i++
    }
}

# Protection: si déjà patché, on ne repatche pas
$already = $false
foreach ($ln in $lines) {
    if ($ln -like "*UTF-8 console hardening (Windows)*") { $already = $true; break }
}
if ($already) {
    Write-Host "INFO: patch déjà présent dans altiora.py (aucune modification)."
    exit 0
}

# Appliquer
$out = @()
$out += $lines[0..($i-1)]
$out += $inject
$out += $lines[$i..($lines.Count-1)]

Set-Content -Path $path -Value $out -Encoding UTF8
Write-Host "OK: patch UTF-8 WinAPI injecté dans altiora.py (v2, insertion index=$i)"
