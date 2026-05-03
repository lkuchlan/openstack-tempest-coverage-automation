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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Jira MCP Integration Setup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo -e "${BLUE}🔌 Jira MCP Integration Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Note: Skills work without Jira MCP (manual input mode)${NC}"
echo ""

read -p "Set up Jira MCP server for automatic ticket fetching? (y/N): " -n 1 -r
echo ""
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if uv is installed
    if ! command -v uv &> /dev/null; then
        echo -e "${RED}❌ uv is not installed (required for Jira MCP)${NC}"
        echo ""
        echo -e "${YELLOW}Install uv first:${NC}"
        echo -e "${YELLOW}  macOS:   brew install uv${NC}"
        echo -e "${YELLOW}  Linux:   pip install uv${NC}"
        echo ""
        echo -e "${YELLOW}After installing uv, re-run setup:${NC}"
        echo -e "${YELLOW}  ./scripts/setup.sh${NC}"
        echo ""
        read -p "Continue setup without Jira MCP? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓${NC} uv is installed"
        echo ""

        # Ask where to save configuration
        echo -e "${BLUE}📍 Where should the MCP configuration be saved?${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} Global   - ~/.claude/settings.json"
        echo -e "     Works for all projects, recommended for personal use"
        echo ""
        echo -e "  ${YELLOW}2)${NC} Project  - $REPO_ROOT/.claude/settings.json"
        echo -e "     Only for this project, recommended for team shared config"
        echo ""

        while true; do
            read -p "Choose (1 or 2): " -n 1 -r CHOICE
            echo ""

            if [[ $CHOICE == "1" ]]; then
                SETTINGS_FILE="$HOME/.claude/settings.json"
                SETTINGS_SCOPE="global"
                break
            elif [[ $CHOICE == "2" ]]; then
                SETTINGS_FILE="$REPO_ROOT/.claude/settings.json"
                SETTINGS_SCOPE="project"
                mkdir -p "$REPO_ROOT/.claude"
                break
            else
                echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
            fi
        done

        echo ""
        echo -e "${BLUE}Configuring MCP server...${NC}"

        # Create MCP configuration JSON
        MCP_CONFIG='{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "uvx",
      "args": ["mcp-atlassian"],
      "env": {
        "JIRA_URL": "${JIRA_URL}",
        "JIRA_USERNAME": "${JIRA_USERNAME}",
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}",
        "JIRA_SSL_VERIFY": "true",
        "READ_ONLY_MODE": "true"
      }
    }
  },
  "enableAllProjectMcpServers": true,
  "permissions": {
    "allow": [
      "mcp__mcp-atlassian__get_issue",
      "mcp__mcp-atlassian__search_issues",
      "mcp__mcp-atlassian__get_epic_children"
    ]
  }
}'

        # Check if settings file exists
        if [ -f "$SETTINGS_FILE" ]; then
            echo -e "${YELLOW}⚠️  Settings file already exists: $SETTINGS_FILE${NC}"
            echo ""
            echo -e "Options:"
            echo -e "  ${YELLOW}1)${NC} Merge - Add mcp-atlassian to existing config (recommended)"
            echo -e "  ${YELLOW}2)${NC} Skip  - Keep existing config unchanged"
            echo -e "  ${YELLOW}3)${NC} View  - Show current config"
            echo ""

            while true; do
                read -p "Choose (1/2/3): " -n 1 -r MERGE_CHOICE
                echo ""

                if [[ $MERGE_CHOICE == "1" ]]; then
                    # Check if mcp-atlassian already exists
                    EXISTING_MCP_CHECK=$(python3 << 'PYTHON_EOF'
import json
import sys
import os

settings_file = os.environ.get('SETTINGS_FILE')

try:
    with open(settings_file, 'r') as f:
        existing = json.load(f)

    # Check if mcp-atlassian exists
    if 'mcpServers' in existing and 'mcp-atlassian' in existing['mcpServers']:
        print("EXISTS")
        print(json.dumps(existing['mcpServers']['mcp-atlassian'], indent=2))
        sys.exit(0)
    else:
        print("NOT_EXISTS")
        sys.exit(0)
except Exception as e:
    print("ERROR")
    sys.exit(1)
PYTHON_EOF
)

                    if echo "$EXISTING_MCP_CHECK" | grep -q "^EXISTS"; then
                        echo ""
                        echo -e "${YELLOW}⚠️  mcp-atlassian is already configured!${NC}"
                        echo ""
                        echo -e "${BLUE}Current mcp-atlassian configuration:${NC}"
                        echo "$EXISTING_MCP_CHECK" | tail -n +2
                        echo ""
                        echo -e "Options:"
                        echo -e "  ${YELLOW}1)${NC} Keep existing - Don't change mcp-atlassian (recommended)"
                        echo -e "  ${YELLOW}2)${NC} Replace - Overwrite with new config"
                        echo -e "  ${YELLOW}3)${NC} Skip all - Don't modify settings.json"
                        echo ""

                        while true; do
                            read -p "Choose (1/2/3): " -n 1 -r REPLACE_CHOICE
                            echo ""

                            if [[ $REPLACE_CHOICE == "1" ]]; then
                                echo -e "${GREEN}✓${NC} Keeping existing mcp-atlassian configuration"
                                echo -e "${GREEN}✓${NC} Adding missing permissions if needed"

                                # Only add permissions, don't touch mcp-atlassian config
                                python3 << 'PYTHON_EOF'
import json
import os

settings_file = os.environ.get('SETTINGS_FILE')

with open(settings_file, 'r') as f:
    existing = json.load(f)

new_permissions = [
    "mcp__mcp-atlassian__get_issue",
    "mcp__mcp-atlassian__search_issues",
    "mcp__mcp-atlassian__get_epic_children"
]

# Merge permissions only
if 'permissions' not in existing:
    existing['permissions'] = {}
if 'allow' not in existing['permissions']:
    existing['permissions']['allow'] = []

added = []
for perm in new_permissions:
    if perm not in existing['permissions']['allow']:
        existing['permissions']['allow'].append(perm)
        added.append(perm)

with open(settings_file, 'w') as f:
    json.dump(existing, f, indent=2)

if added:
    print(f"Added {len(added)} new permissions")
else:
    print("All permissions already present")
PYTHON_EOF
                                break
                            elif [[ $REPLACE_CHOICE == "2" ]]; then
                                echo -e "${YELLOW}Replacing existing mcp-atlassian configuration...${NC}"
                                # Continue with merge below
                                break
                            elif [[ $REPLACE_CHOICE == "3" ]]; then
                                echo -e "${YELLOW}Skipping Jira MCP configuration${NC}"
                                MCP_CONFIG=""
                                break 2  # Break out of both loops
                            else
                                echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                            fi
                        done

                        # If user chose "Keep existing" (option 1), skip the merge
                        if [[ $REPLACE_CHOICE == "1" ]]; then
                            break
                        fi
                    fi

                    # Merge configuration using Python (only runs if NOT keeping existing)
                    python3 << 'PYTHON_EOF'
import json
import sys
import os

settings_file = os.environ.get('SETTINGS_FILE')

# Read existing config
try:
    with open(settings_file, 'r') as f:
        existing = json.load(f)
except:
    existing = {}

# New MCP config
new_mcp = {
    "mcp-atlassian": {
        "command": "uvx",
        "args": ["mcp-atlassian"],
        "env": {
            "JIRA_URL": "${JIRA_URL}",
            "JIRA_USERNAME": "${JIRA_USERNAME}",
            "JIRA_API_TOKEN": "${JIRA_API_TOKEN}",
            "JIRA_SSL_VERIFY": "true",
            "READ_ONLY_MODE": "true"
        }
    }
}

new_permissions = [
    "mcp__mcp-atlassian__get_issue",
    "mcp__mcp-atlassian__search_issues",
    "mcp__mcp-atlassian__get_epic_children"
]

# Merge mcpServers
if 'mcpServers' not in existing:
    existing['mcpServers'] = {}
existing['mcpServers']['mcp-atlassian'] = new_mcp['mcp-atlassian']

# Set enableAllProjectMcpServers
existing['enableAllProjectMcpServers'] = True

# Merge permissions
if 'permissions' not in existing:
    existing['permissions'] = {}
if 'allow' not in existing['permissions']:
    existing['permissions']['allow'] = []

# Add new permissions if not already present
for perm in new_permissions:
    if perm not in existing['permissions']['allow']:
        existing['permissions']['allow'].append(perm)

# Write merged config
with open(settings_file, 'w') as f:
    json.dump(existing, f, indent=2)

print("✓ Merged mcp-atlassian configuration")
PYTHON_EOF
                    echo -e "${GREEN}✓${NC} Preserved existing MCP servers and settings"
                    break
                elif [[ $MERGE_CHOICE == "2" ]]; then
                    echo -e "${YELLOW}Skipping Jira MCP configuration${NC}"
                    MCP_CONFIG=""
                    break
                elif [[ $MERGE_CHOICE == "3" ]]; then
                    echo ""
                    echo -e "${BLUE}Current configuration:${NC}"
                    cat "$SETTINGS_FILE"
                    echo ""
                else
                    echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                fi
            done
        else
            # Create new settings file
            echo "$MCP_CONFIG" > "$SETTINGS_FILE"
            echo -e "${GREEN}✓${NC} Created $SETTINGS_FILE"
            echo -e "${GREEN}✓${NC} Added mcp-atlassian server configuration"
            echo -e "${GREEN}✓${NC} Added Jira permissions (3 tools)"
        fi

        if [ -n "$MCP_CONFIG" ]; then
            echo ""
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}✅ Jira MCP configuration complete!${NC}"
            echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo -e "${BLUE}Configuration saved to:${NC} $SETTINGS_FILE"
            echo -e "${BLUE}Scope:${NC} $SETTINGS_SCOPE"
        fi
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

# Show Jira-specific next steps if MCP was configured
if [[ $REPLY =~ ^[Yy]$ ]] && command -v uv &> /dev/null && [ -n "$MCP_CONFIG" ]; then
    echo -e "${YELLOW}1. Edit .env with your Jira credentials:${NC}"
    echo -e "   vi $REPO_ROOT/.env"
    echo ""
    echo -e "   ${BLUE}Required credentials:${NC}"
    echo -e "   JIRA_URL=https://your-jira.com"
    echo -e "   JIRA_USERNAME=your.email@company.com"
    echo -e "   JIRA_API_TOKEN=your-token-here"
    echo ""
    echo -e "   ${BLUE}📚 Generate API token:${NC}"
    echo -e "   https://id.atlassian.com/manage-profile/security/api-tokens"
    echo ""
    echo -e "${YELLOW}2. Test the Jira MCP connection:${NC}"
    echo -e "   claude"
    echo -e "   > ${BLUE}/jira-coverage-analysis OSPRH-22613${NC}"
    echo ""
    echo -e "   ${GREEN}✓ Success:${NC} Fetches ticket automatically (no prompts)"
    echo -e "   ${RED}✗ Failed:${NC}  Prompts for ticket details"
    echo ""
    echo -e "${YELLOW}3. (Optional) Update repository paths in shared config:${NC}"
    echo -e "   vi $SKILLS_DIR/tempest-coverage/config.json"
    echo ""
else
    echo -e "${YELLOW}1. (Optional) Edit .env with your Jira credentials:${NC}"
    echo -e "   vi $REPO_ROOT/.env"
    echo ""
    echo -e "${YELLOW}2. (Optional) Update repository paths in shared config:${NC}"
    echo -e "   vi $SKILLS_DIR/tempest-coverage/config.json"
    echo ""
    echo -e "${YELLOW}3. (Optional) Set up Jira MCP server:${NC}"
    echo -e "   Re-run: ./scripts/setup.sh"
    echo -e "   Or see: docs/JIRA_SETUP.md"
    echo ""
    echo -e "${YELLOW}4. Test the skills:${NC}"
    echo -e "   claude"
    echo -e "   > ${BLUE}/jira-coverage-analysis --help${NC}"
    echo ""
fi

echo -e "${BLUE}📚 Documentation:${NC}"
echo -e "   README.md          - Main documentation"
echo -e "   docs/QUICKSTART.md - 5-minute guide"
echo -e "   CLAUDE.md          - OpenStack Tempest standards"
echo ""
echo -e "${BLUE}🎯 Quick Start Example:${NC}"
echo -e "   claude"
echo -e "   > ${BLUE}/jira-coverage-analysis OSPRH-22613${NC}"
echo ""
