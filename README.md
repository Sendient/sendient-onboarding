# Sendient Onboarding

Minimal public bootstrap scripts for setting up a Sendient developer environment. Supports macOS, Linux, WSL, and Windows (native PowerShell).

## Quick Start

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- local
```

### Windows (PowerShell)

```powershell
iwr https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.ps1 -OutFile setup.ps1; .\setup.ps1
```

On Windows, `setup.ps1` offers two modes:

| Flag | What it does |
|------|-------------|
| `--native` | Installs tools in Windows (PowerShell, winget/scoop) — recommended for Claude Code and VS Code users |
| `--wsl` | Installs tools inside WSL Ubuntu |
| *(no flag)* | Interactive menu to choose |

```powershell
# Skip the menu — go straight to Windows-native setup
.\setup.ps1 --native

# Or with product repo cloning
.\setup.ps1 --native --with-repos
```

## Profiles

| Profile | Target | Command |
|---------|--------|---------|
| `local` | macOS / Linux / WSL dev workstation | `bash -s -- local [--with-repos]` |
| `local` | Windows-native dev workstation | `.\setup.ps1 --native [--with-repos]` |
| `agent-runner` | Headless agent VPS | `bash -s -- agent-runner [--multi-tenant]` |
| `cloud-box` | Cloud dev VPS | `bash -s -- cloud-box [--with-agent-runner]` |

## What Happens

1. Authenticates with GitHub CLI (guided token creation if needed)
2. Clones `Sendient/developer-tools` (private)
3. Delegates to the selected profile's setup script

The profile setup then installs:

- **Node.js and pnpm** — auto-installed via [Volta](https://volta.sh) on macOS/Linux/WSL; auto-upgraded when below minimum version
- **uv, ruff, pre-commit** — auto-installed (uv first, then ruff and pre-commit via uv)
- **Toolchain validation** — git, gh (required prerequisites); node, pnpm, uv, ruff, pre-commit, shellcheck (auto-installed or validated)
- **SREE lifecycle** — skills, agents, workflows, and engine
- **`run` task runner** — with automatic update checks
- **Claude Code wrapper** — `sendient-claude` command with SREE framework banner
- **MCP servers and tool permissions** — configured in `~/.claude.json` and `~/.claude/settings.json`
- **git-worktree-crypt** — for working with encrypted repos
- **Product repos** — optional (`--with-repos` flag)

**Keeping tools up to date:** Re-run the setup command at any time. It will upgrade node, pnpm, and the `run` tool if newer versions are available, and skip everything already current.

## Platform Support

| Entry Point | Platform | Result |
|------------|----------|--------|
| `curl \| bash setup.sh local` | macOS | Bash setup via brew |
| `curl \| bash setup.sh local` | Linux | Bash setup via apt |
| `curl \| bash setup.sh local` | WSL | Bash setup via apt |
| `.\setup.ps1 --native` | Windows | PowerShell setup via winget/scoop |
| `.\setup.ps1 --wsl` | Windows | Delegates to WSL bash setup |
| `.\setup.ps1` | Windows | Interactive choice |

All tooling, wrapper scripts, and configuration live in [`developer-tools`](https://github.com/Sendient/developer-tools).
This repo is intentionally minimal so it can remain public.
