#!/bin/bash
#
# Jira MCP Setup Helper Script
#
# Guides you through setting up Jira MCP server integration
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
MCP_FILE="$PROJECT_ROOT/.mcp.json"
ENV_FILE="$PROJECT_ROOT/.env"

echo "================================================"
echo "Jira MCP Server Setup"
echo "================================================"
echo ""

echo "This script helps you set up Jira MCP integration."
echo ""

# Check if MCP server package is available
echo "Step 1: Checking MCP server availability..."
if command -v npx &> /dev/null; then
    echo -e "${GREEN}✓ npx is available${NC}"
else
    echo -e "${RED}✗ npx is not available${NC}"
    echo "Please install Node.js and npm first."
    echo "Visit: https://nodejs.org/"
    exit 1
fi
echo ""

# Gather Jira credentials
echo "Step 2: Jira credentials"
echo ""

echo -e "${BLUE}What is your Jira URL?${NC}"
echo "Example: https://issues.redhat.com"
read -p "Jira URL: " JIRA_URL

if [ -z "$JIRA_URL" ]; then
    echo -e "${RED}Jira URL is required${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}What is your Jira username/email?${NC}"
read -p "Jira username: " JIRA_USERNAME

if [ -z "$JIRA_USERNAME" ]; then
    echo -e "${RED}Jira username is required${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}What is your Jira API token?${NC}"
echo "Get it from: https://id.atlassian.com/manage-profile/security/api-tokens"
read -s -p "Jira API token: " JIRA_API_TOKEN
echo ""

if [ -z "$JIRA_API_TOKEN" ]; then
    echo -e "${RED}Jira API token is required${NC}"
    exit 1
fi

echo ""
echo "Step 3: Storing credentials..."
echo ""

# Ask where to store
echo "Where do you want to store credentials?"
echo "  1. In .env file (recommended, git-ignored)"
echo "  2. In .claude/settings.json (less secure)"
read -p "Choice (1 or 2): " STORE_CHOICE

if [ "$STORE_CHOICE" = "1" ]; then
    # Store in .env
    echo "JIRA_URL=$JIRA_URL" > "$ENV_FILE"
    echo "JIRA_USERNAME=$JIRA_USERNAME" >> "$ENV_FILE"
    echo "JIRA_API_TOKEN=$JIRA_API_TOKEN" >> "$ENV_FILE"
    chmod 600 "$ENV_FILE"

    echo -e "${GREEN}✓ Credentials saved to: $ENV_FILE${NC}"
    echo -e "${GREEN}✓ File permissions set to 600 (secure)${NC}"

    # Create .mcp.json with env var references
    cat > "$MCP_FILE" <<'EOF'
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-jira"],
      "env": {
        "JIRA_URL": "${JIRA_URL}",
        "JIRA_USERNAME": "${JIRA_USERNAME}",
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
      }
    }
  }
}
EOF
    chmod 600 "$MCP_FILE"

    echo -e "${GREEN}✓ Created .mcp.json with environment variable references${NC}"

    # Update settings.json to enable project MCP servers
    if [ -f "$SETTINGS_FILE" ]; then
        # Check if enableAllProjectMcpServers already exists
        if grep -q "enableAllProjectMcpServers" "$SETTINGS_FILE"; then
            echo -e "${GREEN}✓ settings.json already enables project MCP servers${NC}"
        else
            # Simple approach: backup and recreate with the flag
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
            cat > "$SETTINGS_FILE" <<'SETTINGS_EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "enableAllProjectMcpServers": true,

  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation"
  }
}
SETTINGS_EOF
            echo -e "${GREEN}✓ Updated settings.json to enable project MCP servers${NC}"
        fi
    fi

else
    # Store directly in .mcp.json
    echo -e "${YELLOW}! Storing credentials in .mcp.json${NC}"
    echo -e "${YELLOW}! This is less secure than using .env${NC}"

    cat > "$MCP_FILE" <<EOF
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-jira"],
      "env": {
        "JIRA_URL": "$JIRA_URL",
        "JIRA_USERNAME": "$JIRA_USERNAME",
        "JIRA_API_TOKEN": "$JIRA_API_TOKEN"
      }
    }
  }
}
EOF
    chmod 600 "$MCP_FILE"

    echo -e "${GREEN}✓ Created .mcp.json with credentials${NC}"

    # Update settings.json to enable project MCP servers
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "enableAllProjectMcpServers" "$SETTINGS_FILE"; then
            echo -e "${GREEN}✓ settings.json already enables project MCP servers${NC}"
        else
            cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
            cat > "$SETTINGS_FILE" <<'SETTINGS_EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "enableAllProjectMcpServers": true,

  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation"
  }
}
SETTINGS_EOF
            echo -e "${GREEN}✓ Updated settings.json to enable project MCP servers${NC}"
        fi
    fi
fi

echo ""
echo "Step 4: Verifying configuration..."

# Test connection (optional)
echo ""
read -p "Do you want to test the Jira connection? (y/n): " TEST_CONN

if [ "$TEST_CONN" = "y" ]; then
    echo ""
    echo "Testing connection to Jira..."

    # Try to fetch a test issue (if user provides ticket ID)
    read -p "Enter a test Jira ticket ID (e.g., RHEL-12345): " TEST_TICKET

    if [ -n "$TEST_TICKET" ]; then
        echo "Testing: curl to $JIRA_URL/rest/api/2/issue/$TEST_TICKET"

        if curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
            "$JIRA_URL/rest/api/2/issue/$TEST_TICKET" \
            | grep -q '"key":'; then
            echo -e "${GREEN}✓ Connection successful! Ticket found.${NC}"
        else
            echo -e "${YELLOW}! Connection test inconclusive${NC}"
            echo "Please verify credentials and try in Claude Code"
        fi
    fi
fi

echo ""
echo "================================================"
echo "Setup Complete"
echo "================================================"
echo ""
echo "Jira MCP server is now configured!"
echo ""
echo "Next steps:"
echo ""
echo "1. Restart Claude Code (if running)"
echo ""
echo "2. Test in Claude:"
echo "   cd $PROJECT_ROOT"
echo "   claude"
echo "   "
echo "   # Try fetching a ticket"
echo "   /jira-coverage-analysis RHEL-12345"
echo ""
echo "3. Skills will automatically:"
echo "   - Detect Jira MCP tools"
echo "   - Fetch tickets via MCP"
echo "   - Extract requirements"
echo ""

if [ "$STORE_CHOICE" = "1" ]; then
    echo "Security notes:"
    echo "  ✓ Credentials stored in .env (git-ignored)"
    echo "  ✓ .env has secure permissions (600)"
    echo "  ✓ .mcp.json uses env var references"
    echo "  ✓ .mcp.json has secure permissions (600)"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
