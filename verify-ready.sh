#!/bin/bash
#
# Quick verification that everything is ready
#

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "Claude Code + Jira MCP - Ready Check"
echo "================================================"
echo ""

READY=true

# Check 1: Current directory
echo -e "${BLUE}1. Checking current directory...${NC}"
if [ "$(pwd)" = "/Users/lironkuchlani/claude-automation" ]; then
    echo -e "${GREEN}   ✓ You are in the project root${NC}"
else
    echo -e "${RED}   ✗ Wrong directory!${NC}"
    echo "   Current: $(pwd)"
    echo "   Expected: /Users/lironkuchlani/claude-automation"
    echo ""
    echo "   Run: cd /Users/lironkuchlani/claude-automation"
    READY=false
fi
echo ""

# Check 2: .mcp.json exists
echo -e "${BLUE}2. Checking MCP configuration...${NC}"
if [ -f ".mcp.json" ]; then
    echo -e "${GREEN}   ✓ .mcp.json exists${NC}"

    # Check permissions
    PERMS=$(stat -f "%OLp" .mcp.json 2>/dev/null || stat -c "%a" .mcp.json 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}   ✓ Permissions are secure (600)${NC}"
    else
        echo -e "${YELLOW}   ! Permissions should be 600 (currently $PERMS)${NC}"
        echo "   Run: chmod 600 .mcp.json"
    fi

    # Validate JSON
    if jq empty .mcp.json 2>/dev/null; then
        echo -e "${GREEN}   ✓ Valid JSON syntax${NC}"
    else
        echo -e "${RED}   ✗ Invalid JSON syntax${NC}"
        READY=false
    fi
else
    echo -e "${RED}   ✗ .mcp.json not found${NC}"
    echo "   Run: bash scripts/jira/setup-mcp.sh"
    READY=false
fi
echo ""

# Check 3: settings.json
echo -e "${BLUE}3. Checking Claude settings...${NC}"
if [ -f ".claude/settings.json" ]; then
    echo -e "${GREEN}   ✓ .claude/settings.json exists${NC}"

    if grep -q "enableAllProjectMcpServers" .claude/settings.json; then
        echo -e "${GREEN}   ✓ MCP auto-approval enabled${NC}"
    else
        echo -e "${YELLOW}   ! MCP auto-approval not set${NC}"
    fi
else
    echo -e "${RED}   ✗ .claude/settings.json not found${NC}"
    READY=false
fi
echo ""

# Check 4: Skills
echo -e "${BLUE}4. Checking skills...${NC}"
if [ -d ".claude/skills/jira-coverage-analysis" ]; then
    echo -e "${GREEN}   ✓ jira-coverage-analysis skill found${NC}"
else
    echo -e "${RED}   ✗ jira-coverage-analysis skill not found${NC}"
    READY=false
fi

if [ -d ".claude/skills/implement-tempest-tests" ]; then
    echo -e "${GREEN}   ✓ implement-tempest-tests skill found${NC}"
else
    echo -e "${RED}   ✗ implement-tempest-tests skill not found${NC}"
    READY=false
fi
echo ""

# Check 5: Jira credentials
echo -e "${BLUE}5. Testing Jira connection...${NC}"
if [ -f ".env" ]; then
    source .env
elif [ -f ".mcp.json" ]; then
    JIRA_URL=$(jq -r '.mcpServers.jira.env.JIRA_URL' .mcp.json)
    JIRA_USERNAME=$(jq -r '.mcpServers.jira.env.JIRA_USERNAME' .mcp.json)
    JIRA_API_TOKEN=$(jq -r '.mcpServers.jira.env.JIRA_API_TOKEN' .mcp.json)
fi

if [ -n "$JIRA_URL" ] && [ -n "$JIRA_USERNAME" ] && [ -n "$JIRA_API_TOKEN" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$JIRA_URL/rest/api/2/myself")

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}   ✓ Jira connection successful${NC}"
        USER=$(curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
            "$JIRA_URL/rest/api/2/myself" | jq -r '.displayName')
        echo "   Authenticated as: $USER"
    else
        echo -e "${RED}   ✗ Jira connection failed (HTTP $HTTP_CODE)${NC}"
        if [ "$HTTP_CODE" = "401" ]; then
            echo "   Invalid credentials - regenerate API token"
        fi
        READY=false
    fi
else
    echo -e "${RED}   ✗ Jira credentials not found${NC}"
    READY=false
fi
echo ""

# Check 6: npx
echo -e "${BLUE}6. Checking npx (for MCP server)...${NC}"
if command -v npx &> /dev/null; then
    echo -e "${GREEN}   ✓ npx is available${NC}"
    echo "   Location: $(command -v npx)"
else
    echo -e "${RED}   ✗ npx not found${NC}"
    echo "   Install Node.js from: https://nodejs.org/"
    READY=false
fi
echo ""

# Summary
echo "================================================"
echo "Summary"
echo "================================================"
echo ""

if [ "$READY" = true ]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "You're ready to start Claude!"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo ""
    echo "1. Start Claude (make sure you're in this directory):"
    echo "   ${GREEN}claude${NC}"
    echo ""
    echo "2. When prompted, approve the 'jira' MCP server"
    echo ""
    echo "3. Test MCP is working:"
    echo "   ${GREEN}What MCP tools do you have?${NC}"
    echo ""
    echo "4. Use the skills:"
    echo "   ${GREEN}/jira-coverage-analysis OSPRH-22613${NC}"
    echo "   ${GREEN}/implement-tempest-tests OSPRH-22613${NC}"
    echo ""
else
    echo -e "${RED}❌ SOME CHECKS FAILED${NC}"
    echo ""
    echo "Fix the issues above, then run this script again."
    echo ""
    echo "For help, see:"
    echo "  - START_HERE.md"
    echo "  - STARTUP_CHECKLIST.md"
    echo "  - MCP_SETUP_GUIDE.md"
    echo ""
fi
