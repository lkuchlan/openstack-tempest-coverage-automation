#!/bin/bash
# Setup script for OpenStack Tempest Coverage Automation
#
# This script installs the Claude Code skills by creating symlinks
# to your ~/.claude/skills/ directory.
#
# Usage:
#   git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
#   cd openstack-tempest-coverage-automation
#   ./scripts/setup.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 OpenStack Tempest Coverage Automation - Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check Claude Code installation
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v claude &> /dev/null; then
    echo -e "${RED}❌ Claude Code not found${NC}"
    echo ""
    echo -e "${YELLOW}Please install Claude Code first:${NC}"
    echo -e "${YELLOW}  Visit: https://claude.ai/code${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Claude Code is installed"

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  Python 3 not found (required for tox validation)${NC}"
else
    echo -e "${GREEN}✓${NC} Python 3 is installed"
fi

echo ""

# Create skills directory
SKILLS_DIR="$HOME/.claude/skills"
echo -e "${BLUE}Installing skills to: ${YELLOW}$SKILLS_DIR${NC}"

mkdir -p "$SKILLS_DIR"
echo -e "${GREEN}✓${NC} Skills directory ready"

# Install skills via symlinks
echo ""
echo -e "${BLUE}📦 Installing skills...${NC}"

# Analysis skill
if [ -d "$REPO_ROOT/skills/jira-coverage-analysis" ]; then
    ln -sf "$REPO_ROOT/skills/jira-coverage-analysis" "$SKILLS_DIR/jira-coverage-analysis"
    echo -e "${GREEN}✓${NC} jira-coverage-analysis"
else
    # Check .claude/skills location (during development)
    if [ -d "$REPO_ROOT/.claude/skills/jira-coverage-analysis" ]; then
        ln -sf "$REPO_ROOT/.claude/skills/jira-coverage-analysis" "$SKILLS_DIR/jira-coverage-analysis"
        echo -e "${GREEN}✓${NC} jira-coverage-analysis"
    else
        echo -e "${YELLOW}⚠️  jira-coverage-analysis not found${NC}"
    fi
fi

# Implementation skill
if [ -d "$REPO_ROOT/skills/implement-tempest-tests" ]; then
    ln -sf "$REPO_ROOT/skills/implement-tempest-tests" "$SKILLS_DIR/implement-tempest-tests"
    echo -e "${GREEN}✓${NC} implement-tempest-tests"
else
    # Check .claude/skills location (during development)
    if [ -d "$REPO_ROOT/.claude/skills/implement-tempest-tests" ]; then
        ln -sf "$REPO_ROOT/.claude/skills/implement-tempest-tests" "$SKILLS_DIR/implement-tempest-tests"
        echo -e "${GREEN}✓${NC} implement-tempest-tests"
    else
        echo -e "${YELLOW}⚠️  implement-tempest-tests not found${NC}"
    fi
fi

# Shared config
if [ -d "$REPO_ROOT/skills/shared" ]; then
    ln -sf "$REPO_ROOT/skills/shared" "$SKILLS_DIR/tempest-coverage"
    echo -e "${GREEN}✓${NC} tempest-coverage (shared config)"
else
    # Check .claude/skills location (during development)
    if [ -d "$REPO_ROOT/.claude/skills/tempest-coverage" ]; then
        ln -sf "$REPO_ROOT/.claude/skills/tempest-coverage" "$SKILLS_DIR/tempest-coverage"
        echo -e "${GREEN}✓${NC} tempest-coverage (shared config)"
    else
        echo -e "${YELLOW}⚠️  tempest-coverage (shared config) not found${NC}"
    fi
fi

echo ""

# Copy example files
echo -e "${BLUE}📄 Setting up configuration...${NC}"

if [ ! -f "$REPO_ROOT/.env" ]; then
    if [ -f "$REPO_ROOT/examples/.env.example" ]; then
        cp "$REPO_ROOT/examples/.env.example" "$REPO_ROOT/.env"
        echo -e "${GREEN}✓${NC} Created .env file (EDIT THIS with your Jira credentials)"
    else
        echo -e "${YELLOW}⚠️  .env.example not found${NC}"
    fi
else
    echo -e "${YELLOW}✓${NC} .env already exists (not overwriting)"
fi

echo ""

# Prompt for basic config
echo -e "${BLUE}⚙️  Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Ask if user wants to configure now
read -p "Configure Tempest repository paths now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Path to Tempest repositories (default: ~/tempest-workspace): " REPO_PATH
    REPO_PATH=${REPO_PATH:-~/tempest-workspace}

    # Expand tilde
    REPO_PATH="${REPO_PATH/#\~/$HOME}"

    if [ -d "$REPO_PATH" ]; then
        echo -e "${GREEN}✓${NC} Repository path: $REPO_PATH"
        # Note: Could update config.json here, but leaving for manual edit
    else
        echo -e "${YELLOW}⚠️  Directory not found: $REPO_PATH${NC}"
        echo -e "${YELLOW}   You can update this later in config.json${NC}"
    fi
fi

echo ""

# Validation
echo -e "${BLUE}🔍 Validating installation...${NC}"

VALIDATION_OK=true

if [ -d "$SKILLS_DIR/jira-coverage-analysis" ]; then
    echo -e "${GREEN}✓${NC} jira-coverage-analysis skill installed"
else
    echo -e "${RED}✗${NC} jira-coverage-analysis skill NOT found"
    VALIDATION_OK=false
fi

if [ -d "$SKILLS_DIR/implement-tempest-tests" ]; then
    echo -e "${GREEN}✓${NC} implement-tempest-tests skill installed"
else
    echo -e "${RED}✗${NC} implement-tempest-tests skill NOT found"
    VALIDATION_OK=false
fi

if [ -d "$SKILLS_DIR/tempest-coverage" ]; then
    echo -e "${GREEN}✓${NC} tempest-coverage (shared config) installed"
else
    echo -e "${RED}✗${NC} tempest-coverage (shared config) NOT found"
    VALIDATION_OK=false
fi

echo ""

if [ "$VALIDATION_OK" = true ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  Installation completed with warnings${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
fi

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}1. (Optional) Configure Jira integration:${NC}"
echo -e "   - Edit credentials: vi $REPO_ROOT/.env"
echo -e "   - Setup MCP server: See docs/JIRA_SETUP.md"
echo -e "   - Skills work without Jira (manual input mode)"
echo ""
echo -e "${YELLOW}2. (Optional) Update repository paths:${NC}"
echo -e "   vi $SKILLS_DIR/tempest-coverage/config.json"
echo ""
echo -e "${YELLOW}3. Test the skills:${NC}"
echo -e "   claude"
echo -e "   > ${BLUE}/jira-coverage-analysis --help${NC}"
echo -e "   > ${BLUE}/implement-tempest-tests --help${NC}"
echo ""

echo -e "${BLUE}📚 Documentation:${NC}"
echo -e "   README.md          - Main documentation"
echo -e "   docs/QUICKSTART.md - 5-minute guide"
echo -e "   CLAUDE.md          - OpenStack Tempest standards"
echo ""
echo -e "${BLUE}🎯 Quick Start Example:${NC}"
echo -e "   claude"
echo -e "   > ${BLUE}/jira-coverage-analysis OSPRH-22613${NC}"
echo ""
