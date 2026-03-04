# setup.ps1 — Windows bootstrap for Sendient local developer profile
#
# This is a minimal PowerShell script that:
#   1. Checks if WSL2 is installed
#   2. If not, prompts the user to install WSL2 (Ubuntu)
#   3. Once WSL is available, invokes setup.sh inside WSL
#
# The real setup logic lives in setup.sh (bash). This script only ensures
# WSL is available and delegates to it.
#
# Usage:
#   .\setup.ps1
#
# Requires: Windows 10 version 2004+ or Windows 11

$ErrorActionPreference = "Stop"

Write-Host "=== Sendient Local Profile Setup (Windows Bootstrap) ===" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is installed
$wslStatus = $null
try {
    $wslStatus = wsl --status 2>&1
} catch {
    $wslStatus = $null
}

if (-not $wslStatus -or $LASTEXITCODE -ne 0) {
    Write-Host "[INFO] WSL2 is not installed." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Would you like to install WSL2 with Ubuntu? (y/N)"

    if ($response -eq "y" -or $response -eq "Y") {
        Write-Host "[INFO] Installing WSL2 with Ubuntu..." -ForegroundColor Cyan
        wsl --install -d Ubuntu
        Write-Host ""
        Write-Host "[INFO] WSL2 installation initiated." -ForegroundColor Green
        Write-Host "       Please restart your computer, then run this script again." -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "[FAIL] WSL2 is required for Sendient local development on Windows." -ForegroundColor Red
        exit 1
    }
}

Write-Host "[OK] WSL2 is available" -ForegroundColor Green

# Copy setup.sh into the WSL filesystem and invoke it
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$setupSh = Join-Path $scriptDir "setup.sh"

if (-not (Test-Path $setupSh)) {
    Write-Host "[FAIL] setup.sh not found at $setupSh" -ForegroundColor Red
    exit 1
}

# Convert Windows path to WSL path and run
$wslPath = wsl wslpath -a ($setupSh -replace "\\", "/")
Write-Host "[INFO] Running setup.sh inside WSL..." -ForegroundColor Cyan
Write-Host ""

wsl bash $wslPath @args

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Sendient local profile setup complete" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[FAIL] Setup exited with code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}
