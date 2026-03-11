#!/usr/bin/env bash
# setup.sh — Unified bootstrap entry point for Sendient developer environments
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- <profile> [flags...]
#   bash setup.sh <profile> [flags...]
#   bash setup.sh --help
#   bash setup.sh              # interactive menu
#
# Profiles:
#   local          Product developer workstation (macOS / Linux / WSL)
#   agent-runner   Autonomous agent VPS (headless)
#   cloud-box      Cloud dev environment (Codespaces / cloud VPS)
#
# Examples:
#   curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- local
#   curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- agent-runner --multi-tenant
#   curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- cloud-box --with-agent-runner
#
# Distribution:
#   This is a copy of the canonical Sendient/developer-tools/setup.sh.
#   It lives in the public sendient-onboarding repo for unauthenticated
#   curl|bash access. Keep in sync with the canonical copy.
#
# Exit codes:
#   0  Success
#   1  Invalid argument or profile delegation failure
#   4  Missing prerequisite (git, gh, or gh auth)
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
readonly DEVELOPER_TOOLS_REPO="Sendient/developer-tools"
# Default workspace root — set per-profile in main() before use
SENDIENT_WORKSPACE="${SENDIENT_WORKSPACE:-}"
export SENDIENT_WORKSPACE
readonly VALID_PROFILES=("local" "agent-runner" "cloud-box")

# =============================================================================
# setup_print_usage — display help text
# Args:    none
# Returns: 0
# Side-effects: prints to stdout
# =============================================================================
setup_print_usage() {
  cat <<'USAGE'
Sendient Developer Platform Setup
==================================

Usage:
  setup.sh <profile> [flags...]
  setup.sh --help
  setup.sh                      (interactive menu)

Profiles:
  local          Product developer workstation (macOS / Linux / WSL)
  agent-runner   Autonomous agent VPS (headless)
  cloud-box      Cloud dev environment (Codespaces / cloud VPS)

Flags are forwarded to the profile setup script. Common flags:
  --multi-tenant       (agent-runner) Create multi-tenant worktrees
  --with-agent-runner  (cloud-box)    Include agent-runner components
  --with-repos         (local)        Clone product repos from manifest

Examples:
  curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- local --with-repos
  curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh | bash -s -- agent-runner --multi-tenant
  bash setup.sh cloud-box --with-agent-runner
USAGE
}

# =============================================================================
# setup_detect_os — detect the host operating system
# Args:    none
# Returns: 0; prints detected OS string to stdout
# Side-effects: none
# =============================================================================
setup_detect_os() {
  local uname_s
  uname_s="$(uname -s)"

  case "${uname_s}" in
    Darwin)
      echo "macos"
      ;;
    Linux)
      if [[ -f /proc/version ]] && grep -qi "microsoft" /proc/version; then
        echo "wsl"
      else
        echo "linux"
      fi
      ;;
    MINGW*|MSYS*)
      echo "[INFO] Git Bash detected - use PowerShell instead." >&2
      echo "" >&2
      echo "  Windows-native:  .\\setup.ps1 --native    (tools in PowerShell, repos at ~\\sendient)" >&2
      echo "  WSL:             .\\setup.ps1 --wsl       (tools inside WSL Ubuntu)" >&2
      echo "  Interactive:     .\\setup.ps1             (choose at prompt)" >&2
      echo "" >&2
      echo "  Download setup.ps1:" >&2
      echo "    Invoke-WebRequest -Uri https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.ps1 -OutFile setup.ps1" >&2
      exit 1
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# =============================================================================
# setup_check_prerequisites — verify git and gh are available and authenticated
# Args:    none
# Returns: 0 on success; exits 4 on failure
# Side-effects: prints status messages
# =============================================================================
setup_check_prerequisites() {
  echo "[INFO] Checking prerequisites..."

  if ! command -v git >/dev/null 2>&1; then
    echo "[FAIL] git is not installed." >&2
    echo "       Install git: https://git-scm.com/downloads" >&2
    exit 4
  fi
  echo "[OK]   git found: $(git --version)"

  if ! command -v gh >/dev/null 2>&1; then
    echo "[FAIL] GitHub CLI (gh) is not installed." >&2
    echo "       Install gh: https://cli.github.com/" >&2
    exit 4
  fi
  echo "[OK]   gh found: $(gh --version | head -n1)"

  if ! gh auth status >/dev/null 2>&1; then
    echo "[INFO] GitHub CLI is not authenticated."
    echo ""
    echo "  1. Open this link to create a personal access token with the required scopes:"
    echo ""
    echo "     https://github.com/settings/tokens/new?scopes=repo,read:org,workflow&description=sendient-dev-setup"
    echo ""
    echo "  2. Set expiration to 90 days (recommended), then click 'Generate token' and copy it."
    echo ""

    if [[ -t 0 ]] || [[ -r /dev/tty ]]; then
      echo -n "  3. Paste your token here: "
      read -r gh_token </dev/tty

      if [[ -z "${gh_token}" ]]; then
        echo "[FAIL] No token provided." >&2
        exit 4
      fi

      if printf '%s\n' "${gh_token}" | gh auth login --with-token 2>&1; then
        echo "[OK]   GitHub CLI authenticated via token"
      else
        echo "[FAIL] Token authentication failed." >&2
        exit 4
      fi
    else
      echo "[FAIL] Non-interactive: set GH_TOKEN env var or run 'gh auth login' first." >&2
      exit 4
    fi
  else
    echo "[OK]   gh is authenticated"
  fi

  # Configure gh as git credential helper so git pull/push work without prompts
  gh auth setup-git 2>/dev/null || true
}

# =============================================================================
# setup_ensure_developer_tools — clone or update the developer-tools repo
# Args:    none
# Returns: 0 on success; exits 1 on clone failure
# Side-effects: clones or pulls developer-tools into /workspace/developer-tools
# =============================================================================
setup_ensure_developer_tools() {
  local dev_tools_path="${SENDIENT_WORKSPACE}/developer-tools"

  if [[ -d "${dev_tools_path}/.git" ]]; then
    echo "[INFO] developer-tools found at ${dev_tools_path} — updating..."
    if git -C "${dev_tools_path}" pull --ff-only 2>&1; then
      echo "[OK]   developer-tools updated"
    else
      echo "[WARN] developer-tools pull failed — continuing with existing version"
    fi
  else
    echo "[INFO] Cloning developer-tools to ${dev_tools_path}..."

    # Ensure workspace directory exists and is writable
    if [[ ! -d "${SENDIENT_WORKSPACE}" ]]; then
      echo "[INFO] Creating ${SENDIENT_WORKSPACE} directory..."
      mkdir -p "${SENDIENT_WORKSPACE}" 2>/dev/null || {
        sudo mkdir -p "${SENDIENT_WORKSPACE}"
        sudo chown "$(id -u):$(id -g)" "${SENDIENT_WORKSPACE}"
      }
    elif [[ ! -w "${SENDIENT_WORKSPACE}" ]]; then
      echo "[INFO] Fixing ownership on ${SENDIENT_WORKSPACE}..."
      sudo chown "$(id -u):$(id -g)" "${SENDIENT_WORKSPACE}"
    fi

    if gh repo clone "${DEVELOPER_TOOLS_REPO}" "${dev_tools_path}" 2>&1; then
      echo "[OK]   developer-tools cloned to ${dev_tools_path}"
    else
      echo "[FAIL] Could not clone developer-tools" >&2
      exit 1
    fi
  fi
}

# =============================================================================
# setup_validate_profile — check that the given profile name is valid
# Args:    $1 — profile name
# Returns: 0 if valid; 1 if invalid
# Side-effects: none
# =============================================================================
setup_validate_profile() {
  local profile="${1}"
  local valid
  for valid in "${VALID_PROFILES[@]}"; do
    if [[ "${profile}" == "${valid}" ]]; then
      return 0
    fi
  done
  return 1
}

# =============================================================================
# setup_interactive_menu — display profile selection menu and read choice
# Args:    none
# Returns: 0; prints selected profile name to stdout
# Side-effects: reads from /dev/tty for interactive input
# =============================================================================
setup_interactive_menu() {
  cat >&2 <<'MENU'

Sendient Developer Platform Setup
==================================
1) local          — Product developer workstation
2) agent-runner   — Autonomous agent VPS
3) cloud-box      — Cloud dev environment (Codespaces / cloud VPS)

MENU

  local choice=""
  while true; do
    printf 'Select profile [1-3]: ' >&2
    if ! read -r choice </dev/tty; then
      echo "[FAIL] Could not read input — stdin is not a terminal." >&2
      echo "       Provide a profile argument: setup.sh <profile>" >&2
      exit 1
    fi

    case "${choice}" in
      1) echo "local";        return 0 ;;
      2) echo "agent-runner";  return 0 ;;
      3) echo "cloud-box";    return 0 ;;
      *)
        echo "[WARN] Invalid selection: ${choice}. Please enter 1, 2, or 3." >&2
        ;;
    esac
  done
}

# =============================================================================
# setup_delegate — hand off execution to the profile-specific setup script
# Args:    $1 — profile name, $@ (remaining) — flags to forward
# Returns: does not return (uses exec)
# Side-effects: replaces current process with profile setup script
# =============================================================================
setup_delegate() {
  local profile="${1}"
  shift

  local profile_script="${SENDIENT_WORKSPACE}/developer-tools/profiles/${profile}/setup.sh"

  if [[ ! -f "${profile_script}" ]]; then
    echo "[FAIL] Profile script not found: ${profile_script}" >&2
    exit 1
  fi

  if [[ ! -x "${profile_script}" ]]; then
    chmod +x "${profile_script}"
  fi

  echo "[INFO] Delegating to ${profile} profile setup..."
  echo ""
  # Redirect stdin from /dev/tty so the profile script can prompt interactively
  # even when the onboarding script was piped via curl | bash
  exec "${profile_script}" "$@" </dev/tty
}

# =============================================================================
# main — entry point; wrapped in a function for safe curl|bash usage
# Args:    "$@" — all command-line arguments
# Returns: 0 on success; various non-zero on failure
# Side-effects: orchestrates the full bootstrap flow
# =============================================================================
main() {
  # Handle --help
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    setup_print_usage
    exit 0
  fi

  local detected_os
  detected_os="$(setup_detect_os)"

  echo "Sendient Developer Platform Setup"
  echo "=================================="
  echo "[INFO] Detected OS: ${detected_os}"
  echo ""

  # Determine profile — from argument or interactive menu
  local profile=""
  if [[ $# -ge 1 ]]; then
    profile="${1}"
    shift

    if ! setup_validate_profile "${profile}"; then
      echo "[FAIL] Unknown profile: ${profile}" >&2
      echo "       Valid profiles: ${VALID_PROFILES[*]}" >&2
      exit 1
    fi
  else
    profile="$(setup_interactive_menu)"
  fi

  echo "[INFO] Selected profile: ${profile}"
  echo ""

  # Set workspace root based on profile (if not already set via env)
  if [[ -z "${SENDIENT_WORKSPACE}" ]]; then
    if [[ "${profile}" == "agent-runner" ]]; then
      SENDIENT_WORKSPACE="/workspace"
    else
      SENDIENT_WORKSPACE="${HOME}/sendient"
    fi
    export SENDIENT_WORKSPACE
  fi
  echo "[INFO] Workspace: ${SENDIENT_WORKSPACE}"

  # Ensure SENDIENT_HOME exists (framework/tooling repos location)
  export SENDIENT_HOME="${SENDIENT_HOME:-${HOME}/.sendient}"
  mkdir -p "${SENDIENT_HOME}"

  # Check prerequisites
  setup_check_prerequisites
  echo ""

  # Ensure developer-tools is available
  setup_ensure_developer_tools
  echo ""

  # Delegate to profile setup script (does not return — uses exec)
  setup_delegate "${profile}" "$@"
}

# Wrapping in main() ensures the entire script is downloaded before execution
# when piped via curl. Without this, a partial download could execute incomplete
# commands.
main "$@"
