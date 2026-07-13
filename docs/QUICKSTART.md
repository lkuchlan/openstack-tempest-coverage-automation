# Quick Start Guide

Get up and running with OpenStack Tempest Coverage Automation in 5 minutes.

## Prerequisites

- Claude Code installed ([claude.ai/code](https://claude.ai/code))
- Python 3.8+
- tox installed
- Tempest repositories cloned locally

## Installation

```bash
# 1. Clone repository
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# 2. Run setup
./scripts/setup.sh

# 3. Start Claude Code
claude
```

## First Analysis

```bash
# In Claude Code
> /jira-coverage-analysis OSPRH-22613

# Or without Jira MCP
> /jira-coverage-analysis

# Provide ticket details when prompted:
# - Service: Cinder
# - Feature: Volume multi-attach
# - Requirements: Test RBAC scenarios
```

**Output:** Structured analysis report with:
- Existing coverage found
- Gaps identified (HIGH/MEDIUM/LOW)
- Effort estimates
- Implementation recommendations

## First Implementation

```bash
# After reviewing analysis
> /implement-tempest-tests OSPRH-22613

# Claude will:
# 1. Find implementation patterns
# 2. Generate tests
# 3. Create git branch
# 4. Run tox validation
# 5. Commit code
```

**Result:**
- Branch: `tempest-coverage-OSPRH-22613`
- Tests: `cinder_tempest_plugin/api/volume/test_multiattach_rbac.py`
- Validated: `tox -e pep8,py3` passed

## Submit to Gerrit

After verification, the pipeline pushes the branch to a GitHub fork and posts fetch
instructions as a Jira comment. Check the ticket for the exact commands, then run on
your local machine inside your plugin clone:

```bash
git fetch ssh://git@github.com/lkuchlan/cinder-tempest-plugin tempest-coverage-OSPRH-22613
git checkout tempest-coverage-OSPRH-22613
git review
```

After `git review` completes, mark the ticket as submitted:

```bash
# In Claude Code
> /orchestrator OSPRH-22613 --submitted <gerrit_url>
```

## Optional: Jira MCP Setup

Install `uv`:
```bash
brew install uv    # macOS
pip install uv     # or via pip
```

Edit `.env`:
```bash
JIRA_URL=https://issues.redhat.com
JIRA_USERNAME=your.email@company.com
JIRA_API_TOKEN=your-api-token-here
```

Add to `.claude/settings.json`:
```json
{
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
  }
}
```

## Common Workflows

### Sprint Planning
```bash
# Analyze multiple tickets
> /jira-coverage-analysis OSPRH-1 OSPRH-2 OSPRH-3

# Get combined effort estimate
# Plan sprint capacity
```

### Batch Implementation
```bash
# Implement tickets in priority order
> /implement-tempest-tests OSPRH-1
> /implement-tempest-tests OSPRH-2
```

## Troubleshooting

**Skills not found?**
```bash
# Verify skills installed
ls -la ~/.claude/skills/
# Should see: jira-coverage-analysis, implement-tempest-tests, tempest-coverage
```

**Repository paths wrong?**
```bash
vi ~/.claude/skills/tempest-coverage/config.json
# Update paths to your Tempest repos
```

**Validation failing?**
```bash
# Check tox works
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
tox -e pep8
```

## Next Steps

- Read [INSTALLATION.md](INSTALLATION.md) for detailed setup
- See [EXAMPLES.md](EXAMPLES.md) for real-world workflows
- Check [JIRA_SETUP.md](JIRA_SETUP.md) for MCP configuration
- Review [CLAUDE.md](../CLAUDE.md) for Tempest standards

## Support

- **Documentation:** [README.md](../README.md)
- **Issues:** [GitHub Issues](https://github.com/lkuchlan/openstack-tempest-coverage-automation/issues)
- **Help:** Ask in Claude Code: "How do I use the jira-coverage-analysis skill?"
