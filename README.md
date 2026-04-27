# OpenStack Tempest Coverage Automation

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OpenStack](https://img.shields.io/badge/OpenStack-Tempest-red.svg)](https://docs.openstack.org/tempest/latest/)
[![Claude Code](https://img.shields.io/badge/Claude-Code-purple.svg)](https://claude.ai/code)

Automated OpenStack Tempest test coverage analysis and implementation using Claude Code. Analyzes Jira tickets, discovers existing patterns, implements upstream-compliant tests with automatic validation.

---

## 🎯 What This Does

Transform Jira tickets into production-ready Tempest tests **in minutes instead of hours**, while enforcing OpenStack upstream standards automatically.

**Before:** 4-6 hours to analyze coverage gaps, find patterns, implement tests, and validate  
**After:** 5-10 minutes with automated analysis, pattern discovery, and quality enforcement

**Example workflow:**
```bash
# Step 1: Analyze ticket for coverage gaps (2 minutes)
/jira-coverage-analysis OSPRH-22613

# Review analysis report with priorities and effort estimates

# Step 2: Implement approved tests (5 minutes)
/implement-tempest-tests OSPRH-22613

# Tests generated, validated with tox, committed to branch
```

---

## ✨ Key Features

- 🔍 **Automated Jira Analysis** - Fetch tickets via MCP, extract requirements, identify gaps
- 🧠 **Intelligent Pattern Discovery** - Explore agent finds base classes, clients, waiters automatically
- 📝 **Upstream-Compliant Generation** - Follows Tempest HACKING guidelines strictly  
- ✅ **Automatic Validation** - Runs `tox -e pep8,py3` before commit
- 🔄 **Git Workflow Automation** - Creates branches, commits with proper messages
- 🛡️ **Pre-commit Quality Enforcement** - Blocks common violations (time.sleep, raw API, no cleanup)
- 🔐 **Optional Jira Integration** - Works with or without Jira MCP
- 📊 **Structured Reports** - Gap analysis with priorities and effort estimates
- 🎓 **RBAC, Negative, Scenario Tests** - Comprehensive coverage types

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Credential Management](#-credential-management)
- [Subagent Strategy](#-subagent-strategy)
- [Pre-commit Hooks](#-pre-commit-hooks)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🚀 Quick Start

**5-minute setup:**

```bash
# 1. Clone repository
git clone https://github.com/your-org/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# 2. Run one-command setup
./scripts/setup.sh

# 3. (Optional) Edit .env with Jira credentials
vi .env

# 4. Test the skills
claude
> /jira-coverage-analysis --help
> /implement-tempest-tests --help

# 5. Analyze a ticket
> /jira-coverage-analysis OSPRH-22613
```

**What happens:**
- Skills installed to `~/.claude/skills/`
- `.env` template created (edit with your credentials)
- Configuration ready to use
- Works immediately, even without Jira MCP

---

## 🏗️ Architecture

```
User Request
    ↓
┌─────────────────────────────────────────────┐
│  /jira-coverage-analysis OSPRH-22613        │
│  • Fetch ticket (Jira MCP or manual)        │
│  • Spawn Explore agent (pattern discovery)  │
│  • Identify gaps with priorities            │
│  • Estimate effort (hours)                  │
│  • Generate structured report               │
└─────────────────────────────────────────────┘
    ↓
User Reviews Analysis Report
    ↓
┌─────────────────────────────────────────────┐
│  /implement-tempest-tests OSPRH-22613       │
│  • Spawn Explore agent (find patterns)      │
│  • Enter plan mode (if complex)             │
│  • Generate tests (strict standards)        │
│  • Create git branch + commit               │
│  • Validate with tox (pep8 + py3)           │
│  • Generate final recap                     │
└─────────────────────────────────────────────┘
    ↓
Tests Ready for Review & Push
```

### Two Specialized Skills

**1. `/jira-coverage-analysis`** - Analysis Only (Fast)
- **Purpose:** Identify test coverage gaps
- **Speed:** < 5 minutes
- **Output:** Structured analysis report with priorities
- **Use for:** Sprint planning, effort estimation, gap audits

**2. `/implement-tempest-tests`** - Implementation + Validation
- **Purpose:** Generate production-ready tests
- **Speed:** 5-10 minutes (with validation)
- **Output:** Validated code + git commit + recap
- **Use for:** Implementing approved tests

### Shared Configuration

- **`skills/shared/config.json`** - Service mappings, base classes, clients, waiters
- **Templates** - API test and scenario test patterns
- **Repository paths** - Default: `~/automation_projects/`

---

## 📦 Installation

### Prerequisites

- **Claude Code** - [Install from claude.ai/code](https://claude.ai/code)
- **Python 3.8+** - For Tempest and hooks
- **tox** - For test validation
- **git** - For version control
- **Optional:** Jira MCP server

### Method 1: Git Clone + Setup Script (Recommended)

```bash
git clone https://github.com/your-org/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation
./scripts/setup.sh
```

**What it does:**
1. Checks Claude Code installed
2. Creates symlinks to `~/.claude/skills/`
3. Copies `.env.example` to `.env`
4. Prompts for repository paths
5. Validates installation
6. Prints next steps

### Method 2: Direct Download (Air-gapped)

```bash
curl -L https://github.com/your-org/openstack-tempest-coverage-automation/archive/refs/tags/v1.0.0.tar.gz | tar xz
cd openstack-tempest-coverage-automation-1.0.0
./scripts/setup.sh
```

### Method 3: Manual Installation

```bash
# Clone repository
git clone https://github.com/your-org/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# Create skills directory
mkdir -p ~/.claude/skills

# Create symlinks
ln -sf "$(pwd)/.claude/skills/jira-coverage-analysis" ~/.claude/skills/jira-coverage-analysis
ln -sf "$(pwd)/.claude/skills/implement-tempest-tests" ~/.claude/skills/implement-tempest-tests
ln -sf "$(pwd)/.claude/skills/tempest-coverage" ~/.claude/skills/tempest-coverage

# Copy credential template
cp examples/.env.example .env

# Edit with your credentials (optional)
vi .env
```

### Verification

```bash
# Test skills are available
claude

# In Claude Code:
> /jira-coverage-analysis --help
> /implement-tempest-tests --help

# Should see skill descriptions
```

---

## ⚙️ Configuration

### Essential Configuration

**1. Repository Paths (if not using defaults)**

Edit `~/.claude/skills/tempest-coverage/config.json`:

```json
{
  "repository_paths": {
    "tempest": ["~/automation_projects/tempest", "~/PycharmProjects/tempest"],
    "plugins": {
      "cinder": "~/automation_projects/cinder-tempest-plugin",
      "manila": "~/automation_projects/manila-tempest-plugin",
      "glance": "~/automation_projects/glance-tempest-plugin"
    }
  }
}
```

**2. Jira Credentials (if using Jira MCP)**

Edit `.env` in repository root:

```bash
JIRA_URL=https://issues.redhat.com
JIRA_USERNAME=your.email@company.com
JIRA_API_TOKEN=your-api-token-here
```

**Generate Jira API token:**
- Jira Cloud: https://id.atlassian.com/manage-profile/security/api-tokens
- Jira Data Center: User Settings → Personal Access Tokens

**3. MCP Server (if using Jira integration)**

Add to `.claude/settings.json`:

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
  },
  "enableAllProjectMcpServers": true
}
```

See `examples/settings.json.example` for complete configuration.

---

## 📖 Usage

### Workflow 1: Analyze → Implement from Jira

```bash
claude

# Step 1: Analyze ticket
> /jira-coverage-analysis OSPRH-22613

# Output: Structured analysis report with:
# - Existing coverage found
# - Gaps identified (HIGH/MEDIUM/LOW priority)
# - Effort estimates (X-Y hours per gap)
# - Implementation recommendations

# Review report, approve implementation

# Step 2: Implement tests
> /implement-tempest-tests OSPRH-22613

# Output: Tests generated, validated, committed
# Branch: tempest-coverage-OSPRH-22613
# Commit: "Add Tempest coverage for <feature>"

# Step 3: Review and push
cd ~/automation_projects/cinder-tempest-plugin
git log -1  # Review commit
git diff HEAD~1  # Review changes
tox -e pep8,py3  # Additional validation
git push origin tempest-coverage-OSPRH-22613
git review  # If using Gerrit
```

### Workflow 2: Batch Analysis for Sprint Planning

```bash
# Analyze multiple tickets at once
> /jira-coverage-analysis OSPRH-22613 OSPRH-22614 OSPRH-22615

# Output: Individual analysis + combined summary
# - Total gaps: 12
# - Total estimated effort: 24-32 hours
# - Priority distribution: 5 HIGH, 4 MEDIUM, 3 LOW

# Plan sprint based on estimates
# Implement in priority order
```

### Workflow 3: Without Jira MCP (Manual Requirements)

```bash
# Skills work without Jira integration
> /implement-tempest-tests

# Claude will prompt for:
# - Service name (e.g., Cinder)
# - Feature/API description
# - Test scenarios needed
# - Acceptance criteria

# Provide requirements, get same quality tests
```

### Workflow 4: Analysis Only (No Implementation)

```bash
# Just analyze, don't implement yet
> /jira-coverage-analysis RHEL-12345

# Use report for:
# - Sprint planning discussions
# - Effort estimation
# - Prioritization decisions
# - Documentation

# Implement later when approved
```

---

## 🔐 Credential Management

### Security First

**⚠️ NEVER commit credentials to git**

The repository has multiple security layers:

1. **`.gitignore`** - Blocks `.env`, `.env.local`, `*.secret`, `*.token`, `*.local.json`
2. **`.env.example`** - Template with placeholders only
3. **Documentation** - Clear security guidelines
4. **Pre-commit checks** - (Future) Detect credential patterns

### Setup Steps

**1. Copy template:**
```bash
cp examples/.env.example .env
```

**2. Edit with your credentials:**
```bash
# Generate Jira API token first:
# https://id.atlassian.com/manage-profile/security/api-tokens

vi .env
```

**3. Secure the file:**
```bash
chmod 600 .env
```

**4. Verify it's git-ignored:**
```bash
git status
# .env should NOT appear in untracked files
```

### Alternative: System Environment Variables

Instead of `.env`, set system-wide:

```bash
# Add to ~/.zshrc or ~/.bashrc
export JIRA_URL="https://your-jira.com"
export JIRA_USERNAME="your-email@company.com"
export JIRA_API_TOKEN="your-token"

source ~/.zshrc
```

### Fallback: Works Without Jira MCP

If you can't or don't want to set up Jira MCP:
- ✅ Skills still work perfectly
- ✅ You provide ticket details manually when prompted
- ✅ Same quality test implementation
- ✅ No automatic ticket fetching

---

## 🤖 Subagent Strategy

These skills use Claude's **Explore agent** intelligently for pattern discovery.

### What Gets Delegated to Explore Agent

**Code Discovery Tasks:**
- Finding existing test patterns in large codebases
- Locating base classes and their inheritance hierarchies
- Discovering service clients and their methods
- Finding waiter implementations
- Identifying cleanup patterns
- Searching for similar tests as templates

**Why Delegated:**
- Thorough, methodical codebase search
- Handles large repositories (100+ files) efficiently
- Frees main agent token budget for analysis/implementation
- Better pattern matching across multiple repositories

### When Explore Agent is Used

**jira-coverage-analysis:**
- **Step 3:** Discover Existing Coverage
- **Mode:** Very thorough
- **Searches:** Existing tests, base classes, patterns

**implement-tempest-tests:**
- **Step 3:** Discover Implementation Patterns
- **Mode:** Very thorough
- **Searches:** Base classes, clients, waiters, templates

### When Explore Agent is Skipped

- Patterns already in memory from recent analysis
- User provides specific file paths
- Quick re-analysis of same ticket
- Repository structure well-known

### Performance Impact

**With Explore Agent:**
- Slightly longer (extra 30-60 seconds)
- More thorough pattern discovery
- Higher quality pattern matching
- Better test implementation

**Without (when skipped):**
- Faster execution
- Uses cached patterns from memory
- Same quality if patterns already known

---

## 🛡️ Pre-commit Hooks for Tempest Standards

Enforce OpenStack Tempest coding standards automatically before each commit.

### What Gets Checked

✅ **Proper Tempest client usage** - No raw `requests/urllib`  
✅ **Base class inheritance** - Tempest base classes only  
✅ **Waiter usage** - No `time.sleep()` for polling  
✅ **Resource cleanup** - `addCleanup()` for all resources  
✅ **Required decorators** - `@decorators.idempotent_id()` present  

### Installation

**In your Tempest plugin repository:**

```bash
cd ~/automation_projects/cinder-tempest-plugin

# Install hooks
/path/to/openstack-tempest-coverage-automation/hooks/install-hooks.sh
```

### Usage

Hooks run automatically on `git commit`:

```bash
git add cinder_tempest_plugin/api/volume/test_myfeature.py
git commit -m "Add test coverage for feature X"

🔍 Checking OpenStack Tempest test standards...
[1/1] Checking: cinder_tempest_plugin/api/volume/test_myfeature.py

✅ All Tempest standards checks passed!
```

### If Violations Found

```bash
❌ Tempest standards violations found!

❌ Waiter violations in test_myfeature.py:
   Line 45: Using time.sleep() - Use Tempest waiters instead

   💡 Fix: Use Tempest waiters instead of sleep/polling
   Examples:
     waiters.wait_for_volume_resource_status(client, vol_id, 'available')

Reference: https://docs.openstack.org/tempest/latest/HACKING.html
```

**Fix the issues and commit again**, or bypass (not recommended):
```bash
git commit --no-verify  # Skip hooks (NOT RECOMMENDED)
```

### Uninstall

```bash
rm .git/hooks/pre-commit
rm -rf .git/hooks/checks/
```

---

## 📚 Documentation

### Quick References

- **[QUICKSTART.md](docs/QUICKSTART.md)** - 5-minute guide to first test
- **[INSTALLATION.md](docs/INSTALLATION.md)** - Comprehensive installation guide
- **[JIRA_SETUP.md](docs/JIRA_SETUP.md)** - MCP server configuration
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Real-world workflow examples
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design overview
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Project Documentation

- **[CLAUDE.md](CLAUDE.md)** - OpenStack Tempest standards (for Claude Code)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[LICENSE](LICENSE)** - Apache 2.0 license

### Upstream References

- [Tempest HACKING Guide](https://docs.openstack.org/tempest/latest/HACKING.html)
- [Tempest Plugin Interface](https://docs.openstack.org/tempest/latest/plugin.html)
- [OpenStack API Reference](https://docs.openstack.org/api-ref/)
- [Cinder API](https://docs.openstack.org/api-ref/block-storage/)
- [Manila API](https://docs.openstack.org/api-ref/shared-file-system/)

---

## 🤝 Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Ways to contribute:**
- Report bugs or issues
- Suggest new features
- Improve documentation
- Add test templates
- Enhance pattern detection
- Support additional OpenStack services

**Development setup:**
```bash
git clone https://github.com/your-org/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# Test on real Tempest repositories
./scripts/setup.sh

# Make changes to skills/ or hooks/

# Test changes
claude
> /jira-coverage-analysis TEST-123
```

---

## 📄 License

Apache License 2.0 - See [LICENSE](LICENSE) for details.

OpenStack standard license for compatibility with upstream Tempest.

---

## 🙏 Acknowledgments

- **OpenStack Tempest Team** - For the excellent testing framework
- **Model Context Protocol** - For Jira integration capabilities
- **Claude Code** - For the agent platform
- **Red Hat OpenStack QE** - For real-world testing and feedback

---

## 📬 Support

**Issues:** [GitHub Issues](https://github.com/your-org/openstack-tempest-coverage-automation/issues)  
**Discussions:** [GitHub Discussions](https://github.com/your-org/openstack-tempest-coverage-automation/discussions)  
**Documentation:** [docs/](docs/)  

---

**Made with ❤️ for the OpenStack QE Community**
