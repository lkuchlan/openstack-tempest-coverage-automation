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

### Tox Validation Fails

**Symptom:** `tox -e pep8` or `tox -e py3` reports errors

**Solution:**
```bash
# Read the tox output carefully - it shows specific violations
# Example error:
# E501 line too long (120 > 79 characters)
# F401 'time' imported but unused

# Fix the violations:
# - Shorten lines
# - Remove unused imports
# - Fix import ordering

# Run tox again
tox -e pep8
# ✅ Should pass
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

**Symptom:** Git commit fails

**Solution:**
```bash
# Check git status
git status

# Ensure files are staged
git add file.py

# Retry commit
git commit -m "Your message"

# If still failing, check git output for specific error
```

## Permission Issues

### Permission Prompts for Read Operations

**Symptom:** Claude asks permission for `mcp__mcp-atlassian__get_issue`

**Solution:**
```bash
# Add to .claude/settings.json permissions.allow:
{
  "permissions": {
    "allow": [
      "mcp__mcp-atlassian__get_issue",
      "mcp__mcp-atlassian__search_issues",
      "mcp__mcp-atlassian__get_epic_children"
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
   - [GitHub Issues](https://github.com/lkuchlan/openstack-tempest-coverage-automation/issues)
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
   - [GitHub Discussions](https://github.com/lkuchlan/openstack-tempest-coverage-automation/discussions)
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
| "Tox validation failed" | Code style/quality issues | Read error, fix violation |
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
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git

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

---

## Skills Usage Issues

### Skills Can't Find Tempest Repositories

**Symptom:** "Repository not found" or "Could not locate cinder-tempest-plugin"

**Solutions:**

**1. Update repository paths in config:**
```bash
vi ~/.claude/skills/tempest-coverage/config.json

# Update paths to your actual locations:
{
  "default_repo_paths": {
    "tempest": ["~/tempest-workspace/tempest"],
    "plugins": {
      "cinder-tempest-plugin": ["~/tempest-workspace/cinder-tempest-plugin"]
    }
  }
}
```

**2. Verify repositories exist:**
```bash
ls $TEMPEST_WORKSPACE/
# Should show: tempest, cinder-tempest-plugin, manila-tempest-plugin, etc.

ls ~/tempest-workspace/cinder-tempest-plugin/
# Should show plugin structure
```

**3. Skills behavior:**
- Skills will note missing repos in analysis reports
- Analysis continues with available information
- Implementation may require manual repository setup

---

### Jira MCP Connection Fails

**Symptom:** "Jira MCP server not available" or manual prompts instead of auto-fetch

**Solutions:**

**1. Check .env file:**
```bash
cat .env
# Should contain:
# JIRA_URL="https://issues.redhat.com"
# JIRA_USERNAME="your-email@redhat.com"  
# JIRA_API_TOKEN="your-token"
```

**2. Verify MCP server is configured:**
```bash
# Check settings.json for mcp-atlassian server
cat ~/.claude/settings.json | grep -A10 mcpServers

# Should see jira/mcp-atlassian configuration
```

**3. Test credentials:**
```bash
# Try fetching a ticket
/jira-coverage-analysis TICKET-123

# If credentials invalid, will show error
```

**4. Fallback to manual input:**
- Skills work without Jira MCP
- Just provide ticket details when prompted
- Same quality output, manual entry

**Note:** See [JIRA_SETUP.md](JIRA_SETUP.md) for detailed MCP configuration.

---

### Posting to Jira Fails (post-test-plan)

**Symptom:** "Failed to post comment" or "Jira is in read-only mode"

**Solutions:**

**1. Check write permissions:**
```bash
# MCP server must have write mode enabled
# Check mcp-atlassian configuration in settings.json
# READ_ONLY_MODE should be "false" or not set
```

**2. Verify Jira permissions:**
- Your Jira account must have comment permissions
- Check ticket is not locked or archived
- Verify you can manually comment on the ticket

**3. Use manual fallback:**
```bash
/post-test-plan TICKET-123

# If posting fails, skill shows formatted plan:
# "Here's the formatted plan to copy-paste into Jira"

# Copy the markdown and paste as comment manually
```

**4. Enable write mode:**
- See [post-test-plan skill documentation](../skills/post-test-plan/README.md)
- Update MCP server configuration to allow writes
- Requires admin access to settings.json

---

### Approval Monitor Shows "NEEDS DISCUSSION"

**Symptom:** The approval-monitor agent prints a `⚠️ NEEDS DISCUSSION` summary instead of APPROVED / REJECTED / TIMED_OUT.

**Cause:** A stakeholder left a comment on the test plan that was neither an approval keyword ("Approved", "LGTM") nor a rejection keyword ("Rejected", "NAK"). This could be a question, a concern, or a request for changes.

**What to do:**

1. **Read the stakeholder's comment** in Jira to understand the feedback
2. **Address the feedback** — update the test plan or discuss in the ticket
3. **Re-post the revised plan** — the skill picks up `discussion_flagged` automatically:
   ```bash
   /post-test-plan TICKET-ID
   # Uses the revised template (includes "Changes Made" section)
   ```
4. **Approval monitoring continues** — the durable cron keeps running; once the stakeholder comments "Approved", the ticket advances normally

**Note:** The ticket is NOT rejected — it stays at AWAITING_APPROVAL. No action is needed beyond addressing the feedback and re-posting.

---

### Tox Validation Fails

**Symptom:** `tox -e pep8,py3` reports errors after implementation

**Solutions:**

**1. Review tox output:**
```bash
cd ~/tempest-workspace/cinder-tempest-plugin
tox -e pep8

# Read specific errors:
# E501 line too long
# F401 unused import
# E302 expected 2 blank lines
```

**2. Common issues and fixes:**

**Import errors:**
```python
# ❌ WRONG
from tempest.common import waiters
# (not used)

# ✅ FIX: Remove unused import
```

**Style errors:**
```python
# ❌ WRONG - Line too long
volume = self.volumes_client.create_volume(size=1, name='very-long-volume-name-that-exceeds-the-limit')

# ✅ FIX - Break line
volume = self.volumes_client.create_volume(
    size=1,
    name='very-long-volume-name'
)
```

**Test structure:**
```python
# ❌ WRONG - Missing decorators
def test_volume_create(self):
    pass

# ✅ FIX - Add required decorators
@decorators.idempotent_id('uuid-here')
@decorators.attr(type='smoke')
def test_volume_create(self):
    pass
```

**3. Fix violations manually or ask Claude:**
```bash
claude
> The tox validation failed with error "E501 line too long at test_volume.py:42". Please fix it.
```

**4. Re-run validation:**
```bash
tox -e pep8,py3
# ✅ Should pass after fixes
```

---

### Validation Always Skipped

**Symptom:** Ticket validation messages like "⚠️ Validation skipped (disabled in config)"

**Solutions:**

**1. Check validation is enabled:**
```bash
cat ~/.claude/skills/tempest-coverage/config.json | grep -A5 ticket_validation

# Should show:
# "enabled": true
```

**2. Verify MCP is available:**
- Validation requires Jira MCP to check ticket status
- Without MCP, validation is automatically skipped
- Check MCP connection (see above)

**3. Override with --force flag:**
```bash
# If you need to analyze a closed ticket or non-automation ticket:
/jira-coverage-analysis TICKET-123 --force

# This bypasses validation checks
```

---

### Duplicate Plan Detection Not Working

**Symptom:** Multiple test plans posted to same ticket or no duplicate warning

**Solutions:**

**1. Check duplicate detection is enabled:**
```bash
cat ~/.claude/skills/tempest-coverage/config.json | grep -A5 duplicate_detection

# Should show:
# "enabled": true
```

**2. Verify comment markers:**
- Default marker: "🤖 Test Automation Plan"
- Check if your existing plan uses this marker
- Customizable in config.json

**3. Check comment fetch limit:**
- Default checks last 100 comments
- If plan older than 100 comments, may not be detected
- Increase `comment_limit` in config if needed

**4. Bypass duplicate check:**
```bash
# Force post even if duplicate exists:
/post-test-plan TICKET-123 --skip-duplicate-check
```

---

## Security Notes

### Credential Management

**Important security practices:**

**✅ DO:**
- Store credentials in `.env` file (git-ignored)
- Use API tokens, NOT passwords
- Rotate tokens regularly
- Limit token permissions to minimum required
- Store `.env` securely (password manager)

**❌ DON'T:**
- Commit `.env` to git
- Share API tokens
- Use personal passwords
- Store credentials in config.json
- Paste tokens in public channels

**Checking .env is git-ignored:**
```bash
git status | grep .env
# Should be empty (file ignored)

git check-ignore .env
# Should output: .env (file is ignored)
```

**If .env was accidentally committed:**
```bash
# IMMEDIATELY rotate the API token in Jira
# Remove from git history:
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (if you have permission)
git push origin --force --all
```

---

### Data Privacy

**Be aware of sensitive data in outputs:**

**Analysis reports:**
- May contain ticket summaries and descriptions
- Could include internal project details
- Review before sharing publicly

**Generated tests:**
- Use only public OpenStack APIs
- No proprietary logic or credentials
- Safe to upstream to OpenStack community

**Git commits:**
- Commit messages include ticket IDs
- Co-authored by Claude (visible in git log)
- Review before pushing to public repos

---

### Git Safety

**Skills follow safe git practices:**

**✅ Skills WILL:**
- Create feature branches
- Stage and commit changes
- Run tox validation before commit
- Include proper commit messages
- Add co-authorship attribution

**❌ Skills NEVER:**
- Auto-push to remote (user controls)
- Auto-submit to Gerrit (user reviews first)
- Modify main/master directly (always branch)
- Force-push (destructive operation)
- Skip validation (ensures quality)

**Automated pipeline:** After DevStack verification, Stage 6 in `run-pipeline.sh`
pushes the branch to the GitHub fork and posts fetch instructions to the Jira ticket.
The engineer then runs the three commands from the ticket — no VM access needed.

**Direct / manual use:** You decide when to push:
```bash
cd ~/tempest-workspace/cinder-tempest-plugin
git log -1  # Review commit
git diff HEAD~1  # Review changes
git push origin tempest-coverage-TICKET-123  # YOU push when ready
git review
```

---

## See Also

- [Configuration Reference](../references/CONFIGURATION.md) - Detailed config options
- [Tempest Standards](../references/TEMPEST_STANDARDS.md) - Coding standards
- [Examples](EXAMPLES.md) - Common workflows
- [Jira Setup](JIRA_SETUP.md) - MCP server configuration
