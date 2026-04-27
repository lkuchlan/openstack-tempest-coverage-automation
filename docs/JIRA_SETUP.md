# Jira MCP Setup Guide

Configure Jira integration for automatic ticket fetching.

## Note: Skills Work Without Jira MCP

You can use both skills **without Jira MCP** - just provide ticket details manually when prompted. This guide is only for automatic ticket fetching.

## Prerequisites

- Jira account with API access
- Access to Jira instance (Cloud or Data Center)
- npm installed (for MCP server)

## Generate API Token

### Jira Cloud

1. Visit: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Name it "Claude Code Tempest Automation"
4. Copy the token (save it securely)

### Jira Data Center

1. Go to User Settings → Personal Access Tokens
2. Create new token
3. Copy token value

## Configure Credentials

**1. Copy template:**
```bash
cp examples/.env.example .env
```

**2. Edit .env:**
```bash
vi .env

# Add your credentials:
JIRA_URL=https://issues.redhat.com
JIRA_USERNAME=your.email@company.com
JIRA_API_TOKEN=your-token-here
```

**3. Secure the file:**
```bash
chmod 600 .env
```

**4. Verify it's git-ignored:**
```bash
git status
# .env should NOT appear
```

## Configure MCP Server

**Method 1: Project settings (recommended)**

Edit `.claude/settings.json`:
```json
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
  },
  "enableAllProjectMcpServers": true,
  "permissions": {
    "allow": [
      "mcp__jira__get_issue",
      "mcp__jira__search_issues",
      "mcp__jira__get_epic_children"
    ]
  }
}
```

**Method 2: User settings (global)**

See `examples/settings.json.example` for complete configuration.

## Test MCP Connection

```bash
claude

# Try fetching a ticket
> /jira-coverage-analysis OSPRH-22613

# Should fetch ticket automatically
# If it prompts for ticket details, MCP is not connected
```

## Troubleshooting

**MCP server not starting:**
- Check npm is installed: `npm --version`
- Try manual installation: `npm install -g @modelcontextprotocol/server-jira`

**Authentication failing:**
- Verify credentials in .env
- Check Jira URL (no trailing slash)
- Ensure API token is valid

**Permissions prompted:**
- Add read-only Jira operations to permissions.allow in settings.json
- See examples/settings.json.example

## Alternative: System Environment Variables

Instead of .env:

```bash
# Add to ~/.zshrc or ~/.bashrc
export JIRA_URL="https://your-jira.com"
export JIRA_USERNAME="your-email@company.com"
export JIRA_API_TOKEN="your-token"

source ~/.zshrc
```

## Security Best Practices

- ✅ Keep .env file secure (chmod 600)
- ✅ Never commit .env to git
- ✅ Rotate API tokens regularly
- ✅ Use least-privilege accounts
- ❌ Don't share tokens in chat/email
- ❌ Don't use admin accounts

## Next Steps

- Test ticket fetching
- Review [EXAMPLES.md](EXAMPLES.md) for workflows
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for issues
