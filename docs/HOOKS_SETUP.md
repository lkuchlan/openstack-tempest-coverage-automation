# Pre-commit Hooks Setup Guide

Complete guide for setting up Tempest pre-commit hooks with both manual and automatic installation options.

---

## Why Pre-commit Hooks?

Pre-commit hooks provide **automatic quality enforcement** for both AI-generated and human-written code:

✅ **Catch violations before commit** - Not after tox or CI  
✅ **Fast feedback** - Seconds instead of minutes  
✅ **Enforce Tempest standards** - No time.sleep(), proper base classes, required cleanup  
✅ **Self-correcting AI** - Claude sees errors and fixes automatically  
✅ **Works for everyone** - Human developers benefit too

### The Quality Pipeline:

```
Layer 1: CLAUDE.md          → Claude tries to write correct code
Layer 2: Pre-commit Hooks   → Catches mistakes before commit
Layer 3: Tox Validation     → Full test suite validation
```

---

## Installation Options

Choose the method that works best for you:

### Option 1: Manual Installation (Recommended for Most Users)

**Best for:**
- First-time users
- Teams with mixed tooling (not everyone uses Claude Code)
- When you want explicit control

**Steps:**

For each Tempest plugin repository:

```bash
# Cinder
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
~/openstack-tempest-coverage-automation/hooks/install-hooks.sh

# Manila
cd $TEMPEST_WORKSPACE/manila-tempest-plugin
~/openstack-tempest-coverage-automation/hooks/install-hooks.sh

# Repeat for: glance, barbican, keystone, etc.
```

**What it does:**
- Copies pre-commit hook to `.git/hooks/pre-commit`
- Copies validation scripts to `.git/hooks/checks/`
- Makes them executable

**Time:** ~30 seconds per repository

---

### Option 2: Automatic Installation (Advanced)

**Best for:**
- Power users who want automation
- Working across many Tempest repositories
- When you always use Claude Code

**Steps:**

**1. Copy the hooks auto-install configuration:**

Add to `.claude/settings.json` (or `~/.claude/settings.json` for global):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git *)",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/skills/tempest-coverage/auto-install-hooks.sh"
          }
        ]
      }
    ]
  }
}
```

**2. That's it!**

Hooks will auto-install the first time Claude enters any Tempest repository.

**What it does:**
1. Before Claude runs any Bash command
2. Detects if current directory is a Tempest repository
3. Checks if hooks already installed
4. If not installed → Installs them silently
5. Shows message: "Auto-installed Tempest pre-commit hooks in cinder-tempest-plugin"

**Time:** One-time setup, then automatic forever

---

## How Hooks Work

Once installed (via either method):

### Normal Workflow:

```bash
# You (or Claude) make changes
$ vim test_volume_multiattach.py

# Stage changes
$ git add test_volume_multiattach.py

# Attempt commit
$ git commit -m "Add volume multi-attach test"

# Git automatically runs: .git/hooks/pre-commit
🔍 Checking OpenStack Tempest test standards...
[1/1] Checking: test_volume_multiattach.py
✅ All checks passed!

[main abc1234] Add volume multi-attach test
 1 file changed, 85 insertions(+)
```

### When Violations Found:

```bash
$ git commit -m "Add test"

# Hook runs:
🔍 Checking OpenStack Tempest test standards...
[1/1] Checking: test_example.py

❌ Waiter violations in test_example.py:
   Line 45: Using time.sleep() - Use Tempest waiters instead
   
   💡 Fix: Use Tempest waiters instead of sleep/polling
   Examples:
     waiters.wait_for_volume_resource_status(client, vol_id, 'available')

❌ Tempest standards violations found!

# Commit BLOCKED - fix the code and try again
```

**If Claude is committing:** Claude automatically reads the error, fixes the code, and retries.

---

## What Hooks Check

Four validation scripts run on every test file (`test_*.py`):

### 1. **check-tempest-imports.py**
- ❌ Blocks: `import requests`, `import urllib`, `import urllib3`
- ✅ Requires: `from tempest.lib import decorators` (if test methods present)
- **Why:** Tempest has service clients - never use raw HTTP

### 2. **check-base-classes.py**
- ❌ Blocks: Inheriting from `unittest.TestCase`
- ✅ Requires: Tempest base classes (`BaseVolumeTest`, `BaseSharesTest`, etc.)
- **Why:** Proper base classes provide fixtures and cleanup

### 3. **check-waiters.py**
- ❌ Blocks: `time.sleep()`, manual polling loops
- ✅ Requires: `waiters.wait_for_*_status()` methods
- **Why:** Waiters provide timeout handling and better errors

### 4. **check-cleanup.py**
- ❌ Blocks: Resource creation without `self.addCleanup()`
- ✅ Requires: Cleanup for all created resources
- **Why:** Tests must clean up - no resource leaks

---

## Bypassing Hooks (NOT Recommended)

```bash
# Skip hooks (emergency only)
git commit --no-verify -m "Emergency fix"
```

**Don't do this unless:**
- Emergency production fix needed immediately
- You understand the violation and will fix it later
- You've documented why in the commit message

**Note:** Claude is instructed to NEVER use `--no-verify`

---

## Verifying Installation

### Check if hooks installed:

```bash
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
ls -la .git/hooks/pre-commit
ls -la .git/hooks/checks/
```

Should show:
```
-rwxr-xr-x  1 user  staff  3829 Apr 27 12:31 .git/hooks/pre-commit
drwxr-xr-x  6 user  staff   192 Apr 27 12:32 .git/hooks/checks/
```

### Test hooks:

```bash
# Create test file with violation
echo 'import time

class Test:
    def test_something(self):
        time.sleep(10)' > test_example.py

# Try to commit
git add test_example.py
git commit -m "test"

# Should see:
# ❌ Waiter violations in test_example.py:
#    Line 5: Using time.sleep() - Use Tempest waiters instead

# Clean up
git reset HEAD test_example.py
rm test_example.py
```

---

## Uninstalling Hooks

If you need to remove hooks:

```bash
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
rm .git/hooks/pre-commit
rm -rf .git/hooks/checks/
```

---

## Troubleshooting

### Hooks not running

**Check 1:** Verify hooks installed
```bash
ls -la .git/hooks/pre-commit
# Should exist and be executable
```

**Check 2:** Verify in git repository
```bash
git status
# Should show git status, not "not a git repository"
```

**Check 3:** Test hook directly
```bash
.git/hooks/pre-commit
# Should run (may say "no test files staged")
```

### Hooks fail with "command not found"

**Problem:** Python not in PATH

**Fix:**
```bash
which python3
# Should show path to python3
# If not found: install Python 3.8+
```

### False positives

**Problem:** Hook blocks valid code

**Solution:**
1. Check if code really follows Tempest standards
2. If it's a bug in the hook, file an issue
3. Temporary bypass: `git commit --no-verify` (document why)

---

## For Team Leads

### Rolling Out to Teams

**Option A: Manual (Simpler)**
- Add to onboarding docs
- Each developer runs install-hooks.sh
- Takes 5 minutes per developer

**Option B: Automatic (More Advanced)**
- Add hooks config to team's shared `.claude/settings.json`
- Commit to repository
- Developers get auto-install when using Claude Code
- Humans still need manual install for non-Claude commits

**Recommendation:** Start with Manual (A), add Automatic (B) later for Claude users

### Enforcement Policy

Suggested policy:
```
✅ Hooks are REQUIRED for all Tempest test commits
✅ Violations must be fixed, not bypassed
⚠️  Emergency bypass allowed with explanation in commit message
📝 Document any persistent false positives as issues
```

---

## FAQ

**Q: Do I need to install hooks in every Tempest repo?**  
A: With manual installation - yes. With automatic installation - no, happens automatically.

**Q: Do hooks slow down commits?**  
A: Minimal - usually <1 second per test file.

**Q: Can I customize which checks run?**  
A: Yes - edit `.git/hooks/pre-commit` or the check scripts in `.git/hooks/checks/`

**Q: Do hooks work with git rebase?**  
A: Yes - they run on every commit created during rebase.

**Q: What if I have custom Tempest patterns?**  
A: Edit the check scripts or add to `.git/hooks/checks/` for custom validations.

**Q: Do hooks work in CI?**  
A: Hooks are local only. For CI, run the check scripts directly in your CI pipeline.

---

## Next Steps

- ✅ Choose installation method (manual or automatic)
- ✅ Install hooks in your Tempest repositories  
- ✅ Test with `/implement-tempest-tests` skill
- ✅ Watch hooks catch violations automatically
- ✅ Share with your team

**See also:**
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [EXAMPLES.md](EXAMPLES.md) - Real-world workflows
- [CLAUDE.md](../CLAUDE.md) - Pre-commit hook instructions for Claude
