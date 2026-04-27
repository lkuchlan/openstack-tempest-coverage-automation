# Claude Code Project Configuration

This directory contains **project-specific** configuration for the `claude-automation` project.

## Directory Structure

```
/Users/lironkuchlani/claude-automation/.claude/
├── README.md                    # This file
├── settings.json                # Project-specific settings (optional)
├── memory/                      # Project-specific memory (auto-created)
├── plans/                       # Project-specific plans (auto-created)
└── skills/                      # Project-specific skills
    └── tempest-coverage/        # Tempest Coverage Skill
```

## How It Works

### Global vs. Project-Specific

When you run Claude Code from this directory, it uses:

1. **Global settings:** `~/.claude/settings.json`
2. **Project settings:** `/Users/lironkuchlani/claude-automation/.claude/settings.json` (overrides global)

3. **Global skills:** `~/.claude/skills/`
4. **Project skills:** `/Users/lironkuchlani/claude-automation/.claude/skills/` (available in this project only)

5. **Global memory:** `~/.claude/memory/`
6. **Project memory:** `/Users/lironkuchlani/claude-automation/.claude/memory/` (project-specific)

### Project-Specific Skills

Skills in `.claude/skills/` are **only available when working in this directory**.

**Current skills:**
- `tempest-coverage` - Automated Tempest test coverage analysis and implementation

**Usage:**
```bash
# Navigate to project
cd /Users/lironkuchlani/claude-automation

# Start Claude Code
claude

# Use the skill
/tempest-coverage JIRA-12345
```

### Memory Isolation

Memory stored in this project's `.claude/memory/` directory:
- Only loaded when working in this directory
- Separate from global memory
- Perfect for project-specific patterns, preferences, and context

### Plans

Plans created while working in this directory are stored in `.claude/plans/`.

## Configuration

### Create Project Settings (Optional)

Create `.claude/settings.json` for project-specific configuration:

```json
{
  "permissions": {
    "allow": [
      {
        "tool": "Bash",
        "command": "tox -e pep8",
        "reason": "Tempest linting"
      },
      {
        "tool": "Bash",
        "command": "tox -e py3",
        "reason": "Tempest tests"
      }
    ]
  },
  "skills": {
    "tempest-coverage": {
      "auto_validate": true
    }
  }
}
```

### Environment Variables

Set project-specific environment variables in `.claude/settings.json`:

```json
{
  "env": {
    "TEMPEST_CONFIG": "/Users/lironkuchlani/automation_projects/tempest/etc/tempest.conf"
  }
}
```

## Using the Tempest Coverage Skill

### Quick Start

1. **Configure repository paths:**
   ```bash
   vi .claude/skills/tempest-coverage/config.json
   ```

2. **Run Claude Code from this directory:**
   ```bash
   cd /Users/lironkuchlani/claude-automation
   claude
   ```

3. **Use the skill:**
   ```
   /tempest-coverage JIRA-12345
   ```

### Documentation

Full documentation available in:
- `.claude/skills/tempest-coverage/README.md` - Complete guide
- `.claude/skills/tempest-coverage/QUICKSTART.md` - Quick start
- `.claude/skills/tempest-coverage/EXAMPLES.md` - Real-world examples

## Version Control

### Git Setup

To track this configuration in git:

```bash
cd /Users/lironkuchlani/claude-automation

# Initialize git if not already done
git init

# Create .gitignore
cat > .gitignore <<EOF
# Claude Code auto-generated
.claude/memory/
.claude/plans/
.claude/*.log

# User-specific config
.claude/settings.local.json
.claude/skills/*/config.local.json
EOF

# Add .claude directory
git add .claude/
git commit -m "Add Claude Code project configuration and Tempest Coverage skill"
```

### What to Track

**Track in git:**
- ✅ `.claude/skills/` - Your custom skills
- ✅ `.claude/settings.json` - Project settings (if no secrets)
- ✅ `.claude/README.md` - This file

**Don't track:**
- ❌ `.claude/memory/` - Auto-generated, contains conversation context
- ❌ `.claude/plans/` - Temporary plans
- ❌ `.claude/settings.local.json` - User-specific overrides
- ❌ `.claude/skills/*/config.local.json` - User-specific skill config

## Benefits of Project-Specific Configuration

### 1. Isolation
- Skills only available where needed
- Memory doesn't pollute global context
- Settings specific to this project

### 2. Collaboration
- Share skills with team via git
- Consistent configuration across team
- Document project-specific workflows

### 3. Organization
- Each project has its own tooling
- No global skill pollution
- Clear separation of concerns

## Sharing with Team

### Option 1: Git Repository

```bash
# Team members clone the repo
git clone <repo-url> ~/claude-automation

# Skills are already in .claude/skills/
# Ready to use!
```

### Option 2: Archive

```bash
# Create archive
tar -czf claude-automation.tar.gz claude-automation/

# Team extracts and uses
tar -xzf claude-automation.tar.gz
cd claude-automation
claude
```

## Troubleshooting

### Skill Not Found

Make sure you're in the project directory:
```bash
pwd
# Should show: /Users/lironkuchlani/claude-automation

# Then start Claude
claude
```

### Skills Not Loading

Check skill directory:
```bash
ls -la .claude/skills/tempest-coverage/
# Should show skill.md and other files
```

### Wrong Memory/Settings

Verify you're in the right directory:
```bash
# Global settings
cat ~/.claude/settings.json

# Project settings (overrides global)
cat .claude/settings.json
```

## Next Steps

1. **Configure the skill:**
   ```bash
   vi .claude/skills/tempest-coverage/config.json
   ```

2. **Test it:**
   ```bash
   claude
   /tempest-coverage <your-test-request>
   ```

3. **Set up git (optional):**
   ```bash
   git init
   git add .claude/
   git commit -m "Add Tempest Coverage skill"
   ```

4. **Share with team (optional):**
   ```bash
   git remote add origin <your-repo>
   git push -u origin main
   ```

---

**Happy Automating! 🚀**
