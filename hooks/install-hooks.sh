#!/bin/bash
# Install pre-commit hooks for OpenStack Tempest standards
#
# This script installs the Tempest pre-commit hooks into your
# Tempest plugin repository's .git/hooks/ directory.
#
# Usage:
#   cd ~/automation_projects/cinder-tempest-plugin
#   /path/to/openstack-tempest-coverage-automation/hooks/install-hooks.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

echo -e "${BLUE}🔧 Installing Tempest Pre-commit Hooks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if in git repository
if [ ! -d "$REPO_ROOT/.git" ]; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    echo -e "${YELLOW}   Run this script from your Tempest plugin repository:${NC}"
    echo -e "${YELLOW}   cd ~/automation_projects/cinder-tempest-plugin${NC}"
    echo -e "${YELLOW}   /path/to/openstack-tempest-coverage-automation/hooks/install-hooks.sh${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Git repository found: $REPO_ROOT"

# Create hooks directory if needed
mkdir -p "$REPO_ROOT/.git/hooks"
echo -e "${GREEN}✓${NC} Hooks directory ready"

# Copy or link pre-commit hook
if [ -f "$SCRIPT_DIR/pre-commit" ]; then
    cp "$SCRIPT_DIR/pre-commit" "$REPO_ROOT/.git/hooks/pre-commit"
    chmod +x "$REPO_ROOT/.git/hooks/pre-commit"
    echo -e "${GREEN}✓${NC} Pre-commit hook installed"
else
    echo -e "${RED}❌ Hook file not found: $SCRIPT_DIR/pre-commit${NC}"
    exit 1
fi

# Copy check scripts
if [ -d "$SCRIPT_DIR/checks" ]; then
    mkdir -p "$REPO_ROOT/.git/hooks/checks"
    cp "$SCRIPT_DIR/checks/"*.py "$REPO_ROOT/.git/hooks/checks/"
    chmod +x "$REPO_ROOT/.git/hooks/checks/"*.py
    echo -e "${GREEN}✓${NC} Check scripts installed (4 checks)"
else
    echo -e "${RED}❌ Checks directory not found: $SCRIPT_DIR/checks${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 Tempest pre-commit hooks installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}The hooks will check for:${NC}"
echo -e "  ${GREEN}✓${NC} Proper Tempest imports (no requests/urllib)"
echo -e "  ${GREEN}✓${NC} Base class usage (Tempest base classes)"
echo -e "  ${GREEN}✓${NC} Waiter usage (no time.sleep)"
echo -e "  ${GREEN}✓${NC} Cleanup patterns (addCleanup for resources)"
echo ""
echo -e "${BLUE}Testing:${NC}"
echo -e "  ${YELLOW}The hooks will run automatically on 'git commit'${NC}"
echo -e "  ${YELLOW}Test now:${NC} echo 'import time' > test_example.py && git add test_example.py && git commit -m 'test'"
echo ""
echo -e "${BLUE}Bypass hooks (NOT recommended):${NC}"
echo -e "  ${YELLOW}git commit --no-verify${NC}"
echo ""
echo -e "${BLUE}Uninstall:${NC}"
echo -e "  ${YELLOW}rm $REPO_ROOT/.git/hooks/pre-commit${NC}"
echo -e "  ${YELLOW}rm -rf $REPO_ROOT/.git/hooks/checks/${NC}"
echo ""
