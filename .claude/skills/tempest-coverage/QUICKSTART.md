# Quick Start Guide - Tempest Coverage Skill

Get started with the Tempest Coverage skill in 5 minutes.

## Prerequisites

1. **Claude Code** installed and configured
2. **Tempest repositories** cloned locally (tempest core and/or plugins)
3. **Tox** installed for validation

## Step 1: Verify Installation

The skill should already be installed at:
```bash
ls ~/.claude/skills/tempest-coverage/
```

You should see:
```
skill.md
config.json
README.md
EXAMPLES.md
templates/
```

## Step 2: Configure Your Repository Paths

Edit the config file with your actual repository paths:

```bash
# Edit the config
vi ~/.claude/skills/tempest-coverage/config.json
```

Update the paths to match your environment:
```json
{
  "default_repo_paths": {
    "tempest": [
      "/Users/lironkuchlani/automation_projects/tempest"
    ],
    "plugins": {
      "cinder-tempest-plugin": [
        "/Users/lironkuchlani/automation_projects/cinder-tempest-plugin"
      ],
      "manila-tempest-plugin": [
        "/Users/lironkuchlani/automation_projects/manila-tempest-plugin"
      ]
    }
  }
}
```

## Step 3: Test with a Simple Example

Start Claude Code and try a simple test:

```
User: /tempest-coverage

I need a simple volume creation test for Cinder.
The test should create a volume and verify it reaches 'available' status.
```

Expected response:
- Claude will search for existing patterns
- Propose a test implementation
- Create a git branch
- Implement the test
- Validate with tox

## Step 4: Try with a Real Jira Ticket

If you have a Jira ticket:

```
User: /tempest-coverage RHEL-12345
```

Or provide the details:

```
User: Analyze test coverage for the following requirement:

Service: Manila
Feature: Share revert to snapshot
Requirements:
- Admin can revert any share
- Member can revert own share
- Reader cannot revert (negative test)
```

## Step 5: Review the Output

The skill will provide:

1. **Analysis**: What coverage exists, what's missing
2. **Implementation**: Complete test code
3. **Validation**: Results from tox
4. **Git**: Branch and commit info

Example output:
```markdown
# Tempest Coverage Analysis: Your Request

## Summary
- Service: Manila
- Coverage: ⚠️ Partial

## Existing Coverage
- File: manila_tempest_plugin/tests/api/test_shares_actions.py
- Tests: test_share_revert()

## Gaps
- Missing RBAC tests

## Implementation
[Code shown here...]

## Validation
✅ pep8: PASSED
✅ py3: PASSED

## Branch
tempest-coverage-share-revert-rbac
```

## Common Commands

### Invoke the skill directly
```
/tempest-coverage JIRA-12345
```

### Natural language invocation
```
Please analyze Tempest test coverage for [description]
```

### With specific service
```
I need Cinder test coverage for volume multi-attach
```

### For RBAC testing
```
Implement RBAC tests for Manila share extend operation
```

### For scenario testing
```
Create an end-to-end scenario test for volume migration workflow
```

## Validation Workflow

After implementation, the skill automatically:

```bash
# 1. Lint check
cd <repo>
tox -e pep8 -- path/to/new/test.py

# 2. Unit tests
tox -e py3 -- path.to.test.TestClass

# 3. Show results
echo "Validation complete"
```

You can also run manually:
```bash
# Navigate to the repo
cd ~/automation_projects/cinder-tempest-plugin

# Check the branch
git status

# Run tests
tox -e py3 -- cinder_tempest_plugin.api.volume.test_your_new_test
```

## Reviewing Changes

After the skill completes:

```bash
# See what branch was created
cd ~/automation_projects/cinder-tempest-plugin
git branch

# Review changes
git diff main

# See the commit
git log -1

# Run full test suite (optional)
tox
```

## What the Skill Does NOT Do

The skill will NOT:
- ❌ Push code to remote
- ❌ Submit patches to Gerrit
- ❌ Modify main/master directly
- ❌ Guess structure if repo is missing

You remain in control of:
- Reviewing the code
- Running additional tests
- Submitting to code review
- Merging to main

## Troubleshooting

### Issue: "Repository not found"

**Solution:**
```bash
# Check your config paths
cat ~/.claude/skills/tempest-coverage/config.json

# Update with correct paths
# Then re-run the skill
```

### Issue: "tox validation failed"

**Solution:**
The skill will show you the errors. Common fixes:
- Check imports
- Verify base class is correct
- Ensure proper cleanup
- Check indentation

The skill can help fix validation errors - just ask:
```
The pep8 check failed, can you fix the issues?
```

### Issue: "Can't find base class"

**Solution:**
```
The skill will ask you for guidance:
"Multiple base classes found: BaseVolumeTest, BaseVolumeAdminTest
Which should I use?"

Respond with your choice.
```

### Issue: "Unclear requirements"

**Solution:**
Provide more specific details:
- Service name
- API operation
- Expected behavior
- Positive AND negative scenarios

## Next Steps

### 1. Build Memory
Use the skill multiple times. It will learn:
- Common patterns in your repos
- Your preferences
- Service-specific conventions

### 2. Customize Templates
Edit templates in `~/.claude/skills/tempest-coverage/templates/` to match your team's style.

### 3. Share with Team
Once validated, share the skill:
```bash
# Create a git repo
cd ~/.claude/skills/tempest-coverage
git init
git add .
git commit -m "Initial tempest-coverage skill"
git remote add origin <your-repo-url>
git push -u origin main
```

Team members can install:
```bash
git clone <your-repo-url> ~/.claude/skills/tempest-coverage
```

### 4. Contribute Improvements
After using the skill:
- Found a better pattern? Update skill.md
- Discovered a common issue? Add to EXAMPLES.md
- Have a better template? Update templates/

## Tips for Success

### ✅ DO:
- Provide clear, specific requirements
- Mention the service name explicitly
- Review generated code before committing
- Let the skill learn from your feedback
- Use it regularly to build memory

### ❌ DON'T:
- Assume it will push code automatically
- Skip the validation step
- Ignore pep8/py3 failures
- Provide vague requirements
- Expect it to work without local repos

## Example Session

Here's a complete example session:

```
User: /tempest-coverage

I need test coverage for Cinder volume backup with metadata.
The test should:
1. Create a volume
2. Create a backup with custom metadata
3. Verify metadata is stored correctly

---

Claude:
🔍 Searching for existing patterns in cinder-tempest-plugin...

✓ Found base class: BaseVolumeTest
✓ Found client: self.backups_client
✓ Found similar test: test_volume_backup_create()

📊 Analysis:
Existing: Basic backup test exists
Gap: Metadata validation missing

📝 Implementing:
File: cinder_tempest_plugin/api/volume/test_volumes_backup.py
Test: test_backup_create_with_metadata()

[Code implementation shown...]

✅ Validation:
pep8: PASSED
py3: PASSED

🌿 Git:
Branch: tempest-coverage-backup-metadata
Commit: "Add backup metadata test"

---

User: Great! Can you also add a negative test for invalid metadata?

---

Claude:
✓ Adding negative test to same file...

Test: test_backup_create_invalid_metadata_negative()

[Code implementation...]

✅ Validation: PASSED

🌿 Git:
Amended commit with both tests

---

User: Perfect, I'll review and submit to Gerrit

---

Claude:
✅ Ready for review!

To submit:
1. Review: git diff main
2. Run full suite: tox
3. Submit: git review
```

## Getting Help

- **Documentation**: See README.md for full details
- **Examples**: Check EXAMPLES.md for real-world usage
- **Templates**: Review templates/ for test structure
- **Ask Claude**: Just ask "How do I use the tempest-coverage skill for X?"

## Quick Reference Card

```
Command                          Purpose
─────────────────────────────────────────────────────────────
/tempest-coverage JIRA-12345    Analyze Jira ticket
/tempest-coverage               General coverage request

Provide: Service + Feature + Requirements

Output: Analysis + Code + Validation + Git branch

Validation: tox -e pep8 && tox -e py3

Review: git diff main

NO auto-push, NO auto-submit - You control the code review!
```

---

**You're ready!** Start with a simple test and let the skill learn your patterns. 🚀
