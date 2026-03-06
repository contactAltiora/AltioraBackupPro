$ErrorActionPreference = "Stop"
Set-Location "C:\Dev\AltioraBackupPro"

function Read-PasswordMasked {
  param([string]$Prompt = "Password")

  Write-Host -NoNewline "${Prompt}: "
  $chars = New-Object System.Collections.Generic.List[char]

  while ($true) {
    $key = [Console]::ReadKey($true)

    if ($key.Key -eq [ConsoleKey]::Enter) {
      Write-Host ""
      break
    }

    if ($key.Key -eq [ConsoleKey]::Backspace) {
      if ($chars.Count -gt 0) {
        $chars.RemoveAt($chars.Count - 1)
        Write-Host -NoNewline "`b `b"
      }
      continue
    }

    if (-not [char]::IsControl($key.KeyChar)) {
      $chars.Add($key.KeyChar)
      Write-Host -NoNewline "*"
    }
  }

  return (-join $chars.ToArray())
}

try {
  $plain = Read-PasswordMasked -Prompt "ABP_SELFTEST_PASSWORD"

  if([string]::IsNullOrWhiteSpace($plain)){
    throw "FAIL-CLOSED: password empty"
  }

  $env:ABP_SELFTEST_PASSWORD = $plain

  powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\release_build_and_backup.ps1" -NoUsbRequired
}
finally {
  Remove-Item Env:ABP_SELFTEST_PASSWORD -ErrorAction SilentlyContinue
}
