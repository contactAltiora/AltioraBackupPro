$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$target = Join-Path (Get-Location).Path "altiora.py"
$text = Get-Content -LiteralPath $target -Raw -Encoding UTF8

if($text -notmatch "_abp_runtime_verify_or_die"){ throw "Hook introuvable (abort)" }

# Replace the root resolution line inside the hook (bounded: only first occurrence)
$pattern = "(?m)^\s*root\s*=\s*os\.path\.dirname\(os\.path\.abspath\(__file__\)\)\s*$"
if($text -notmatch $pattern){ throw "Ligne root=... introuvable (abort)" }

$replacement = @"
    # Determine application root (supports PyInstaller onefile EXE)
    if getattr(sys, 'frozen', False):
        root = os.path.dirname(os.path.abspath(sys.executable))
    else:
        root = os.path.dirname(os.path.abspath(__file__))
"@

$text2 = [regex]::Replace($text, $pattern, $replacement, 1)
Set-Content -LiteralPath $target -Value $text2 -Encoding UTF8
Write-Host "PATCH OK: hook root resolution upgraded for EXE (sys.executable when frozen)"
