param(
  [Parameter(Mandatory=$false)][int]$N = 25,
  [Parameter(Mandatory=$true)][string]$Password,
  [Parameter(Mandatory=$true)][string]$SourceDir,
  [Parameter(Mandatory=$false)][string]$AltioraPy = ".\altiora.py",
  [Parameter(Mandatory=$false)][string]$PythonExe = "python",
  [Parameter(Mandatory=$false)][string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

function Fail([string]$msg){
  Write-Host ("[SELFTEST] ERROR: " + $msg)
  exit 1
}

function Info([string]$msg){
  Write-Host ("[SELFTEST] " + $msg)
}

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ return }
  if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function Get-HeaderLineAndOffset([byte[]]$bytes){
  $lf = [byte]10
  $idx = [Array]::IndexOf($bytes, $lf)
  if($idx -lt 0){ return $null }

  $end = $idx - 1
  if($end -ge 0 -and $bytes[$end] -eq [byte]13){ $end-- } # CR
  if($end -lt 0){ return $null }

  $headerBytes = $bytes[0..$end]
  $headerText  = [System.Text.Encoding]::UTF8.GetString($headerBytes)
  $offsetAfter = $idx + 1
  return @($headerText, $offsetAfter)
}

function Extract-SaltNonce([string]$path){
  if(!(Test-Path $path)){ Fail("Fichier introuvable: $path") }

  $bytes = [System.IO.File]::ReadAllBytes($path)
  if($bytes.Length -lt 1){ Fail("Fichier vide: $path") }

  # Trouver début JSON : premier '{'
  $lb = [byte][char]'{'
  $rb = [byte][char]'}'
  $j0 = [Array]::IndexOf($bytes, $lb)
  if($j0 -lt 0){ Fail("JSON start { introuvable: $path") }

  # Trouver une fin JSON valide en testant des '}' candidates (borné)
  $maxScan = 8192
  $scanEnd = [Math]::Min($bytes.Length - 1, $j0 + $maxScan)
  $j1 = -1
  $headerText = $null

  for($k=$j0; $k -le $scanEnd; $k++){
    if($bytes[$k] -ne $rb){ continue }
    $tryBytes = $bytes[$j0..$k]
    $tryText  = [System.Text.Encoding]::UTF8.GetString($tryBytes)
    try { $null = $tryText | ConvertFrom-Json; $j1 = $k; $headerText = $tryText; break } catch { }
  }

  if($j1 -lt 0){
    # diagnostic court
    $diagLen = [Math]::Min(120, $bytes.Length - $j0)
    if($diagLen -gt 0){
      $diagText = [System.Text.Encoding]::UTF8.GetString($bytes[$j0..($j0+$diagLen-1)])
      Fail("Header JSON introuvable (aucune fin valide dans $maxScan bytes). Début extrait: $diagText")
    } else {
      Fail("Header JSON introuvable (aucune fin valide dans $maxScan bytes).")
    }
  }

  $off  = $j1 + 1
  $need = 16 + 12
  if(($off + $need) -gt $bytes.Length){
    Fail("Taille insuffisante pour SALT(16)+NONCE(12) après JSON: $path")
  }

  $salt  = $bytes[$off..($off+15)]
  $nonce = $bytes[($off+16)..($off+27)]

  $saltHex  = ([BitConverter]::ToString($salt)).Replace("-","").ToLowerInvariant()
  $nonceHex = ([BitConverter]::ToString($nonce)).Replace("-","").ToLowerInvariant()

  return @($saltHex, $nonceHex)
}

if(!(Test-Path $AltioraPy)){
  Fail("AltioraPy introuvable: $AltioraPy")
}
if(!(Test-Path $SourceDir)){
  Fail("SourceDir introuvable: $SourceDir")
}

if([string]::IsNullOrWhiteSpace($OutDir)){
  $OutDir = Join-Path $env:TEMP ("abp_selftest_out_" + [Guid]::NewGuid().ToString("N"))
}
Ensure-Dir $OutDir

Info("N=$N")
Info("SourceDir=$SourceDir")
Info("OutDir=$OutDir")
Info("AltioraPy=$AltioraPy")
Info("PythonExe=$PythonExe")

$seenNonce = New-Object "System.Collections.Generic.HashSet[string]"
$seenSalt  = New-Object "System.Collections.Generic.HashSet[string]"
$saltDupCount = 0

for($i=1; $i -le $N; $i++){
  Info("Backup $i / $N ...")

  $outFile = Join-Path $OutDir ("selftest_" + $i.ToString("0000") + "_" + [Guid]::NewGuid().ToString("N") + ".altb")
  $args = @(
    $AltioraPy,
    "backup",
    $SourceDir,
    $outFile,
    "-p", $Password
  )

  $p = Start-Process -FilePath $PythonExe -ArgumentList $args -NoNewWindow -Wait -PassThru
  if($p.ExitCode -ne 0){
    Fail("Commande backup a échoué (exit=$($p.ExitCode)) au tour $i")
  }

  $latest = Get-Item -LiteralPath $outFile

  if($null -eq $latest){
    Fail("Aucun fichier généré dans OutDir après backup $i")
  }

  $sn = Extract-SaltNonce $latest.FullName
  $saltHex  = $sn[0]
  $nonceHex = $sn[1]

  if(-not $seenNonce.Add($nonceHex)){
    Fail("DOUBLON NONCE détecté: $nonceHex (fichier: $($latest.Name))")
  }

  if(-not $seenSalt.Add($saltHex)){
    $saltDupCount++
  }
}

if($saltDupCount -gt 0){
  Info("ATTENTION: doublons de SALT détectés: $saltDupCount (informatif, non bloquant)")
}

Info("✅ OK aucun doublon de NONCE sur $N backups")
exit 0



