# setup.ps1 - Windows bootstrap for Sendient developer environments
#
# This script handles Windows setup by either:
#   1. Running Windows-native setup (tools in PowerShell/Windows)
#   2. Delegating to WSL (tools in Linux subsystem)
#
# Usage:
#   .\setup.ps1                   # Interactive - choose native or WSL
#   .\setup.ps1 --native          # Windows-native setup directly
#   .\setup.ps1 --wsl             # WSL setup directly
#   .\setup.ps1 --with-repos      # Forward flag to profile setup
#
# Distribution:
#   This lives in the public Sendient/sendient-onboarding repo.
#   The canonical copy is in Sendient/developer-tools/setup.ps1.
#
# Requires: Windows 10 version 1809+ or Windows 11

$ErrorActionPreference = "Continue"

$DEVELOPER_TOOLS_REPO = "Sendient/developer-tools"

# ── Parse arguments ──────────────────────────────────────────────────────────
$MODE = ""
$FORWARD_ARGS = @()

foreach ($arg in $args) {
    switch ($arg) {
        "--native" { $MODE = "native" }
        "--wsl"    { $MODE = "wsl" }
        default    { $FORWARD_ARGS += $arg }
    }
}

# ── Banner ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=== Sendient Developer Platform Setup (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# ── Mode selection ───────────────────────────────────────────────────────────

if (-not $MODE) {
    Write-Host "How do you want to develop on this machine?" -ForegroundColor White
    Write-Host ""
    Write-Host "  1) Windows-native  - Tools in PowerShell, repos at ~\sendient" -ForegroundColor Green
    Write-Host "                       Best for: VS Code, Claude Code, standard dev workflow"
    Write-Host ""
    Write-Host "  2) WSL (Linux)     - Tools inside WSL Ubuntu, repos at ~/sendient" -ForegroundColor Yellow
    Write-Host "                       Best for: Linux-first workflows, Docker-heavy development"
    Write-Host ""

    do {
        $choice = Read-Host "Select mode [1-2]"
    } while ($choice -ne "1" -and $choice -ne "2")

    $MODE = if ($choice -eq "1") { "native" } else { "wsl" }
}

Write-Host "[INFO] Selected mode: $MODE" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Windows-native path
# =============================================================================
if ($MODE -eq "native") {
    # Check prerequisites: git and gh must be available in Windows
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Host "[FAIL] git is not installed." -ForegroundColor Red
        Write-Host "       Install: winget install Git.Git" -ForegroundColor Red
        exit 4
    }
    Write-Host "[OK] git found: $(git --version)" -ForegroundColor Green

    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghCmd) {
        Write-Host "[FAIL] GitHub CLI (gh) is not installed." -ForegroundColor Red
        Write-Host "       Install: winget install GitHub.cli" -ForegroundColor Red
        exit 4
    }
    Write-Host "[OK] gh found: $(gh --version | Select-Object -First 1)" -ForegroundColor Green

    # Check gh auth
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[INFO] GitHub CLI is not authenticated." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Open: https://github.com/settings/tokens/new?scopes=repo,read:org,workflow&description=sendient-dev-setup" -ForegroundColor Cyan
        Write-Host "  2. Generate token (90-day expiry), copy it."
        Write-Host ""

        $token = Read-Host "  3. Paste your token here"
        if ([string]::IsNullOrWhiteSpace($token)) {
            Write-Host "[FAIL] No token provided." -ForegroundColor Red
            exit 4
        }

        $token | gh auth login --with-token 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Token auth failed." -ForegroundColor Red
            exit 4
        }
        Write-Host "[OK] GitHub CLI authenticated" -ForegroundColor Green
    } else {
        Write-Host "[OK] gh is authenticated" -ForegroundColor Green
    }

    # Clone developer-tools if needed
    $workspace = if ($env:SENDIENT_WORKSPACE) { $env:SENDIENT_WORKSPACE } else { Join-Path $env:USERPROFILE "sendient" }
    $devToolsPath = Join-Path $workspace "developer-tools"

    if (-not (Test-Path (Join-Path $devToolsPath ".git"))) {
        Write-Host "[INFO] Cloning developer-tools..." -ForegroundColor Cyan
        if (-not (Test-Path $workspace)) {
            New-Item -ItemType Directory -Path $workspace -Force | Out-Null
        }
        $null = & gh repo clone $DEVELOPER_TOOLS_REPO $devToolsPath 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Could not clone developer-tools" -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK] developer-tools cloned" -ForegroundColor Green
    } else {
        Write-Host "[OK] developer-tools found at $devToolsPath" -ForegroundColor Green
    }

    # Delegate to Windows-native profile setup
    $profileScript = Join-Path $devToolsPath "profiles\local\setup.ps1"
    if (-not (Test-Path $profileScript)) {
        Write-Host "[FAIL] Profile script not found: $profileScript" -ForegroundColor Red
        Write-Host "       developer-tools may need updating. Run: git -C $devToolsPath pull" -ForegroundColor Red
        exit 1
    }

    Write-Host "[INFO] Delegating to local profile setup (Windows-native)..." -ForegroundColor Cyan
    Write-Host ""
    & $profileScript @FORWARD_ARGS
    exit $LASTEXITCODE
}

# =============================================================================
# WSL path
# =============================================================================
if ($MODE -eq "wsl") {
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
            Write-Host "[FAIL] WSL2 is required for WSL mode. Use --native for Windows-native setup." -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "[OK] WSL2 is available" -ForegroundColor Green

    # Download setup.sh alongside this script if not present
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $setupSh = Join-Path $scriptDir "setup.sh"

    if (-not (Test-Path $setupSh)) {
        Write-Host "[INFO] Downloading setup.sh..." -ForegroundColor Cyan
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh" -OutFile $setupSh -UseBasicParsing
            Write-Host "[OK] setup.sh downloaded" -ForegroundColor Green
        } catch {
            Write-Host "[FAIL] Could not download setup.sh" -ForegroundColor Red
            Write-Host "       Download manually: https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh"
            exit 1
        }
    }

    # Verify it's actually a bash script (not a copy of this PS1)
    $firstLine = Get-Content $setupSh -TotalCount 1
    if ($firstLine -notmatch "^#!/") {
        Write-Host "[FAIL] setup.sh does not appear to be a bash script." -ForegroundColor Red
        Write-Host "       Delete $setupSh and re-run this script to re-download it." -ForegroundColor Red
        exit 1
    }

    # Convert Windows path to WSL path and run
    $wslPath = wsl wslpath -a ($setupSh -replace "\\", "/")
    Write-Host "[INFO] Running setup.sh inside WSL..." -ForegroundColor Cyan
    Write-Host ""

    # Forward args: prepend "local" profile since we know this is local setup
    $wslArgs = @("bash", $wslPath, "local") + $FORWARD_ARGS
    wsl @wslArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[OK] Sendient local profile setup complete (WSL)" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Your dev environment is inside WSL. To use it:" -ForegroundColor Cyan
        Write-Host "    wsl                          # open WSL terminal"
        Write-Host "    cd ~/sendient                # your workspace"
        Write-Host "    code .                       # open VS Code (Remote-WSL)"
    } else {
        Write-Host ""
        Write-Host "[FAIL] Setup exited with code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
