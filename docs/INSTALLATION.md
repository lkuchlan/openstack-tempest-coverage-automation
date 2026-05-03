# Installation Guide

Comprehensive installation guide for OpenStack Tempest Coverage Automation.

## Prerequisites

### Required
- **Claude Code** - Version 1.x or later ([claude.ai/code](https://claude.ai/code))
- **Python 3.8+** - For Tempest validation with tox
- **git** - Version control

### Recommended
- **tox** - Test validation (`pip install tox`)
- **Tempest repositories** - Cloned locally for pattern discovery

### Optional
- **Jira MCP server** - For automatic ticket fetching
- **npm** - For MCP server installation

## Installation Methods

See [QUICKSTART.md](QUICKSTART.md) for quick 5-minute setup, or [README.md](../README.md) for detailed installation methods:

1. Git clone + setup script (recommended)
2. Direct download (air-gapped environments)
3. Manual installation

## Verification

After installation, verify:

```bash
# Skills installed
ls -la ~/.claude/skills/
# Should see: jira-coverage-analysis, implement-tempest-tests, tempest-coverage

# Test skills
claude
> /jira-coverage-analysis --help
> /implement-tempest-tests --help
```

## Configuration

### Repository Paths

Edit `~/.claude/skills/tempest-coverage/config.json`:

```json
{
  "repository_paths": {
    "tempest": ["~/tempest-workspace/tempest"],
    "plugins": {
      "cinder": "~/tempest-workspace/cinder-tempest-plugin",
      "manila": "~/tempest-workspace/manila-tempest-plugin"
    }
  }
}
```

### Jira MCP (Optional)

See [JIRA_SETUP.md](JIRA_SETUP.md) for complete Jira MCP configuration.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

## Next Steps

- [QUICKSTART.md](QUICKSTART.md) - 5-minute guide
- [JIRA_SETUP.md](JIRA_SETUP.md) - MCP configuration
- [EXAMPLES.md](EXAMPLES.md) - Usage examples
