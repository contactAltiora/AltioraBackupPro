$ErrorActionPreference="Stop"
if($env:ALTIORA_PATCH -ne "1"){ throw "ALTIORA_PATCH=1 requis (utiliser tools\patch_runner.ps1)" }

$repoRoot = (git rev-parse --show-toplevel) 2>$null
if([string]::IsNullOrWhiteSpace($repoRoot)){ throw "FAIL-CLOSED: not a git repo. Run from C:\Dev\AltioraBackupPro" }

$path = Join-Path $repoRoot "tools\update_state_md.ps1"
if(!(Test-Path -LiteralPath $path)){ throw "Missing: $path" }

$txt0 = Get-Content -LiteralPath $path -Encoding UTF8 -Raw
if([string]::IsNullOrEmpty($txt0)){ throw "FAIL-CLOSED: empty file read: $path" }

# Idempotent
if($txt0 -like "*ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2*"){
  Write-Host "Already patched: ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2. No change."
  exit 0
}

# Anchor
if($txt0 -notlike "*Version parse error*"){ throw "FAIL-CLOSED: anchor not found: 'Version parse error'" }

$txt = $txt0

# Helper (insert near top, after possible param(...) block)
if($txt -notmatch '(?is)\bfunction\s+ABP-GetVersionCore\b'){
  $helperLines = @(
    "# ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2",
    "function ABP-GetVersionCore {",
    "  param([Parameter(Mandatory=`$true)][string]`$V)",
    "  `$v2 = `$V.Trim()",
    "  # Accept: v1.2.3p1 / v1.2.3-rc1 / 1.2.3+build.7 -> return v1.2.3 or 1.2.3",
    "  `$m = [regex]::Match(`$v2, '^(?<v>v)?(?<core>\d+\.\d+\.\d+)')",
    "  if(`$m.Success){",
    "    `$core = `$m.Groups['core'].Value",
    "    if(`$m.Groups['v'].Success){ return ('v' + `$core) }",
    "    return `$core",
    "  }",
    "  return `$v2",
    "}",
    ""
  )
  $helper = ($helperLines -join "`r`n") + "`r`n"

  $mParam = [regex]::Match($txt, '(?is)\bparam\s*\(.*?\)\s*\r?\n')
  if($mParam.Success){
    $pos = $mParam.Index + $mParam.Length
    $txt = $txt.Insert($pos, "`r`n$helper")
  } else {
    $txt = "$helper`r`n$txt"
  }
}

# Patch the specific validation block that throws "Version parse error"
# We look for: if( ... -match/-notmatch ... ) { throw "Version parse error" }
$patched = 0
$pat = '(?is)if\s*\(\s*(?<cond>[^)]*(?:-match|-notmatch)[^)]*)\)\s*\{\s*throw\s*([''"])Version parse error\2\s*\}'
$txt2 = [regex]::Replace($txt, $pat, {
  param($m)
  $cond = $m.Groups["cond"].Value

  if($m.Value -like "*ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2_NORMALIZE*"){ return $m.Value }

  # Find first variable in condition to normalize (e.g. $version, $ver, $v)
  $vm = [regex]::Match($cond, '(\$[A-Za-z_]\w*)')
  if(-not $vm.Success){ return $m.Value }

  $v = $vm.Groups[1].Value
  $script:patched++

@"
if($cond){
  # ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2_NORMALIZE
  $v = (ABP-GetVersionCore ($v))
  if($cond){ throw "Version parse error" }
}
"@
})

if($patched -lt 1){
  throw "FAIL-CLOSED: anchor exists, but could not rewrite a matching if(...) { throw ""Version parse error"" } block. Inspect tools\update_state_md.ps1 around that throw."
}

Set-Content -LiteralPath $path -Value $txt2 -Encoding UTF8
Write-Host "OK: patched -> tools\update_state_md.ps1 [ABP_UPDATE_STATE_PARSE_SUFFIX_V3K2], rewritten_blocks=$patched"
