# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sendient Onboarding is a minimal **public** repository containing bootstrap scripts for setting up Sendient developer environments. It exists solely to provide a stable, unauthenticated URL for `curl | bash` onboarding.

## Architecture

This repo contains only two scripts:

- **`setup.sh`** — Bash bootstrap for macOS, Linux, and WSL. Authenticates with GitHub, clones the private `Sendient/developer-tools` repo, and delegates to profile-specific setup scripts.
- **`setup.ps1`** — PowerShell bootstrap for Windows. Checks/installs WSL2, then delegates to `setup.sh` inside WSL.

All actual tooling (Claude wrapper, banner, Runfile tasks, profile setup scripts, SREE installation) lives in the private `Sendient/developer-tools` repository.

## Key Files

| File | Purpose |
|---|---|
| `setup.sh` | Bash entry point — profile selection, gh auth, clone developer-tools, delegate |
| `setup.ps1` | Windows entry point — WSL check/install, delegate to setup.sh |

## Conventions

- This repo is **public** — never commit secrets, tokens, or internal URLs.
- Changes to `setup.sh` should be mirrored in `developer-tools/setup.sh` (canonical copy).
- The repo is intentionally minimal. Resist adding implementation detail here.
