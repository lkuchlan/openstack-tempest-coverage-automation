# Jira MCP Server Setup Guide

This guide explains how to set up Jira MCP server integration for the Tempest Coverage skill.

## Overview

With Jira MCP server integration, the skill can:
- ✅ Automatically fetch Jira tickets by ID
- ✅ Extract requirements, acceptance criteria, and descriptions
- ✅ Search for related tickets
- ✅ Access comments and attachments
- ✅ No manual copy/paste needed!

## Prerequisites

- Claude Code with MCP support
- Access to Jira instance (e.g., https://issues.redhat.com)
- Jira API token or credentials

## Option 1: Using Existing Jira MCP Servers

### Available Jira MCP Servers

Several MCP servers for Jira are available:

1. **@modelcontextprotocol/server-jira** (Official)
   - Source: https://github.com/modelcontextprotocol/servers
   - Supports Jira Cloud and Data Center

2. **Community Jira MCP servers**
   - Check MCP server registry: https://github.com/modelcontextprotocol/servers

### Installation Steps

#### Step 1: Install MCP Server

```bash
# Option A: Using npx (no installation needed)
# Configure in Claude Code settings

# Option B: Install globally
npm install -g @modelcontextprotocol/server-jira

# Option C: Install locally in your project
cd /Users/lironkuchlani/claude-automation
npm install @modelcontextprotocol/server-jira
```

#### Step 2: Get Jira API Token

1. **For Jira Cloud:**
   - Go to: https://id.atlassian.com/manage-profile/security/api-tokens
   - Click "Create API token"
   - Copy the token (save it securely!)

2. **For Jira Data Center/Server:**
   - Use your username and password
   - Or generate a personal access token in Jira settings

3. **For Red Hat Jira (issues.redhat.com):**
   - Contact your admin for API access
   - Or use Kerberos authentication if available

#### Step 3: Configure Claude Code Settings

Add MCP server configuration to your Claude Code settings.

**Global configuration:**
```bash
vi ~/.claude/settings.json
```

**Or project-specific:**
```bash
vi /Users/lironkuchlani/claude-automation/.claude/settings.json
```

**Add this configuration:**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-jira"
      ],
      "env": {
        "JIRA_URL": "https://issues.redhat.com",
        "JIRA_USERNAME": "your-email@redhat.com",
        "JIRA_API_TOKEN": "your-api-token-here"
      }
    }
  },
  
  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation"
  }
}
```

#### Step 4: Secure Your Credentials

**Option A: Use environment variables**

Create `.env` file (git-ignored):
```bash
cat > /Users/lironkuchlani/claude-automation/.env <<EOF
JIRA_URL=https://issues.redhat.com
JIRA_USERNAME=your-email@redhat.com
JIRA_API_TOKEN=your-api-token-here
EOF

chmod 600 .env
```

Update settings.json:
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
  }
}
```

**Option B: Use system environment variables**

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
export JIRA_URL="https://issues.redhat.com"
export JIRA_USERNAME="your-email@redhat.com"
export JIRA_API_TOKEN="your-api-token-here"
```

Then reload:
```bash
source ~/.zshrc
```

#### Step 5: Verify Installation

Start Claude Code:
```bash
cd /Users/lironkuchlani/claude-automation
claude
```

Test MCP tools are available:
```
List available MCP tools
```

You should see Jira tools like:
- `jira_get_issue`
- `jira_search`
- `jira_create_issue`
- `jira_update_issue`
- etc.

#### Step 6: Test Jira Integration

```
/tempest-coverage RHEL-12345
```

The skill should automatically:
1. Detect Jira MCP is available
2. Fetch ticket RHEL-12345 using `jira_get_issue`
3. Extract requirements
4. Proceed with test implementation

---

## Option 2: Custom Jira MCP Server

If you need custom Jira integration, you can create your own MCP server.

### Create Custom MCP Server

```bash
cd /Users/lironkuchlani/claude-automation
mkdir jira-mcp-server
cd jira-mcp-server
npm init -y
npm install @modelcontextprotocol/sdk axios
```

### Example Custom Server (TypeScript)

**File:** `src/index.ts`

```typescript
#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';

const JIRA_URL = process.env.JIRA_URL || 'https://issues.redhat.com';
const JIRA_USERNAME = process.env.JIRA_USERNAME;
const JIRA_API_TOKEN = process.env.JIRA_API_TOKEN;

const jiraClient = axios.create({
  baseURL: `${JIRA_URL}/rest/api/2`,
  auth: {
    username: JIRA_USERNAME!,
    password: JIRA_API_TOKEN!,
  },
  headers: {
    'Content-Type': 'application/json',
  },
});

const server = new Server(
  {
    name: 'jira-tempest-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'jira_get_issue',
        description: 'Get Jira issue details by key (e.g., RHEL-12345)',
        inputSchema: {
          type: 'object',
          properties: {
            issue_key: {
              type: 'string',
              description: 'Jira issue key (e.g., RHEL-12345)',
            },
          },
          required: ['issue_key'],
        },
      },
      {
        name: 'jira_search',
        description: 'Search for Jira issues using JQL',
        inputSchema: {
          type: 'object',
          properties: {
            jql: {
              type: 'string',
              description: 'JQL query string',
            },
            max_results: {
              type: 'number',
              description: 'Maximum results to return (default: 10)',
            },
          },
          required: ['jql'],
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'jira_get_issue') {
    const { issue_key } = args as { issue_key: string };
    
    try {
      const response = await jiraClient.get(`/issue/${issue_key}`, {
        params: {
          fields: 'summary,description,status,assignee,components,labels,comment',
        },
      });

      const issue = response.data;
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              key: issue.key,
              summary: issue.fields.summary,
              description: issue.fields.description,
              status: issue.fields.status.name,
              assignee: issue.fields.assignee?.displayName,
              components: issue.fields.components.map((c: any) => c.name),
              labels: issue.fields.labels,
              comments: issue.fields.comment?.comments.map((c: any) => ({
                author: c.author.displayName,
                body: c.body,
                created: c.created,
              })),
            }, null, 2),
          },
        ],
      };
    } catch (error: any) {
      throw new Error(`Failed to fetch Jira issue: ${error.message}`);
    }
  }

  if (name === 'jira_search') {
    const { jql, max_results = 10 } = args as { jql: string; max_results?: number };
    
    try {
      const response = await jiraClient.post('/search', {
        jql,
        maxResults: max_results,
        fields: ['summary', 'status', 'assignee'],
      });

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(response.data.issues, null, 2),
          },
        ],
      };
    } catch (error: any) {
      throw new Error(`Failed to search Jira: ${error.message}`);
    }
  }

  throw new Error(`Unknown tool: ${name}`);
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Jira MCP server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
```

### Build and Configure

```bash
# Compile TypeScript
npx tsc

# Configure in settings.json
```

**settings.json:**
```json
{
  "mcpServers": {
    "jira": {
      "command": "node",
      "args": ["/Users/lironkuchlani/claude-automation/jira-mcp-server/dist/index.js"],
      "env": {
        "JIRA_URL": "https://issues.redhat.com",
        "JIRA_USERNAME": "your-email@redhat.com",
        "JIRA_API_TOKEN": "your-api-token-here"
      }
    }
  }
}
```

---

## Usage Examples

### Basic Usage

```bash
cd /Users/lironkuchlani/claude-automation
claude
```

**With Jira ticket ID:**
```
/tempest-coverage RHEL-12345
```

The skill automatically:
1. Detects Jira MCP tools
2. Calls `jira_get_issue(issue_key="RHEL-12345")`
3. Extracts requirements
4. Implements tests

### Search for Related Tickets

```
/tempest-coverage

Search for all Cinder volume test coverage tickets and implement missing tests
```

The skill can:
1. Use `jira_search(jql="project=RHEL AND component=Cinder AND labels=test-coverage")`
2. Analyze multiple tickets
3. Identify gaps across all tickets

### Without Ticket ID

```
/tempest-coverage

Implement RBAC tests for Manila share revert operation
```

The skill will:
1. Ask if you have a Jira ticket
2. If yes, fetch it via MCP
3. If no, proceed with provided requirements

---

## Configuration Reference

### Skill Config (.claude/skills/tempest-coverage/config.json)

```json
{
  "jira_integration": {
    "enabled": true,
    "use_mcp_if_available": true,
    "default_jira_url": "https://issues.redhat.com",
    "ticket_id_patterns": [
      "RHEL-\\d+",
      "OSPRH-\\d+",
      "OSASINFRA-\\d+",
      "[A-Z]+-\\d+"
    ],
    "fields_to_extract": [
      "summary",
      "description",
      "acceptance_criteria",
      "components",
      "labels",
      "status",
      "assignee",
      "comments"
    ],
    "search_related_tickets": true,
    "max_related_tickets": 5
  }
}
```

### MCP Server Config (.claude/settings.json)

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-jira"],
      "env": {
        "JIRA_URL": "https://issues.redhat.com",
        "JIRA_USERNAME": "${JIRA_USERNAME}",
        "JIRA_API_TOKEN": "${JIRA_API_TOKEN}"
      }
    }
  }
}
```

---

## Troubleshooting

### "Jira MCP tools not available"

**Check:**
```bash
# Verify MCP server is configured
cat .claude/settings.json | grep -A 10 mcpServers

# Test environment variables
echo $JIRA_URL
echo $JIRA_USERNAME
```

**Solution:**
- Ensure MCP server is properly configured in settings.json
- Restart Claude Code after changing settings
- Verify credentials are correct

### "Authentication failed"

**Check:**
- API token is valid and not expired
- Username is correct
- Jira URL is accessible

**Test manually:**
```bash
curl -u "your-email@redhat.com:your-api-token" \
  "https://issues.redhat.com/rest/api/2/issue/RHEL-12345"
```

### "Issue not found"

**Check:**
- Ticket ID is correct (e.g., RHEL-12345 not RHEL12345)
- You have permission to view the ticket
- Ticket exists and is not deleted

### "Rate limiting"

Jira APIs have rate limits. If you hit them:
- Wait a few minutes
- Reduce number of requests
- Contact your Jira admin for higher limits

---

## Security Best Practices

### ✅ DO:
- Store credentials in environment variables
- Use `.env` file (git-ignored)
- Use API tokens instead of passwords
- Rotate API tokens regularly
- Use least-privilege access (read-only for fetching)

### ❌ DON'T:
- Commit credentials to git
- Share API tokens
- Use admin accounts for automation
- Store tokens in plain text in shared locations

---

## Advanced Usage

### Custom JQL Queries

The skill can search with custom JQL:

```
/tempest-coverage

Search for: project=RHEL AND component=Cinder AND status="In Progress" AND labels=rbac-testing
```

### Batch Processing

Process multiple tickets:

```
/tempest-coverage

Implement tests for tickets: RHEL-12345, RHEL-12346, RHEL-12347
```

### Related Ticket Analysis

The skill can analyze related tickets:

```
/tempest-coverage RHEL-12345

Also check related tickets for additional requirements
```

---

## Summary

**Setup steps:**
1. ✅ Install Jira MCP server (npx or npm)
2. ✅ Get Jira API token
3. ✅ Configure `.claude/settings.json` with MCP server
4. ✅ Store credentials securely (env vars or .env)
5. ✅ Test: `/tempest-coverage RHEL-12345`

**Benefits:**
- ✅ Automatic ticket fetching
- ✅ No manual copy/paste
- ✅ Access to all ticket fields
- ✅ Search capabilities
- ✅ Related ticket analysis

**Fallback:**
- If MCP not available, skill still works
- User provides ticket details manually
- No functionality lost

---

**Ready to use Jira MCP integration! 🎯**
