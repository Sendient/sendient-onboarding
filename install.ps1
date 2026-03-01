# Sendient Claude — Windows Installer (PowerShell)
# Usage: irm https://raw.githubusercontent.com/Sendient/company-claude/main/install.ps1 | iex
#    or: pwsh ./install.ps1              (from inside the repo)
#
# What this does:
#   1. Checks for (or installs) Claude Code (native installer)
#   2. Checks for (or installs) the `run` task runner
#   3. Installs the sendient-claude wrapper as "claude.cmd" in ~/.sendient/bin
#   4. Configures MCP runtool + Playwright servers in ~/.claude.json
#   5. Adds ~/.sendient/bin to User PATH (persistent)
#   6. Auto-allows runtool + Playwright MCP tools in ~/.claude/settings.json
#   7. Installs Runfile tasks (company_claude:*) to ~/.runfile
#   8. Clones SREE repo and runs global install (skip with -NoSree)

# Parse flags
param(
    [switch]$NoSree
)

$ErrorActionPreference = 'Stop'

$InstallDir = if ($env:SENDIENT_INSTALL_DIR) { $env:SENDIENT_INSTALL_DIR } else { Join-Path $env:USERPROFILE '.sendient\bin' }
$WrapperName = 'claude.cmd'

# File URLs — set these to gist raw URLs for no-auth installs
$RepoRawUrl = if ($env:SENDIENT_REPO_URL) { $env:SENDIENT_REPO_URL } else { 'https://raw.githubusercontent.com/Sendient/company-claude/main' }
$UrlWrapper = if ($env:SENDIENT_URL_WRAPPER) { $env:SENDIENT_URL_WRAPPER } else { 'https://gist.githubusercontent.com/MichaelJarvisSendient/d07007a35bfd873c07790467fbedeca5/raw/sendient-claude.cmd' }
$UrlRunfile = if ($env:SENDIENT_URL_RUNFILE) { $env:SENDIENT_URL_RUNFILE } else { 'https://gist.githubusercontent.com/MichaelJarvisSendient/a7f2ebc6d337391d102e5c2febce1200/raw/Runfile' }

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

$nativeClaude = Join-Path $env:USERPROFILE '.local\bin\claude.exe'

if (Test-Path $nativeClaude) {
    $claudeVersion = try { & $nativeClaude --version 2>$null } catch { 'unknown' }
    Write-Ok "Claude Code found — native ($claudeVersion)"
} elseif (Get-Command claude -ErrorAction SilentlyContinue) {
    $claudeVersion = try { & claude --version 2>$null } catch { 'unknown' }
    Write-Warn "Claude Code found ($claudeVersion) but not native — migrating..."
    & claude install
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
    Write-Ok 'Migrated to native installer'
} else {
    Write-Info 'Claude Code not found — installing via native installer...'
    try {
        & ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1)))
        $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
        Write-Ok 'Claude Code installed (native)'
    } catch {
        Write-Fail "Native installer failed. Install Claude Code manually:`n     https://code.claude.com/docs/setup"
    }
}

# Clean up old npm install if present (leaves shims that cause warnings)
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if ($npmCmd) {
    $npmList = try { & npm list -g @anthropic-ai/claude-code 2>$null } catch { $null }
    if ($npmList -and $npmList -notmatch 'empty') {
        Write-Info 'Removing old npm-installed Claude Code...'
        try {
            & npm uninstall -g @anthropic-ai/claude-code 2>$null
            Write-Ok 'npm Claude Code removed'
        } catch {
            Write-Warn 'npm uninstall failed — you may want to remove it manually'
        }
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
        # Playwright MCP
        if ($config.mcpServers.PSObject.Properties.Name -contains 'playwright') {
            Write-Ok 'playwright MCP server already configured'
        } else {
            $playwrightConfig = [PSCustomObject]@{
                type = 'http'
                url  = 'http://localhost:8931/mcp'
            }
            $config.mcpServers | Add-Member -NotePropertyName 'playwright' -NotePropertyValue $playwrightConfig
            $config | ConvertTo-Json -Depth 10 | Set-Content $claudeJson -Encoding UTF8
            Write-Ok 'playwright MCP server added to ~/.claude.json'
        }
    } catch {
        Write-Warn "Could not parse ~/.claude.json — skipping MCP config. Error: $_"
    }
} else {
    Write-Warn '~/.claude.json not found — skipping MCP config (will be created on first claude run)'
}

# ── Step 5b: Configure global settings permissions ───────────────────

$settingsJson = Join-Path $env:USERPROFILE '.claude\settings.json'
$mcpPerms = @('mcp__runtool__*', 'mcp__playwright__*')

if (Test-Path $settingsJson) {
    try {
        $settings = Get-Content $settingsJson -Raw | ConvertFrom-Json

        # Ensure permissions.allow exists
        if (-not ($settings.PSObject.Properties.Name -contains 'permissions')) {
            $settings | Add-Member -NotePropertyName 'permissions' -NotePropertyValue ([PSCustomObject]@{ allow = @() })
        } elseif (-not ($settings.permissions.PSObject.Properties.Name -contains 'allow')) {
            $settings.permissions | Add-Member -NotePropertyName 'allow' -NotePropertyValue @()
        }

        $changed = $false
        foreach ($perm in $mcpPerms) {
            if ($settings.permissions.allow -contains $perm) {
                Write-Ok "$perm already in allow list"
            } else {
                $settings.permissions.allow = @($settings.permissions.allow) + $perm
                Write-Ok "$perm added to ~/.claude/settings.json"
                $changed = $true
            }
        }
        if ($changed) {
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsJson -Encoding UTF8
        }
    } catch {
        Write-Warn "Could not parse ~/.claude/settings.json — skipping. Error: $_"
    }
} else {
    $settingsDir = Split-Path $settingsJson
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    $newSettings = [PSCustomObject]@{
        permissions = [PSCustomObject]@{
            allow = $mcpPerms
        }
    }
    $newSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsJson -Encoding UTF8
    Write-Ok 'Created ~/.claude/settings.json with MCP permissions'
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

# ── Step 7: Install SREE framework (global) ──────────────────────────

$SreeCache = Join-Path $env:USERPROFILE '.sendient\sree'
$SreeRepo = 'git@github.com:Sendient/sree.git'

if ($NoSree) {
    Write-Info 'Skipping SREE install (-NoSree)'
} elseif (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn 'git not found — skipping SREE install'
} else {
    Write-Info 'Installing SREE framework...'
    $sreeGitDir = Join-Path $SreeCache '.git'

    if (Test-Path $sreeGitDir) {
        try {
            & git -C $SreeCache pull --ff-only 2>$null
            Write-Ok 'SREE repo updated'
        } catch {
            Write-Warn 'SREE pull failed — using cached version'
        }
    } else {
        $sreeParent = Split-Path $SreeCache
        if (-not (Test-Path $sreeParent)) {
            New-Item -ItemType Directory -Path $sreeParent -Force | Out-Null
        }
        try {
            & git clone --depth 1 $SreeRepo $SreeCache 2>$null
            Write-Ok 'SREE repo cloned'
        } catch {
            Write-Warn 'Could not clone SREE repo — skipping (check SSH key / git access)'
        }
    }

    $sreeInstallScript = Join-Path $SreeCache 'scripts\install-sree.sh'
    if (Test-Path $sreeInstallScript) {
        $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
        if ($bashCmd) {
            'y' | & bash $sreeInstallScript global
            Write-Ok 'SREE global install complete'
        } else {
            Write-Warn 'bash not found — cannot run SREE install script. Install Git Bash or WSL.'
        }
    } elseif (Test-Path $sreeGitDir) {
        Write-Warn "SREE install script not found at $sreeInstallScript"
    }
}

# ── Step 8: Verify ───────────────────────────────────────────────────

Write-Host ''
$resolvedClaude = Get-Command claude -ErrorAction SilentlyContinue
if ($resolvedClaude -and $resolvedClaude.Source -eq $WrapperPath) {
    Write-Ok "All done! Running 'claude' will now show the Sendient SREE banner."
} else {
    Write-Ok "Wrapper installed at $WrapperPath"
    $inPath = $env:Path.Split(';') -contains $InstallDir
    if ($inPath) {
        Write-Ok "$InstallDir is in PATH (another 'claude' may take priority depending on PATH order)"
    } else {
        Write-Warn "$InstallDir is not in PATH — you may need to restart your terminal."
    }
}
Write-Host ''
