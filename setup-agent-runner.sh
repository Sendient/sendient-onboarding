#!/usr/bin/env bash
# Interactive wrapper for agent-runner onboarding.
# Downloads and runs setup.sh with the agent-runner profile.
# PG defaults (host, user, database) are baked into the profile script;
# the password is prompted interactively by the profile if not provided.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup-agent-runner.sh | bash
set -euo pipefail

echo "=== Sendient Agent-Runner Setup ==="
echo ""
echo "This will set up an agent-runner VPS using the default PG configuration."
echo "You will be prompted for the PG password during setup."
echo ""

curl -fsSL https://raw.githubusercontent.com/Sendient/sendient-onboarding/main/setup.sh \
  | bash -s -- agent-runner
