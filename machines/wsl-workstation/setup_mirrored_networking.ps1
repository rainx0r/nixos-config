# Run from an elevated PowerShell session:
#   .\setup_mirrored_networking.ps1
#
# Optional:
#   .\setup_mirrored_networking.ps1 -SshPort 22
#   .\setup_mirrored_networking.ps1 -ShutdownWSL

[CmdletBinding()]
param(
  [int]$SshPort = 4089,
  [switch]$ShutdownWSL
)

$ErrorActionPreference = "Stop"

$wslVmCreatorId = "{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}"
$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
$firewallRuleName = "WSL NixOS SSH"
$requiredSettingsBySection = [ordered]@{
  wsl2 = [ordered]@{
    networkingMode = "mirrored"
  }
  experimental = [ordered]@{
    hostAddressLoopback = "true"
  }
}

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-IniValue {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Section,
    [string]$Key,
    [string]$Value
  )

  $sectionPattern = "^\s*\[{0}\]\s*$" -f [regex]::Escape($Section)
  $keyPattern = "^\s*{0}\s*=" -f [regex]::Escape($Key)

  $sectionStart = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -imatch $sectionPattern) {
      $sectionStart = $i
      break
    }
  }

  if ($sectionStart -lt 0) {
    if ($Lines.Count -gt 0 -and $Lines[$Lines.Count - 1] -ne "") {
      $Lines.Add("")
    }

    $Lines.Add("[$Section]")
    $Lines.Add("$Key=$Value")
    return
  }

  $sectionEnd = $Lines.Count
  for ($i = $sectionStart + 1; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^\s*\[.+\]\s*$") {
      $sectionEnd = $i
      break
    }
  }

  for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
    if ($Lines[$i] -imatch $keyPattern) {
      $Lines[$i] = "$Key=$Value"
      return
    }
  }

  $Lines.Insert($sectionEnd, "$Key=$Value")
}

if (-not (Test-IsAdministrator)) {
  throw "Run this script from an elevated PowerShell session."
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw "wsl.exe is not available on this machine."
}

if (-not (Get-Command New-NetFirewallHyperVRule -ErrorAction SilentlyContinue)) {
  throw "Hyper-V firewall cmdlets are not available on this machine."
}

$lines = [System.Collections.Generic.List[string]]::new()
if (Test-Path -LiteralPath $wslConfigPath) {
  foreach ($line in Get-Content -LiteralPath $wslConfigPath) {
    $lines.Add($line)
  }
}

foreach ($sectionName in $requiredSettingsBySection.Keys) {
  foreach ($entry in $requiredSettingsBySection[$sectionName].GetEnumerator()) {
    Set-IniValue -Lines $lines -Section $sectionName -Key $entry.Key -Value $entry.Value
  }
}

$newConfig = (($lines -join "`r`n").TrimEnd() + "`r`n")
$oldConfig = ""

if (Test-Path -LiteralPath $wslConfigPath) {
  $oldConfig = [System.IO.File]::ReadAllText($wslConfigPath)
}

if ($newConfig -ne $oldConfig) {
  if (Test-Path -LiteralPath $wslConfigPath) {
    $backupPath = "{0}.bak.{1}" -f $wslConfigPath, (Get-Date -Format "yyyyMMddHHmmss")
    Copy-Item -LiteralPath $wslConfigPath -Destination $backupPath
    Write-Host ("Backed up existing .wslconfig to {0}" -f $backupPath)
  }

  [System.IO.File]::WriteAllText(
    $wslConfigPath,
    $newConfig,
    [System.Text.Encoding]::ASCII
  )
  Write-Host ("Updated {0}" -f $wslConfigPath)
} else {
  Write-Host (".wslconfig already contains the required mirrored-networking settings: {0}" -f $wslConfigPath)
}

$existingRule = Get-NetFirewallHyperVRule -Name $firewallRuleName -ErrorAction SilentlyContinue
if ($existingRule) {
  Set-NetFirewallHyperVRule `
    -Name $firewallRuleName `
    -Direction Inbound `
    -VMCreatorId $wslVmCreatorId `
    -Protocol TCP `
    -LocalPorts $SshPort `
    -Action Allow `
    -Enabled True | Out-Null
  Write-Host ("Updated Hyper-V firewall rule '{0}' for TCP port {1}" -f $firewallRuleName, $SshPort)
} else {
  New-NetFirewallHyperVRule `
    -Name $firewallRuleName `
    -DisplayName $firewallRuleName `
    -Direction Inbound `
    -VMCreatorId $wslVmCreatorId `
    -Protocol TCP `
    -LocalPorts $SshPort `
    -Action Allow `
    -Enabled True | Out-Null
  Write-Host ("Created Hyper-V firewall rule '{0}' for TCP port {1}" -f $firewallRuleName, $SshPort)
}

if ($ShutdownWSL) {
  Write-Host "Shutting down WSL so the networking changes can take effect..."
  & wsl.exe --shutdown
} else {
  Write-Host "Run 'wsl.exe --shutdown' and then reopen the distro to apply mirrored networking."
}

Write-Host "After restart, verify the WSL instance has a LAN-facing address and then connect with SSH on the configured port."
