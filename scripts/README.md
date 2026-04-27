# Scripts Directory

Automation scripts for the Tempest coverage workflow.

## Directory Structure

```
scripts/
├── setup/              # Setup and configuration scripts
│   ├── initial-setup.sh        # Complete initial setup
│   ├── configure-repos.sh      # Configure repository paths
│   └── test-skills.sh          # Test both skills
│
├── jira/               # Jira-related scripts
│   ├── fetch_jira.py           # Fetch Jira ticket data
│   ├── fetch_epic_children.py  # Fetch epic children
│   └── setup-mcp.sh            # Set up Jira MCP server
│
├── tempest/            # Tempest-related scripts
│   └── find-repos.sh           # Find Tempest repositories
│
└── utils/              # Utility scripts (future)
```

---

## Quick Start

### Initial Setup (First Time)

Run the complete setup process:

```bash
cd /Users/lironkuchlani/claude-automation
bash scripts/setup/initial-setup.sh
```

This will:
- ✅ Verify Claude Code is installed
- ✅ Check directory structure
- ✅ Validate configuration
- ✅ Find Tempest repositories
- ✅ Check dependencies
- ✅ Provide next steps

---

## Setup Scripts

### 1. Initial Setup

**Script:** `scripts/setup/initial-setup.sh`

**Purpose:** Complete first-time setup and verification

**Usage:**
```bash
bash scripts/setup/initial-setup.sh
```

**What it does:**
- Checks Claude Code installation
- Verifies skill directories exist
- Validates configuration file
- Finds Tempest repositories
- Checks dependencies (tox, git, jq)
- Provides setup summary

---

### 2. Configure Repository Paths

**Script:** `scripts/setup/configure-repos.sh`

**Purpose:** Interactive repository path configuration

**Usage:**
```bash
bash scripts/setup/configure-repos.sh
```

**What it does:**
- Searches for Tempest repositories automatically
- Prompts for manual paths
- Updates config.json
- Creates backup
- Validates configuration

**Requirements:**
- `jq` installed (for JSON manipulation)

---

### 3. Test Skills

**Script:** `scripts/setup/test-skills.sh`

**Purpose:** Guide for testing both skills

**Usage:**
```bash
bash scripts/setup/test-skills.sh
```

**What it does:**
- Provides step-by-step testing instructions
- Shows expected output for each skill
- Includes validation checklist
- Offers troubleshooting tips

---

## Jira Scripts

### 1. Fetch Jira Data

**Script:** `scripts/jira/fetch_jira.py`

**Purpose:** Python script to fetch Jira ticket data

**Usage:**
```bash
python scripts/jira/fetch_jira.py <ticket-id>
```

**Requirements:**
- Python 3
- Jira credentials configured

---

### 2. Fetch Epic Children

**Script:** `scripts/jira/fetch_epic_children.py`

**Purpose:** Fetch all child tickets of a Jira epic

**Usage:**
```bash
python scripts/jira/fetch_epic_children.py <epic-id>
```

---

### 3. Setup Jira MCP

**Script:** `scripts/jira/setup-mcp.sh`

**Purpose:** Interactive Jira MCP server setup

**Usage:**
```bash
bash scripts/jira/setup-mcp.sh
```

**What it does:**
- Checks npx/npm availability
- Gathers Jira credentials interactively
- Offers secure credential storage (.env)
- Updates .claude/settings.json
- Tests connection (optional)
- Provides next steps

**Security:**
- Recommends .env file (git-ignored)
- Sets secure permissions (600)
- Uses environment variable references

---

## Tempest Scripts

### 1. Find Repositories

**Script:** `scripts/tempest/find-repos.sh`

**Purpose:** Search for Tempest repositories

**Usage:**
```bash
bash scripts/tempest/find-repos.sh
```

**What it does:**
- Searches common locations for Tempest repos
- Identifies tempest core
- Identifies service plugins
- Provides summary
- Suggests configuration steps

**Search paths:**
- `~/automation_projects`
- `~/PycharmProjects`
- `~/repos`
- `~/work`
- `~/projects`
- `~/src`

---

## Workflow Examples

### Complete First-Time Setup

```bash
# 1. Initial setup
bash scripts/setup/initial-setup.sh

# 2. Configure repository paths
bash scripts/setup/configure-repos.sh

# 3. (Optional) Set up Jira MCP
bash scripts/jira/setup-mcp.sh

# 4. Test the skills
bash scripts/setup/test-skills.sh

# 5. Start using
cd /Users/lironkuchlani/claude-automation
claude
/jira-coverage-analysis <ticket>
```

### Quick Repository Configuration

```bash
# Find repositories
bash scripts/tempest/find-repos.sh

# Configure paths
bash scripts/setup/configure-repos.sh
```

### Jira MCP Setup

```bash
# Set up Jira integration
bash scripts/jira/setup-mcp.sh

# Restart Claude Code
# Test with:
# /jira-coverage-analysis RHEL-12345
```

---

## Requirements

### Required
- **Claude Code** - Main application
- **bash** - For running shell scripts
- **git** - For git operations

### Recommended
- **jq** - For JSON processing
  ```bash
  # macOS
  brew install jq
  
  # Linux
  apt-get install jq
  ```

- **tox** - For test validation
  ```bash
  pip install tox
  ```

### Optional
- **Node.js/npm** - For Jira MCP server
- **Python 3** - For Jira Python scripts

---

## Script Permissions

All scripts should be executable. If not:

```bash
# Make all scripts executable
chmod +x scripts/setup/*.sh
chmod +x scripts/jira/*.sh
chmod +x scripts/tempest/*.sh
```

---

## Troubleshooting

### Script not found
```bash
# Ensure you're in the project root
cd /Users/lironkuchlani/claude-automation

# Run scripts with full path
bash scripts/setup/initial-setup.sh
```

### Permission denied
```bash
# Make script executable
chmod +x scripts/setup/initial-setup.sh

# Then run
bash scripts/setup/initial-setup.sh
```

### jq not installed
```bash
# macOS
brew install jq

# Linux (Debian/Ubuntu)
sudo apt-get install jq

# Linux (RHEL/CentOS)
sudo yum install jq
```

### Configuration not updating
```bash
# Check config file exists
ls -la .claude/skills/tempest-coverage/config.json

# Validate JSON
jq empty .claude/skills/tempest-coverage/config.json

# Check permissions
ls -la .claude/skills/tempest-coverage/
```

---

## Adding New Scripts

To add a new script:

1. **Choose the right directory:**
   - `setup/` - Setup and configuration
   - `jira/` - Jira-related
   - `tempest/` - Tempest-related
   - `utils/` - General utilities

2. **Create the script:**
   ```bash
   vi scripts/setup/my-script.sh
   ```

3. **Add shebang:**
   ```bash
   #!/bin/bash
   ```

4. **Make executable:**
   ```bash
   chmod +x scripts/setup/my-script.sh
   ```

5. **Document it** in this README

---

## Future Scripts (Planned)

### Utility Scripts
- `validate-config.sh` - Validate all configuration files
- `cleanup.sh` - Clean up temporary files
- `backup-config.sh` - Backup configuration
- `restore-config.sh` - Restore from backup

### Analysis Scripts
- `batch-analyze.sh` - Batch analyze multiple tickets
- `generate-report.sh` - Generate coverage report

### Implementation Scripts
- `batch-implement.sh` - Batch implement multiple tickets

---

## Support

### Documentation
- **Main README:** `../README.md`
- **Architecture:** `../TWO_SKILL_ARCHITECTURE.md`
- **Skills Overview:** `../SKILLS_OVERVIEW.md`

### Skill Documentation
- **Analysis skill:** `../.claude/skills/jira-coverage-analysis/README.md`
- **Implementation skill:** `../.claude/skills/implement-tempest-tests/README.md`

### Getting Help
- Run `bash scripts/setup/test-skills.sh` for testing guidance
- Check `.claude/skills/tempest-coverage/JIRA_MCP_SETUP.md` for Jira setup

---

**Automation scripts for efficient Tempest coverage workflow! 🚀**
