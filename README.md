# Sendient Onboarding

Minimal public bootstrap scripts for setting up a Sendient developer environment.

## Quick Start

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- local
```

### Windows (PowerShell)

```powershell
iwr https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.ps1 -OutFile setup.ps1; .\setup.ps1
```

## Profiles

| Profile | Target | Command |
|---------|--------|---------|
| `local` | macOS / Linux / WSL dev workstation | `bash -s -- local [--with-repos]` |
| `agent-runner` | Headless agent VPS | `bash -s -- agent-runner [--multi-tenant]` |
| `cloud-box` | Cloud dev VPS | `bash -s -- cloud-box [--with-agent-runner]` |

## What happens

1. `setup.sh` authenticates with GitHub (guided token creation)
2. Clones `Sendient/developer-tools` (private)
3. Delegates to the selected profile's setup script

All tooling, wrapper scripts, and configuration live in `developer-tools`.
This repo is intentionally minimal so it can remain public.
