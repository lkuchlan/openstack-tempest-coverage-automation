#!/bin/bash
#
# Test Jira MCP Connection
#
# Quick test to verify Jira MCP server can connect
#

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "================================================"
echo "Test Jira MCP Connection"
echo "================================================"
echo ""

# Step 1: Check files exist
echo "Step 1: Checking configuration files..."
if [ -f "$PROJECT_ROOT/.mcp.json" ]; then
    echo -e "${GREEN}✓ .mcp.json exists${NC}"
else
    echo -e "${RED}✗ .mcp.json missing${NC}"
    exit 1
fi

if [ -f "$PROJECT_ROOT/.env" ]; then
    echo -e "${GREEN}✓ .env exists${NC}"
    source "$PROJECT_ROOT/.env"
else
    echo -e "${YELLOW}! .env not found, using credentials from .mcp.json${NC}"
    # Extract from .mcp.json
    JIRA_URL=$(jq -r '.mcpServers.jira.env.JIRA_URL' "$PROJECT_ROOT/.mcp.json")
    JIRA_USERNAME=$(jq -r '.mcpServers.jira.env.JIRA_USERNAME' "$PROJECT_ROOT/.mcp.json")
    JIRA_API_TOKEN=$(jq -r '.mcpServers.jira.env.JIRA_API_TOKEN' "$PROJECT_ROOT/.mcp.json")
fi

echo ""

# Step 2: Validate JSON
echo "Step 2: Validating .mcp.json syntax..."
if jq empty "$PROJECT_ROOT/.mcp.json" 2>/dev/null; then
    echo -e "${GREEN}✓ .mcp.json is valid JSON${NC}"
else
    echo -e "${RED}✗ .mcp.json has JSON syntax errors${NC}"
    exit 1
fi

echo ""

# Step 3: Check npx availability
echo "Step 3: Checking npx availability..."
if command -v npx &> /dev/null; then
    echo -e "${GREEN}✓ npx is available${NC}"
    echo "  Location: $(command -v npx)"
else
    echo -e "${RED}✗ npx not found${NC}"
    echo "  Install Node.js: https://nodejs.org/"
    exit 1
fi

echo ""

# Step 4: Test Jira REST API connection
echo "Step 4: Testing Jira REST API connection..."
if [ -z "$JIRA_URL" ] || [ -z "$JIRA_USERNAME" ] || [ -z "$JIRA_API_TOKEN" ]; then
    echo -e "${RED}✗ Missing Jira credentials${NC}"
    exit 1
fi

echo "  URL: $JIRA_URL"
echo "  Username: $JIRA_USERNAME"
echo "  Testing connection..."

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
    "$JIRA_URL/rest/api/2/myself")

if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ Jira REST API connection successful${NC}"

    # Get user info
    USER_INFO=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$JIRA_URL/rest/api/2/myself" | jq -r '.displayName')
    echo "  Authenticated as: $USER_INFO"
else
    echo -e "${RED}✗ Jira connection failed (HTTP $RESPONSE)${NC}"
    if [ "$RESPONSE" = "401" ]; then
        echo "  Reason: Invalid credentials"
        echo "  Action: Regenerate API token at https://id.atlassian.com/manage-profile/security/api-tokens"
    fi
    exit 1
fi

echo ""

# Step 5: Check Claude Code settings
echo "Step 5: Checking Claude Code settings..."
if [ -f "$PROJECT_ROOT/.claude/settings.json" ]; then
    echo -e "${GREEN}✓ .claude/settings.json exists${NC}"

    if grep -q "enableAllProjectMcpServers" "$PROJECT_ROOT/.claude/settings.json"; then
        echo -e "${GREEN}✓ enableAllProjectMcpServers is configured${NC}"
    else
        echo -e "${YELLOW}! enableAllProjectMcpServers not found${NC}"
    fi

    if grep -q "enabledMcpjsonServers" "$PROJECT_ROOT/.claude/settings.json"; then
        echo -e "${GREEN}✓ enabledMcpjsonServers is configured${NC}"
    else
        echo -e "${YELLOW}! enabledMcpjsonServers not found (optional)${NC}"
    fi
else
    echo -e "${RED}✗ .claude/settings.json missing${NC}"
fi

echo ""

# Step 6: Check working directory
echo "Step 6: Checking working directory..."
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" = "$PROJECT_ROOT" ]; then
    echo -e "${GREEN}✓ Currently in project root${NC}"
    echo "  You can start Claude from here"
else
    echo -e "${YELLOW}! Not in project root${NC}"
    echo "  Current: $CURRENT_DIR"
    echo "  Expected: $PROJECT_ROOT"
    echo ""
    echo "  Action: Run this before starting Claude:"
    echo "    cd $PROJECT_ROOT"
fi

echo ""
echo "================================================"
echo "Summary"
echo "================================================"
echo ""
echo -e "${GREEN}All checks passed!${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Make sure you're in the project root:"
echo "   cd $PROJECT_ROOT"
echo ""
echo "2. Start Claude:"
echo "   claude"
echo ""
echo "3. When prompted, approve the 'jira' MCP server"
echo ""
echo "4. Test the skill:"
echo "   /jira-coverage-analysis OSPRH-22613"
echo ""
echo "If MCP tools are not available, see:"
echo "  $PROJECT_ROOT/MCP_SETUP_GUIDE.md"
echo ""
