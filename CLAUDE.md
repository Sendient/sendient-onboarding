# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Company Claude is a cross-platform wrapper and tooling system for running Claude Code with the Sendient SREE Framework banner. It distributes via secret GitHub gists so end users need no authentication. The project has no build step, tests, or linting — it's a collection of shell scripts, a Python banner, and a task runner configuration.

## Architecture

**Wrapper pattern:** `sendient-claude` (bash) and `sendient-claude.cmd` (batch) sit in `~/.sendient/bin/` as `claude`, taking PATH priority over the real binary. They display the SREE banner for interactive sessions then `exec` the real Claude with all arguments passed through.

**Distribution:** A GitHub Actions workflow (`.github/workflows/sync-gists.yml`) syncs 6 key files to secret gists on push to main. Gist URLs are stored as GitHub repo variables (`GIST_URL_*`). The custom action at `.github/actions/sync-file-to-gist/` handles creation and updates.

**Task runner:** The `Runfile` (800+ lines) defines tasks for the `run` tool, with dual bash/PowerShell implementations using `@os` and `@shell` annotations. Task namespaces: `company_claude:*` (install/update/doctor/uninstall), `epic_search`, `sree:*` (register/update/db/track/import/sync).

**SREE tracking DB:** SQLite at `~/.claude/sree/tracking.db` with tables for projects, phases, epics, stories, sessions, and my_epics. Created lazily by `sree:db`.

## Key Files

| File | Purpose |
|---|---|
| `install.sh` / `install.ps1` | Cross-platform installers (idempotent, re-runnable) |
| `sendient-claude` / `sendient-claude.cmd` | Wrapper scripts deployed as `claude` |
| `banner.py` | Pure Python terminal banner (zero deps, width-aware, respects `NO_COLOR`) |
| `Runfile` | Task runner definitions for `run --serve-mcp` (exposed as runtool MCP) |

## Development Patterns

- **Dual-OS support is mandatory.** Every installer/wrapper change needs both bash and PowerShell variants. The Runfile uses `@os linux,macos` / `@os windows` and `@shell bash` / `@shell pwsh` annotations.
- **Fallback chains everywhere.** Python: `python3` then `python`. Downloads: `curl` then `wget`. Tool installs: scoop/brew/cargo.
- **Banner is skipped** for non-interactive modes (`-p`, `--print`, `--json`, `--version`) and non-TTY contexts.
- **Gist sync is automatic** on push to main for changed files, but the CDN-cached `/raw/` URL can lag. Use `workflow_dispatch` to force a full sync.
- **SQL in Runfile tasks** uses heredocs with `sqlite3`. Schema changes go in the `sree:db` task's auto-create block.

## Environment Variables

| Variable | Purpose |
|---|---|
| `SENDIENT_EPICS_DIR` | Path to epic markdown files (required for `epic_search`) |
| `SENDIENT_EPICS_FILE` | Path to epics index file (required for `epic_search`) |
| `SENDIENT_INSTALL_DIR` | Override install dir (default: `~/.sendient/bin`) |
| `NO_COLOR` | Disable ANSI colours in banner |
| `GITHUB_TOKEN` | For private repo fallback (not needed with gist distribution) |
