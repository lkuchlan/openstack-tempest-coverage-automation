# Permissions Guide for Claude Code

This guide explains how to configure permissions in the claude-automation project.

## Understanding Claude Code Permissions

Claude Code uses a **permission system** where you approve tool calls at runtime. The settings.json file has limited permission configuration options.

## Current Configuration

**File:** `.claude/settings.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation"
  }
}
```

This is a minimal, valid configuration.

## How to Reduce Permission Prompts

### Option 1: Use the /fewer-permission-prompts Skill

Claude Code has a built-in skill that analyzes your usage and creates optimized permission settings:

```bash
# After using the tempest-coverage skill a few times, run:
/fewer-permission-prompts
```

This will automatically generate allowlists based on your actual usage patterns.

### Option 2: Grant Permissions at Runtime

When Claude asks for permission to run a command:
- **Allow Once** - Run this time only
- **Allow Similar** - Remember for similar commands
- **Allow for Session** - Remember for this session
- **Always Allow** - Remember permanently

Choose **"Always Allow"** for common commands like:
- `tox -e pep8`
- `tox -e py3`
- `git status`
- `git diff`
- `find` commands
- `grep` commands

### Option 3: Manual Permissions Configuration

For advanced users, you can manually configure permissions using the `/update-config` skill:

```bash
/update-config
```

Then ask to add specific Bash command permissions.

## Recommended Workflow

### For Tempest Testing

When using the tempest-coverage skill, you'll commonly see prompts for:

1. **Repository Discovery**
   - `find` commands to locate Tempest repos
   - `grep` commands to search for patterns
   - Grant: **Always Allow**

2. **Git Operations**
   - `git status`
   - `git diff`
   - `git log`
   - `git branch`
   - `git checkout -b`
   - Grant: **Always Allow**

3. **Validation**
   - `tox -e pep8`
   - `tox -e py3`
   - Grant: **Always Allow**

4. **File Reading**
   - `Read` tool calls
   - Grant: **Allow Similar** or **Always Allow**

### First-Time Setup

1. **Start Claude Code:**
   ```bash
   cd /Users/lironkuchlani/claude-automation
   claude
   ```

2. **Use the skill:**
   ```
   /tempest-coverage
   
   I need a simple test for Cinder volume creation
   ```

3. **Grant permissions as prompted:**
   - Click "Always Allow" for safe, read-only commands
   - Review carefully for write operations (git commit, edit files)

4. **After a few uses, optimize:**
   ```
   /fewer-permission-prompts
   ```

## Environment Variables

Environment variables can be set in `.claude/settings.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation",
    "TEMPEST_CONFIG": "/path/to/tempest.conf",
    "DEBUG": "false"
  }
}
```

## Hooks Configuration

Claude Code supports various hook events. For Tempest workflows, useful hooks include:

### Example: SessionStart Hook

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "SessionStart": [
      {
        "command": "echo 'Welcome to claude-automation! Use /tempest-coverage to get started.'"
      }
    ]
  }
}
```

### Valid Hook Events

According to the error message, valid events are:
- `PreToolUse`
- `PostToolUse`
- `PostToolUseFailure`
- `PostToolBatch`
- `Notification`
- `UserPromptSubmit`
- `UserPromptExpansion`
- `SessionStart`
- `SessionEnd`
- `Stop`
- `StopFailure`
- `SubagentStart`
- `SubagentStop`
- `PreCompact`
- `PostCompact`
- `PermissionRequest`
- `PermissionDenied`
- `Setup`
- `TeammateIdle`
- `TaskCreated`
- `TaskCompleted`
- `Elicitation`
- `ElicitationResult`
- `ConfigChange`
- `WorktreeCreate`
- `WorktreeRemove`
- `InstructionsLoaded`
- `CwdChanged`
- `FileChanged`

### Example: PostToolUse Hook for Validation

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PostToolUse": [
      {
        "tool": "Write",
        "pattern": "**/*_test.py",
        "command": "echo 'Test file created: {{file_path}}'"
      }
    ]
  }
}
```

## Global vs. Project Settings

### Global Settings
**Location:** `~/.claude/settings.json`

Applies to all Claude Code sessions.

### Project Settings
**Location:** `/Users/lironkuchlani/claude-automation/.claude/settings.json`

Applies only when working in this directory. **Overrides** global settings.

### Strategy

- **Global:** Set permissions for commonly used safe commands
- **Project:** Set project-specific environment variables

## Security Best Practices

### Safe to "Always Allow"
✅ Read operations (`Read`, `cat`, `grep`, `find`)
✅ Git read operations (`git status`, `git diff`, `git log`)
✅ Listing operations (`ls`, `tree`)
✅ Validation (`tox -e pep8`, `tox -e py3`)

### Review Carefully
⚠️ Write operations (`Write`, `Edit`, `echo >`)
⚠️ Git write operations (`git commit`, `git push`)
⚠️ File deletion (`rm`, `git clean`)
⚠️ System commands (`sudo`, `chmod`, `chown`)

### Never Auto-Allow
❌ Destructive operations (`rm -rf`, `git reset --hard`)
❌ Network operations without review
❌ Execution of unknown scripts

## Troubleshooting

### "Too many permission prompts"

**Solution:**
```bash
# Use the built-in skill after a few sessions
/fewer-permission-prompts
```

This analyzes your usage and creates an optimized allowlist.

### "Permission denied"

**Solution:**
- Check you have correct file permissions
- Check you're in the right directory
- Review the command Claude is trying to run

### "Settings validation errors"

**Solution:**
- Ensure `$schema` is exactly: `https://json.schemastore.org/claude-code-settings.json`
- Validate JSON syntax: `jq empty .claude/settings.json`
- Check hook event names against valid list above

## Example: Complete settings.json

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  
  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation",
    "TEMPEST_CONFIG": "/Users/lironkuchlani/automation_projects/tempest/etc/tempest.conf"
  },
  
  "hooks": {
    "SessionStart": [
      {
        "command": "echo 'Claude Automation Project - Tempest Coverage Skill Available'"
      }
    ],
    "TaskCompleted": [
      {
        "command": "echo 'Task completed: {{task_subject}}'"
      }
    ]
  }
}
```

## Learning More

- **Official Docs:** https://code.claude.com/docs/en/hooks
- **Update Config:** Use `/update-config` skill
- **Reduce Prompts:** Use `/fewer-permission-prompts` skill
- **JSON Schema:** https://json.schemastore.org/claude-code-settings.json

## Summary

1. ✅ Start with minimal settings.json
2. ✅ Grant permissions at runtime ("Always Allow" for safe commands)
3. ✅ After a few sessions, run `/fewer-permission-prompts`
4. ✅ Use hooks for automation (optional)
5. ✅ Keep security in mind - review write operations

**Current valid settings.json:**
```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "PROJECT_ROOT": "/Users/lironkuchlani/claude-automation"
  }
}
```

**No errors! ✅**
