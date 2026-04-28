# Troubleshooting Guide

Common issues and solutions for OpenStack Tempest Coverage Automation.

## Installation Issues

### Skills Not Found

**Symptom:** `/jira-coverage-analysis` command not recognized

**Solution:**
```bash
# Verify skills installed
ls -la ~/.claude/skills/
# Should see: jira-coverage-analysis, implement-tempest-tests, tempest-coverage

# If missing, re-run setup
cd /path/to/openstack-tempest-coverage-automation
./scripts/setup.sh

# Verify symlinks
ls -l ~/.claude/skills/jira-coverage-analysis
# Should point to repository location
```

### Claude Code Not Found

**Symptom:** `claude: command not found` during setup

**Solution:**
```bash
# Install Claude Code from https://claude.ai/code
# Verify installation
which claude

# Add to PATH if needed (check installation docs)
```

## Configuration Issues

### Repository Paths Not Found

**Symptom:** "Repository not found" errors during analysis

**Solution:**
```bash
# Edit shared config
vi ~/.claude/skills/tempest-coverage/config.json

# Update repository paths:
{
  "repository_paths": {
    "tempest": ["~/tempest-workspace/tempest"],
    "plugins": {
      "cinder": "~/tempest-workspace/cinder-tempest-plugin"
    }
  }
}

# Verify paths exist
ls ~/tempest-workspace/cinder-tempest-plugin
```

### Jira MCP Not Working

**Symptom:** Skills prompt for ticket details instead of fetching automatically

**Solutions:**

**1. Check .env file:**
```bash
# Verify .env exists and has credentials
cat .env
# Should show JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN

# Verify not git-ignored (should NOT show in git status)
git status | grep .env
# Should be empty
```

**2. Check MCP configuration:**
```bash
# Verify settings.json has jira MCP server
cat .claude/settings.json | grep -A10 mcpServers

# Should see jira configuration
```

**3. Test MCP connection:**
```bash
# Start Claude and check for MCP errors
claude
# Look for "Jira MCP server started" message

# If errors, check npm:
npm --version
```

**4. Alternative: Manual input**
```bash
# Skills work without MCP - just provide details manually
> /jira-coverage-analysis

# When prompted, enter:
# - Ticket ID
# - Summary
# - Requirements
```

## Validation Issues

### Tox Validation Failing

**Symptom:** Generated tests fail `tox -e pep8` or `tox -e py3`

**Solutions:**

**1. Check tox installation:**
```bash
cd ~/tempest-workspace/cinder-tempest-plugin
tox --version

# Install if missing
pip install tox
```

**2. Check specific errors:**
```bash
# Run tox manually to see full errors
tox -e pep8

# Common issues:
# - Import errors: Missing dependencies
# - Style errors: Usually auto-fixed by implementation skill
# - Test errors: Check base class and client usage
```

**3. Re-run implementation:**
```bash
# If tests are fundamentally wrong, re-run implementation
# with more specific requirements
> /implement-tempest-tests TICKET-123

# Provide detailed scenarios when prompted
```

### Pre-commit Hooks Blocking Commits

**Symptom:** Hooks detect violations and block commit

**Solution:**
```bash
# Read the error messages carefully - they're specific
# Example error:
# ❌ Waiter violations in test_file.py:
#    Line 45: Using time.sleep() - Use Tempest waiters

# Fix the violation:
# Before: time.sleep(10)
# After: waiters.wait_for_volume_resource_status(...)

# Commit again
git commit -m "Fix waiter usage"
# ✅ Should pass

# To bypass (NOT RECOMMENDED):
git commit --no-verify
```

## Skill Execution Issues

### Analysis Taking Too Long

**Symptom:** Analysis runs for > 10 minutes

**Possible causes:**
- Very large repository (1000+ files)
- Slow disk I/O
- Explore agent searching too broadly

**Solutions:**
```bash
# 1. Provide specific file paths to skip exploration
> /jira-coverage-analysis TICKET-123
# When prompted, mention specific test files

# 2. Check repository size
cd ~/tempest-workspace/cinder-tempest-plugin
find . -name "*.py" | wc -l
# If > 1000 files, consider optimizing search

# 3. Analysis typically < 5 min - if longer, interrupt and retry
```

### Implementation Not Following Standards

**Symptom:** Generated tests don't use proper base classes or clients

**Solution:**
```bash
# Check CLAUDE.md is in repository
ls /path/to/openstack-tempest-coverage-automation/CLAUDE.md

# Skills read CLAUDE.md for standards
# If tests are still wrong, file an issue with example
```

## Git Workflow Issues

### Branch Already Exists

**Symptom:** "Branch tempest-coverage-TICKET already exists"

**Solution:**
```bash
cd ~/tempest-workspace/cinder-tempest-plugin

# Delete old branch
git branch -D tempest-coverage-TICKET-123

# Or use different branch name
> /implement-tempest-tests TICKET-123
# Skill will handle existing branch
```

### Commit Failed

**Symptom:** Git commit fails with pre-commit hook errors

**Solution:**
```bash
# Review hook errors
# Fix violations
# Commit will succeed after fixes

# If hooks are incorrect, file an issue
# Temporary bypass (not recommended):
git commit --no-verify
```

## Permission Issues

### Permission Prompts for Read Operations

**Symptom:** Claude asks permission for `mcp__jira__get_issue`

**Solution:**
```bash
# Add to .claude/settings.json permissions.allow:
{
  "permissions": {
    "allow": [
      "mcp__jira__get_issue",
      "mcp__jira__search_issues",
      "mcp__jira__get_epic_children"
    ]
  }
}

# See examples/settings.json.example for full list
```

## Getting Help

**Still stuck?**

1. **Check documentation:**
   - [README.md](../README.md) - Main docs
   - [QUICKSTART.md](QUICKSTART.md) - Setup guide
   - [CLAUDE.md](../CLAUDE.md) - Standards

2. **Search issues:**
   - [GitHub Issues](https://github.com/your-org/openstack-tempest-coverage-automation/issues)
   - Check for similar problems

3. **Ask Claude:**
   ```bash
   claude
   > How do I configure Jira MCP for the jira-coverage-analysis skill?
   ```

4. **Open an issue:**
   - Provide error messages
   - Include steps to reproduce
   - Mention Claude Code version
   - Include relevant configuration

5. **Discussions:**
   - [GitHub Discussions](https://github.com/your-org/openstack-tempest-coverage-automation/discussions)
   - Ask questions
   - Share tips

## Debug Mode

Enable verbose logging:

```bash
# Run Claude with debug flag
claude --debug

# Check logs
tail -f ~/.claude/logs/latest.log
```

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Repository not found" | Invalid path in config.json | Update repository_paths |
| "Jira MCP connection failed" | Invalid credentials or MCP not configured | Check .env and settings.json |
| "Tox validation failed" | Test code errors | Review tox output, fix errors |
| "Skill not found" | Skills not installed | Run ./scripts/setup.sh |
| "Pre-commit hook failed" | Code violations | Read error, fix violation |
| "Permission denied" | Missing allow rule | Add to permissions.allow |

## Reset and Start Fresh

If all else fails:

```bash
# 1. Remove installed skills
rm -rf ~/.claude/skills/jira-coverage-analysis
rm -rf ~/.claude/skills/implement-tempest-tests
rm -rf ~/.claude/skills/tempest-coverage

# 2. Re-clone repository
cd ~
rm -rf openstack-tempest-coverage-automation
git clone https://github.com/your-org/openstack-tempest-coverage-automation.git

# 3. Re-run setup
cd openstack-tempest-coverage-automation
./scripts/setup.sh

# 4. Reconfigure
vi .env
vi ~/.claude/skills/tempest-coverage/config.json

# 5. Test
claude
> /jira-coverage-analysis --help
```
