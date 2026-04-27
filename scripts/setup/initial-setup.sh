#!/bin/bash
#
# Initial Setup Script for Claude Automation
#
# This script helps you set up the Tempest coverage skills for the first time.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "================================================"
echo "Claude Automation - Initial Setup"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check Claude Code is installed
echo "Step 1: Checking Claude Code installation..."
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓ Claude Code is installed${NC}"
    claude --version
else
    echo -e "${RED}✗ Claude Code is not installed${NC}"
    echo "Please install Claude Code from: https://claude.ai/code"
    exit 1
fi
echo ""

# Step 2: Check directory structure
echo "Step 2: Verifying directory structure..."
if [ -d "$PROJECT_ROOT/.claude/skills/jira-coverage-analysis" ]; then
    echo -e "${GREEN}✓ jira-coverage-analysis skill found${NC}"
else
    echo -e "${RED}✗ jira-coverage-analysis skill not found${NC}"
    exit 1
fi

if [ -d "$PROJECT_ROOT/.claude/skills/implement-tempest-tests" ]; then
    echo -e "${GREEN}✓ implement-tempest-tests skill found${NC}"
else
    echo -e "${RED}✗ implement-tempest-tests skill not found${NC}"
    exit 1
fi
echo ""

# Step 3: Check configuration file
echo "Step 3: Checking configuration..."
CONFIG_FILE="$PROJECT_ROOT/.claude/skills/tempest-coverage/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Configuration file exists${NC}"

    # Validate JSON
    if command -v jq &> /dev/null; then
        if jq empty "$CONFIG_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓ Configuration file is valid JSON${NC}"
        else
            echo -e "${RED}✗ Configuration file has invalid JSON${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}! jq not installed, skipping JSON validation${NC}"
    fi
else
    echo -e "${RED}✗ Configuration file not found${NC}"
    exit 1
fi
echo ""

# Step 4: Find Tempest repositories
echo "Step 4: Searching for Tempest repositories..."
echo "Running: $SCRIPT_DIR/../tempest/find-repos.sh"
bash "$SCRIPT_DIR/../tempest/find-repos.sh"
echo ""

# Step 5: Check optional dependencies
echo "Step 5: Checking optional dependencies..."

# Check tox
if command -v tox &> /dev/null; then
    echo -e "${GREEN}✓ tox is installed (for validation)${NC}"
else
    echo -e "${YELLOW}! tox is not installed (needed for test validation)${NC}"
    echo "  Install with: pip install tox"
fi

# Check git
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓ git is installed${NC}"
    # Check git config
    if git config user.name &> /dev/null && git config user.email &> /dev/null; then
        echo -e "${GREEN}✓ git is configured${NC}"
    else
        echo -e "${YELLOW}! git is not fully configured${NC}"
        echo "  Configure with:"
        echo "    git config --global user.name \"Your Name\""
        echo "    git config --global user.email \"your.email@example.com\""
    fi
else
    echo -e "${RED}✗ git is not installed${NC}"
    exit 1
fi

# Check jq (optional but useful)
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq is installed (for JSON processing)${NC}"
else
    echo -e "${YELLOW}! jq is not installed (optional, for JSON processing)${NC}"
    echo "  Install with: brew install jq (macOS) or apt-get install jq (Linux)"
fi
echo ""

# Step 6: Summary
echo "================================================"
echo "Setup Summary"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure repository paths:"
echo "   bash scripts/setup/configure-repos.sh"
echo ""
echo "2. (Optional) Set up Jira MCP integration:"
echo "   bash scripts/jira/setup-mcp.sh"
echo ""
echo "3. Test the skills:"
echo "   bash scripts/setup/test-skills.sh"
echo ""
echo "4. Start using:"
echo "   cd $PROJECT_ROOT"
echo "   claude"
echo "   /jira-coverage-analysis <ticket>"
echo "   /implement-tempest-tests <ticket>"
echo ""
echo -e "${GREEN}Setup verification complete!${NC}"
