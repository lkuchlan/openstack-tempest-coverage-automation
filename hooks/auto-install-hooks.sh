#!/bin/bash
# Auto-install Tempest pre-commit hooks when Claude enters a Tempest repository
#
# This script is designed to be called from Claude Code's PreToolUse hook.
# It detects if the current directory is a Tempest plugin repository and
# automatically installs the pre-commit hooks if they're not already installed.
#
# Usage (from settings.json):
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{
#         "type": "command",
#         "command": "~/.claude/skills/tempest-coverage/auto-install-hooks.sh"
#       }]
#     }]
#   }
# }

set -e

# Determine the hooks directory
# Try to find it relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    # Not in a git repo, nothing to do
    exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

# Check if hooks already installed
if [ -f "$REPO_ROOT/.git/hooks/pre-commit" ]; then
    # Check if it's our hook (look for signature)
    if grep -q "OpenStack Tempest test standards" "$REPO_ROOT/.git/hooks/pre-commit" 2>/dev/null; then
        # Our hooks already installed, nothing to do
        exit 0
    fi
fi

# Detect if this is a Tempest repository
IS_TEMPEST_REPO=false

# Check 1: Directory name contains "tempest"
if [[ "$(basename "$REPO_ROOT")" == *tempest* ]]; then
    IS_TEMPEST_REPO=true
fi

# Check 2: Has tempest-related directories
if [ -d "$REPO_ROOT/tempest" ] || \
   [ -d "$REPO_ROOT/tempest_tests" ] || \
   [ -d "$REPO_ROOT/tempest_plugin" ] || \
   ls -d "$REPO_ROOT"/*tempest* 2>/dev/null | grep -q .; then
    IS_TEMPEST_REPO=true
fi

# Check 3: setup.cfg mentions tempest
if [ -f "$REPO_ROOT/setup.cfg" ]; then
    if grep -q "tempest" "$REPO_ROOT/setup.cfg"; then
        IS_TEMPEST_REPO=true
    fi
fi

# Check 4: Has test files matching test_*.py pattern in common locations
if find "$REPO_ROOT" -maxdepth 3 -name "test_*.py" 2>/dev/null | grep -q .; then
    IS_TEMPEST_REPO=true
fi

# If not a Tempest repo, exit silently
if [ "$IS_TEMPEST_REPO" = false ]; then
    exit 0
fi

# This is a Tempest repo and hooks are not installed - install them
# Use the install-hooks.sh script
if [ -f "$SCRIPT_DIR/install-hooks.sh" ]; then
    # Run installation silently
    cd "$REPO_ROOT"
    "$SCRIPT_DIR/install-hooks.sh" --silent 2>/dev/null || true

    # Output JSON for Claude Code to indicate hooks were installed
    cat << EOF
{
  "systemMessage": "Auto-installed Tempest pre-commit hooks in $(basename "$REPO_ROOT")"
}
EOF
else
    # Hooks installer not found, exit silently
    exit 0
fi
