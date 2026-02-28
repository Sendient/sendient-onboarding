# Company Claude

![SREE banner](docs/banner.png)

Wrapper and tooling for running Claude Code with the Sendient SREE methodology banner and [`run`](https://github.com/nihilok/run) task runner integration.

## Quick install

> **Private repo** — you need a GitHub personal access token with `repo` scope.
> Create one at https://github.com/settings/tokens and export it:
>
> ```sh
> export GITHUB_TOKEN=ghp_...
> ```

**macOS / Linux:**

```sh
# From the repo (no token needed)
./install.sh

# Remote
curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
  https://raw.githubusercontent.com/Sendient/company-claude/main/install.sh \
  | GITHUB_TOKEN="$GITHUB_TOKEN" bash
```

**Windows (PowerShell):**

```powershell
# From the repo (no token needed)
pwsh ./install.ps1

# Remote
$env:GITHUB_TOKEN = 'ghp_...'
$h = @{ Authorization = "token $env:GITHUB_TOKEN" }
irm https://raw.githubusercontent.com/Sendient/company-claude/main/install.ps1 -Headers $h | iex
```

The installer checks for (or installs) Claude Code and `run`, then:

1. Copies the `sendient-claude` wrapper to `~/.sendient/bin/claude`
2. Prepends `~/.sendient/bin` to your PATH
3. Configures the `runtool` MCP server in `~/.claude.json`
4. Installs Runfile tasks to `~/.runfile`

## What you get

**Wrapper** — Running `claude` shows the SREE methodology banner before launching the real Claude Code binary. Non-interactive invocations (`--print`, `--json`, etc.) skip the banner.

**Runfile tasks** — Available globally via `run <task>`:

| Task | Description |
|------|-------------|
| `company_claude:install` | Fetch and run the remote installer (works from anywhere) |
| `company_claude:update` | Alias for `install` — re-runs the installer to update everything |
| `company_claude:doctor` | Health check — verifies Claude Code, `run`, wrapper, MCP, and epics directory |
| `company_claude:uninstall` | Remove the wrapper |
| `epic_search <id>` | Look up a Shortcut epic by number (e.g. `run epic_search 8894`) |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | *(required for remote)* | GitHub PAT for private repo access |
| `SENDIENT_INSTALL_DIR` | `~/.sendient/bin` | Where the wrapper is installed |
| `SENDIENT_EPICS_DIR` | *(required)* | Path to epic markdown files |
| `SENDIENT_EPICS_FILE` | *(required)* | Path to the epics index file |
| `SENDIENT_REPO_URL` | `https://raw.githubusercontent.com/Sendient/company-claude/main` | Override for remote installs |

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (installer will attempt `npm install` if missing)
- [`run`](https://github.com/nihilok/run) task runner (installer will attempt install if missing)
- `jq` (for MCP config)
