# Sendient Claude — Windows Installer (PowerShell)
# Usage: irm https://raw.githubusercontent.com/Sendient/company-claude/main/install.ps1 | iex
#    or: pwsh ./install.ps1              (from inside the repo)
#
# What this does:
#   1. Checks for (or installs) Claude Code
#   2. Checks for (or installs) the `run` task runner
#   3. Installs the sendient-claude wrapper as "claude.cmd" in ~/.sendient/bin
#   4. Configures MCP runtool server in ~/.claude.json
#   5. Adds ~/.sendient/bin to User PATH (persistent)
#   6. Installs Runfile tasks (company_claude:*) to ~/.runfile

$ErrorActionPreference = 'Stop'

$InstallDir = if ($env:SENDIENT_INSTALL_DIR) { $env:SENDIENT_INSTALL_DIR } else { Join-Path $env:USERPROFILE '.sendient\bin' }
$WrapperName = 'claude.cmd'

# File URLs — set these to gist raw URLs for no-auth installs
$RepoRawUrl = if ($env:SENDIENT_REPO_URL) { $env:SENDIENT_REPO_URL } else { 'https://raw.githubusercontent.com/Sendient/company-claude/main' }
$UrlWrapper = if ($env:SENDIENT_URL_WRAPPER) { $env:SENDIENT_URL_WRAPPER } else { "$RepoRawUrl/sendient-claude.cmd" }
$UrlRunfile = if ($env:SENDIENT_URL_RUNFILE) { $env:SENDIENT_URL_RUNFILE } else { "$RepoRawUrl/Runfile" }

# Auth headers for private repo — only needed when fetching from raw.githubusercontent.com
$AuthHeaders = @{}
if ($env:GITHUB_TOKEN) {
    $AuthHeaders = @{ Authorization = "token $($env:GITHUB_TOKEN)" }
}

# Detect local vs remote mode
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$LocalWrapper = Join-Path $ScriptDir 'sendient-claude.cmd'
$LocalMode = Test-Path $LocalWrapper

# ── Helpers ───────────────────────────────────────────────────────────

function Write-Info  { param([string]$Msg) Write-Host "  → $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  ! $Msg" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "  ✗ $Msg" -ForegroundColor Red; exit 1 }

# ── Step 0: Pre-flight ───────────────────────────────────────────────

Write-Host ''
Write-Host 'Sendient Claude — Installer' -ForegroundColor White
Write-Host ''

if (-not $LocalMode -and -not $env:GITHUB_TOKEN -and -not $env:SENDIENT_URL_WRAPPER) {
    Write-Fail 'GITHUB_TOKEN is required for remote installs from private repo. Set it first: $env:GITHUB_TOKEN = "ghp_..." Or set SENDIENT_URL_WRAPPER / SENDIENT_URL_RUNFILE to gist raw URLs.'
}

# ── Step 1: Ensure Claude Code is installed ──────────────────────────

$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    $claudeVersion = try { & claude --version 2>$null } catch { 'unknown' }
    Write-Ok "Claude Code found ($claudeVersion)"
} else {
    Write-Info 'Claude Code not found — installing via npm...'
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        & npm install -g @anthropic-ai/claude-code
        if ($LASTEXITCODE -ne 0) { Write-Fail 'npm install failed' }
        Write-Ok 'Claude Code installed'
        # Refresh command cache
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    } else {
        Write-Fail "npm not found. Install Node.js/npm first, or install Claude Code manually:`n     https://docs.anthropic.com/en/docs/claude-code"
    }
}

# ── Step 2: Ensure `run` task runner is installed ────────────────────

$runCmd = Get-Command run -ErrorAction SilentlyContinue
if ($runCmd) {
    $runVersion = try { & run --version 2>$null } catch { 'unknown' }
    Write-Ok "run tool found ($runVersion)"
} else {
    Write-Info 'run tool not found — installing...'
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    $cargoCmd = Get-Command cargo -ErrorAction SilentlyContinue

    if ($scoopCmd) {
        & scoop install run
        Write-Ok 'run tool installed via scoop'
    } elseif ($cargoCmd) {
        & cargo install run
        if ($LASTEXITCODE -ne 0) { Write-Fail 'cargo install run failed' }
        Write-Ok 'run tool installed via cargo'
    } else {
        Write-Info 'No package manager found. Installing Rust toolchain...'
        # Download and run rustup-init.exe
        $rustupInit = Join-Path $env:TEMP 'rustup-init.exe'
        Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile $rustupInit -UseBasicParsing
        & $rustupInit -y
        if ($LASTEXITCODE -ne 0) { Write-Fail 'Rust toolchain installation failed' }
        # Add cargo to current session PATH
        $cargobin = Join-Path $env:USERPROFILE '.cargo\bin'
        $env:Path = "$cargobin;$env:Path"
        & cargo install run
        if ($LASTEXITCODE -ne 0) { Write-Fail 'cargo install run failed' }
        Write-Ok 'run tool installed via cargo (Rust toolchain installed)'
    }
}

# ── Step 3: Install wrapper script ───────────────────────────────────

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$WrapperPath = Join-Path $InstallDir $WrapperName

# Safety: refuse to overwrite a real claude binary (not our wrapper)
if (Test-Path $WrapperPath) {
    $content = Get-Content $WrapperPath -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -notmatch 'sendient-claude') {
        Write-Fail "$WrapperPath exists and is not the Sendient wrapper. Aborting to avoid overwriting Claude Code."
    }
}

Write-Info "Installing wrapper to $WrapperPath"

if ($LocalMode) {
    Copy-Item $LocalWrapper $WrapperPath -Force
    Write-Ok 'Wrapper installed (from local repo)'
} else {
    try {
        Invoke-WebRequest -Uri $UrlWrapper -OutFile $WrapperPath -UseBasicParsing -Headers $AuthHeaders
        Write-Ok 'Wrapper installed (downloaded)'
    } catch {
        Write-Fail "Failed to download wrapper from $UrlWrapper"
    }
}

# ── Step 4: Ensure ~/.sendient/bin is in User PATH ───────────────────

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -and $userPath.Split(';') -contains $InstallDir) {
    Write-Ok "$InstallDir already in PATH"
} else {
    Write-Info "Adding $InstallDir to User PATH..."
    $newPath = if ($userPath) { "$InstallDir;$userPath" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    # Also update current session
    $env:Path = "$InstallDir;$env:Path"
    Write-Warn "Added $InstallDir to User PATH — restart your terminal for full effect."
}

# ── Step 5: Configure MCP runtool server ─────────────────────────────

$claudeJson = Join-Path $env:USERPROFILE '.claude.json'

if (Test-Path $claudeJson) {
    try {
        $config = Get-Content $claudeJson -Raw | ConvertFrom-Json

        # Ensure mcpServers property exists
        if (-not ($config.PSObject.Properties.Name -contains 'mcpServers')) {
            $config | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue ([PSCustomObject]@{})
        }

        if ($config.mcpServers.PSObject.Properties.Name -contains 'runtool') {
            Write-Ok 'runtool MCP server already configured'
        } else {
            $runtoolConfig = [PSCustomObject]@{
                command = 'run'
                args    = @('--serve-mcp')
            }
            $config.mcpServers | Add-Member -NotePropertyName 'runtool' -NotePropertyValue $runtoolConfig
            $config | ConvertTo-Json -Depth 10 | Set-Content $claudeJson -Encoding UTF8
            Write-Ok 'runtool MCP server added to ~/.claude.json'
        }
    } catch {
        Write-Warn "Could not parse ~/.claude.json — skipping MCP config. Error: $_"
    }
} else {
    Write-Warn '~/.claude.json not found — skipping MCP config (will be created on first claude run)'
}

# ── Step 6: Install Runfile tasks to ~/.runfile ──────────────────────

$GlobalRunfile = Join-Path $env:USERPROFILE '.runfile'
$BeginMarker = '# ── BEGIN company_claude ──'
$EndMarker = '# ── END company_claude ──'

# Extract our block from source Runfile
$OurBlock = $null
if ($LocalMode) {
    $LocalRunfile = Join-Path $ScriptDir 'Runfile'
    if (Test-Path $LocalRunfile) {
        $lines = Get-Content $LocalRunfile
        $inBlock = $false
        $blockLines = @()
        foreach ($line in $lines) {
            if ($line -match [regex]::Escape($BeginMarker)) { $inBlock = $true }
            if ($inBlock) { $blockLines += $line }
            if ($line -match [regex]::Escape($EndMarker)) { $inBlock = $false }
        }
        if ($blockLines.Count -gt 0) { $OurBlock = $blockLines -join "`n" }
    }
} else {
    try {
        $runfileContent = (Invoke-WebRequest -Uri $UrlRunfile -UseBasicParsing -Headers $AuthHeaders).Content
        $lines = $runfileContent -split "`n"
        $inBlock = $false
        $blockLines = @()
        foreach ($line in $lines) {
            if ($line -match [regex]::Escape($BeginMarker)) { $inBlock = $true }
            if ($inBlock) { $blockLines += $line }
            if ($line -match [regex]::Escape($EndMarker)) { $inBlock = $false }
        }
        if ($blockLines.Count -gt 0) { $OurBlock = $blockLines -join "`n" }
    } catch {
        Write-Warn "Could not download Runfile — skipping"
    }
}

if (-not $OurBlock) {
    Write-Warn 'Could not extract company_claude block from Runfile — skipping'
} elseif (-not (Test-Path $GlobalRunfile)) {
    Set-Content -Path $GlobalRunfile -Value $OurBlock -Encoding UTF8
    Write-Ok "Runfile tasks installed to $GlobalRunfile"
} else {
    $existingContent = Get-Content $GlobalRunfile -Raw
    if ($existingContent -match [regex]::Escape($BeginMarker)) {
        # Replace existing block
        $pattern = '(?s)' + [regex]::Escape($BeginMarker) + '.*?' + [regex]::Escape($EndMarker) + '[^\n]*'
        $newContent = [regex]::Replace($existingContent, $pattern, $OurBlock)
        Set-Content -Path $GlobalRunfile -Value $newContent -Encoding UTF8
        Write-Ok "Runfile tasks updated in $GlobalRunfile"
    } else {
        # Append our block
        Add-Content -Path $GlobalRunfile -Value "`n$OurBlock" -Encoding UTF8
        Write-Ok "Runfile tasks appended to $GlobalRunfile"
    }
}

# ── Step 7: Verify ───────────────────────────────────────────────────

Write-Host ''
$resolvedClaude = Get-Command claude -ErrorAction SilentlyContinue
if ($resolvedClaude -and $resolvedClaude.Source -eq $WrapperPath) {
    Write-Ok "All done! Running 'claude' will now show the Sendient SREE banner."
} else {
    Write-Ok "Wrapper installed at $WrapperPath"
    if ($resolvedClaude) {
        Write-Warn "Your shell may resolve a different 'claude' first ($($resolvedClaude.Source))."
        Write-Warn "Ensure $InstallDir appears before $(Split-Path $resolvedClaude.Source) in your PATH."
    }
}
Write-Host ''
