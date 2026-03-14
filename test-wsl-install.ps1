#Requires -RunAsAdministrator
# =============================================================================
# MachineY Engine (机器小乙·引擎) — Local Test Script
#
# Registers machiney-engine.wsl with the local WSL manifest so you can test
# `wsl --install machiney-engine` without submitting to Microsoft.
#
# Usage (Admin PowerShell):
#   .\test-wsl-install.ps1
#
# Cleanup:
#   Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" -Name DistributionListUrl
# =============================================================================

[CmdletBinding()]
param(
    [string]$TarPath = "$PSScriptRoot\distro\machiney-engine.wsl",
    [string]$Flavor = "machiney-engine",
    [string]$Version = "machiney-engine",
    [string]$FriendlyName = "MachineY Engine - 机器小乙·引擎 (Powered by OpenClaw)"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve paths
$TarPath = Resolve-Path $TarPath
Write-Host "============================================"
Write-Host "  MachineY Engine — Local Install Test"
Write-Host "  机器小乙·引擎"
Write-Host "============================================"
Write-Host ""
Write-Host "  File:   $TarPath"
Write-Host "  Size:   $([math]::Round((Get-Item $TarPath).Length / 1MB, 2)) MB"

# Compute SHA256
Write-Host "  Computing SHA256..."
$hash = (Get-FileHash $TarPath -Algorithm SHA256).Hash
Write-Host "  SHA256: $hash"

# Create manifest
$manifest = @{
    ModernDistributions = @{
        "$Flavor" = @(
            @{
                Name         = "$Version"
                Default      = $true
                FriendlyName = "$FriendlyName"
                Amd64Url     = @{
                    Url    = "file://$TarPath"
                    Sha256 = "0x$hash"
                }
            }
        )
    }
}

$manifestFile = "$PSScriptRoot\manifest.json"
$manifest | ConvertTo-Json -Depth 5 | Out-File -Encoding ascii $manifestFile
Write-Host ""
Write-Host "  Manifest: $manifestFile"

# Set registry
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" `
    -Name DistributionListUrl `
    -Value "file://$manifestFile" `
    -Type String -Force

Write-Host ""
Write-Host "============================================"
Write-Host "  Done! You can now run:"
Write-Host ""
Write-Host "    wsl --list --online"
Write-Host "    wsl --install machiney-engine"
Write-Host ""
Write-Host "  To cleanup:"
Write-Host "    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss' -Name DistributionListUrl"
Write-Host "============================================"
