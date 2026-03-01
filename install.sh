#!/usr/bin/env bash
# Sendient Claude — Installer
# Usage: curl -fsSL <url>/install.sh | bash
#    or: ./install.sh              (from inside the repo)
#
# What this does:
#   1. Checks for (or installs) Claude Code
#   2. Checks for (or installs) the `run` task runner
#   3. Installs the sendient-claude wrapper as "claude" in ~/.sendient/bin
#      (a dedicated directory that takes PATH priority over the real claude)
#   4. Configures MCP runtool server in ~/.claude.json
#   5. Installs Runfile tasks (company_claude:*) to ~/.runfile
#   6. Clones SREE repo and runs global install (skip with --no-sree)

set -euo pipefail

# Parse flags
NO_SREE=false
for arg in "$@"; do
  case "$arg" in
    --no-sree) NO_SREE=true ;;
  esac
done

INSTALL_DIR="${SENDIENT_INSTALL_DIR:-$HOME/.sendient/bin}"
WRAPPER_NAME="claude"

# File URLs — set these to gist raw URLs for no-auth installs, or leave
# unset to fall back to SENDIENT_REPO_URL + GITHUB_TOKEN.
REPO_RAW_URL="${SENDIENT_REPO_URL:-https://raw.githubusercontent.com/Sendient/company-claude/main}"
URL_WRAPPER="${SENDIENT_URL_WRAPPER:-https://gist.githubusercontent.com/MichaelJarvisSendient/63c13dab54a26595d05e9f041a943679/raw/sendient-claude}"
URL_RUNFILE="${SENDIENT_URL_RUNFILE:-https://gist.githubusercontent.com/MichaelJarvisSendient/a7f2ebc6d337391d102e5c2febce1200/raw/Runfile}"

# Auth for private repo — only needed when fetching from raw.githubusercontent.com
CURL_AUTH=()
WGET_AUTH=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  CURL_AUTH=(-H "Authorization: token $GITHUB_TOKEN")
  WGET_AUTH=(--header="Authorization: token $GITHUB_TOKEN")
fi

# Detect if running from inside the repo (local mode) vs curl pipe (remote mode)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/sendient-claude" ]; then
  LOCAL_MODE=true
else
  LOCAL_MODE=false
fi

info()  { printf '  \033[1;36m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[1;33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ── Step 0: Pre-flight ──────────────────────────────────────────────

printf '\n\033[1mSendient Claude — Installer\033[0m\n\n'

if ! $LOCAL_MODE && [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${SENDIENT_URL_WRAPPER:-}" ]; then
  fail "GITHUB_TOKEN is required for remote installs from private repo.\n     Export it first: export GITHUB_TOKEN=ghp_...\n     Or set SENDIENT_URL_WRAPPER / SENDIENT_URL_RUNFILE to gist raw URLs."
fi

# ── Step 1: Ensure Claude Code is installed ─────────────────────────

if command -v claude >/dev/null 2>&1; then
  CLAUDE_VERSION="$(claude --version 2>/dev/null || echo "unknown")"
  ok "Claude Code found ($CLAUDE_VERSION)"
else
  info "Claude Code not found — installing via npm..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g @anthropic-ai/claude-code
    ok "Claude Code installed"
  else
    fail "npm not found. Install Node.js/npm first, or install Claude Code manually:\n     https://docs.anthropic.com/en/docs/claude-code"
  fi
fi

# ── Step 2: Ensure `run` task runner is installed ───────────────────

if command -v run >/dev/null 2>&1; then
  ok "run tool found ($(run --version 2>/dev/null || echo 'unknown'))"
else
  info "run tool not found — installing..."
  if command -v scoop >/dev/null 2>&1; then
    scoop install run
    ok "run tool installed via scoop"
  elif command -v brew >/dev/null 2>&1; then
    brew install run
    ok "run tool installed via homebrew"
  elif command -v cargo >/dev/null 2>&1; then
    cargo install run
    ok "run tool installed via cargo"
  else
    info "No package manager found. Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    . "$HOME/.cargo/env"
    cargo install run
    ok "run tool installed via cargo (Rust toolchain installed)"
  fi
fi

# ── Step 3: Install wrapper script ───────────────────────────────────

mkdir -p "$INSTALL_DIR"

WRAPPER_PATH="$INSTALL_DIR/$WRAPPER_NAME"

# Safety: refuse to overwrite a real claude binary (not our wrapper)
if [ -f "$WRAPPER_PATH" ] && ! grep -q 'sendient-claude' "$WRAPPER_PATH" 2>/dev/null; then
  fail "$WRAPPER_PATH exists and is not the Sendient wrapper. Aborting to avoid overwriting Claude Code."
fi

info "Installing wrapper to $WRAPPER_PATH"

if $LOCAL_MODE; then
  cp "$SCRIPT_DIR/sendient-claude" "$WRAPPER_PATH"
  ok "Wrapper installed (from local repo)"
else
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${CURL_AUTH[@]}" "$URL_WRAPPER" -o "$WRAPPER_PATH"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$WRAPPER_PATH" "${WGET_AUTH[@]}" "$URL_WRAPPER"
  else
    fail "Neither curl nor wget found."
  fi
  ok "Wrapper installed (downloaded)"
fi

chmod +x "$WRAPPER_PATH"

# ── Step 4: Ensure ~/.sendient/bin is in PATH (before claude) ───────

add_to_path() {
  local shell_rc="$1"
  local line="export PATH=\"$INSTALL_DIR:\$PATH\""
  if [ -f "$shell_rc" ] && grep -qF "$INSTALL_DIR" "$shell_rc"; then
    return 0
  fi
  printf '\n# Sendient Claude wrapper\n%s\n' "$line" >> "$shell_rc"
  warn "Added $INSTALL_DIR to PATH in $shell_rc — restart your shell or run:"
  printf '       source %s\n' "$shell_rc"
}

case "${PATH:-}" in
  *"$INSTALL_DIR"*) ok "$INSTALL_DIR already in PATH" ;;
  *)
    info "Adding $INSTALL_DIR to PATH..."
    case "${SHELL:-/bin/bash}" in
      */zsh)  add_to_path "$HOME/.zshrc" ;;
      */bash) add_to_path "$HOME/.bashrc" ;;
      *)      add_to_path "$HOME/.profile" ;;
    esac
    export PATH="$INSTALL_DIR:$PATH"
    ;;
esac

# ── Step 5: Configure MCP runtool server ────────────────────────────

CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$CLAUDE_JSON" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.mcpServers.runtool' "$CLAUDE_JSON" >/dev/null 2>&1; then
    ok "runtool MCP server already configured"
  else
    tmpfile=$(mktemp)
    jq '.mcpServers.runtool = {"command": "run", "args": ["--serve-mcp"]}' "$CLAUDE_JSON" > "$tmpfile" && mv "$tmpfile" "$CLAUDE_JSON"
    ok "runtool MCP server added to ~/.claude.json"
  fi
elif [ ! -f "$CLAUDE_JSON" ]; then
  warn "~/.claude.json not found — skipping MCP config (will be created on first claude run)"
else
  warn "jq not found — skipping MCP config. Add runtool manually."
fi

# ── Step 6: Install Runfile tasks to ~/.runfile ──────────────────────

GLOBAL_RUNFILE="$HOME/.runfile"
BEGIN_MARKER="# ── BEGIN company_claude ──"
END_MARKER="# ── END company_claude ──"

# Extract our block from the source Runfile (local mode only)
if $LOCAL_MODE && [ -f "$SCRIPT_DIR/Runfile" ]; then
  OUR_BLOCK=$(sed -n "/^${BEGIN_MARKER}/,/^${END_MARKER}/p" "$SCRIPT_DIR/Runfile")
elif ! $LOCAL_MODE; then
  # Download Runfile from remote
  if command -v curl >/dev/null 2>&1; then
    OUR_BLOCK=$(curl -fsSL "${CURL_AUTH[@]}" "$URL_RUNFILE" | sed -n "/^${BEGIN_MARKER}/,/^${END_MARKER}/p")
  elif command -v wget >/dev/null 2>&1; then
    OUR_BLOCK=$(wget -qO- "${WGET_AUTH[@]}" "$URL_RUNFILE" | sed -n "/^${BEGIN_MARKER}/,/^${END_MARKER}/p")
  fi
fi

if [ -z "${OUR_BLOCK:-}" ]; then
  warn "Could not extract company_claude block from Runfile — skipping"
elif [ ! -f "$GLOBAL_RUNFILE" ]; then
  printf '%s\n' "$OUR_BLOCK" > "$GLOBAL_RUNFILE"
  ok "Runfile tasks installed to $GLOBAL_RUNFILE"
elif grep -qF "$BEGIN_MARKER" "$GLOBAL_RUNFILE"; then
  # Replace existing block: write new block to temp, then swap via sed
  block_file=$(mktemp)
  printf '%s\n' "$OUR_BLOCK" > "$block_file"
  tmpfile=$(mktemp)
  sed -e "/^${BEGIN_MARKER}/,/^${END_MARKER}/{ /^${BEGIN_MARKER}/{
    r $block_file
  }; d; }" "$GLOBAL_RUNFILE" > "$tmpfile" && mv "$tmpfile" "$GLOBAL_RUNFILE"
  rm -f "$block_file"
  ok "Runfile tasks updated in $GLOBAL_RUNFILE"
else
  # Append our block
  printf '\n%s\n' "$OUR_BLOCK" >> "$GLOBAL_RUNFILE"
  ok "Runfile tasks appended to $GLOBAL_RUNFILE"
fi

# ── Step 7: Install SREE framework (global) ────────────────────────

SREE_CACHE="$HOME/.sendient/sree"
SREE_REPO="git@github.com:Sendient/sree.git"

if $NO_SREE; then
  info "Skipping SREE install (--no-sree)"
elif ! command -v git >/dev/null 2>&1; then
  warn "git not found — skipping SREE install"
else
  info "Installing SREE framework..."
  if [ -d "$SREE_CACHE/.git" ]; then
    git -C "$SREE_CACHE" pull --ff-only 2>/dev/null && ok "SREE repo updated" || warn "SREE pull failed — using cached version"
  else
    mkdir -p "$(dirname "$SREE_CACHE")"
    if git clone --depth 1 "$SREE_REPO" "$SREE_CACHE" 2>/dev/null; then
      ok "SREE repo cloned"
    else
      warn "Could not clone SREE repo — skipping (check SSH key / git access)"
    fi
  fi

  if [ -f "$SREE_CACHE/scripts/install-sree.sh" ]; then
    bash "$SREE_CACHE/scripts/install-sree.sh" global
    ok "SREE global install complete"
  elif [ -d "$SREE_CACHE/.git" ]; then
    warn "SREE install script not found at $SREE_CACHE/scripts/install-sree.sh"
  fi
fi

# ── Step 8: Verify ──────────────────────────────────────────────────

printf '\n'
RESOLVED="$(command -v claude 2>/dev/null || true)"
if [ "$RESOLVED" = "$WRAPPER_PATH" ]; then
  ok "All done! Running 'claude' will now show the Sendient SREE banner."
else
  ok "Wrapper installed at $WRAPPER_PATH"
  warn "Your shell may resolve a different 'claude' first ($RESOLVED)."
  warn "Ensure $INSTALL_DIR appears before $(dirname "${RESOLVED:-/usr/local/bin/claude}") in your PATH."
fi
printf '\n'
