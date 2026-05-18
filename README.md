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

**Manual workflow (per ticket):**
```bash
/jira-coverage-analysis OSPRH-22613   # Analyze gaps
/post-test-plan OSPRH-22613           # Post plan for approval
/implement-tempest-tests OSPRH-22613  # Implement after approval
/verify-tempest-devstack OSPRH-22613  # Verify on real OpenStack
```

**Automated workflow (batch):**
```bash
/orchestrator --jql "project = OSPRH AND component = Cinder AND labels = needs-tempest-coverage"
# Discovers tickets → analyzes → posts plans → monitors approval → implements → verifies
```

---

## ✨ Key Features

- 🔍 **Automated Jira Analysis** - Fetch tickets via MCP, extract requirements, identify gaps
- 🧠 **Intelligent Pattern Discovery** - Explore agent finds base classes, clients, waiters automatically
- 📝 **Upstream-Compliant Generation** - Follows Tempest HACKING guidelines strictly  
- ✅ **Automatic Validation** - Runs `tox -e pep8,py3` before commit
- 🔄 **Git Workflow Automation** - Creates branches, commits with proper messages
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
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🚀 Quick Start

**5-minute setup:**

```bash
# 1. Clone repository
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
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

### Five Skills

**1. `/jira-coverage-analysis`** - Analysis Only (Fast)
- **Purpose:** Identify test coverage gaps
- **Speed:** < 5 minutes
- **Output:** Structured analysis report with priorities
- **Use for:** Sprint planning, effort estimation, gap audits

**2. `/post-test-plan`** - Stakeholder Approval
- **Purpose:** Post test plan to Jira for review before implementing
- **Speed:** < 1 minute
- **Output:** Jira comment with duplicate detection
- **Use for:** Getting stakeholder sign-off before writing tests

**3. `/implement-tempest-tests`** - Implementation + Validation
- **Purpose:** Generate production-ready tests
- **Speed:** 5-10 minutes (with validation)
- **Output:** Validated code + git commit + recap
- **Use for:** Implementing approved tests

**4. `/verify-tempest-devstack`** - Real-world Verification
- **Purpose:** Verify tests on a real DevStack OpenStack environment
- **Speed:** 35-90 minutes (includes DevStack deployment)
- **Output:** Verification report with pass/fail results
- **Use for:** Validating tests against real OpenStack APIs before pushing

**5. `/orchestrator`** - Full Pipeline Automation
- **Purpose:** Automate the entire pipeline end-to-end
- **Speed:** Hours to days (poll-based approval + verification)
- **Output:** State-tracked pipeline with Jira updates
- **Use for:** Batch ticket processing, automated workflow

### Shared Configuration

- **`skills/shared/config.json`** - Service mappings, base classes, clients, waiters
- **Templates** - API test and scenario test patterns
- **Repository paths** - Customizable, default: `~/tempest-workspace/`

---

## 📦 Installation

### Prerequisites

- **Claude Code** - [Install from claude.ai/code](https://claude.ai/code)
- **Python 3.8+** - For Tempest validation
- **tox** - For test validation
- **git** - For version control
- **Optional:** Jira MCP server

### Method 1: Git Clone + Setup Script (Recommended)

```bash
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
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
curl -L https://github.com/lkuchlan/openstack-tempest-coverage-automation/archive/refs/tags/v1.0.0.tar.gz | tar xz
cd openstack-tempest-coverage-automation-1.0.0
./scripts/setup.sh
```

### Method 3: Manual Installation

```bash
# Clone repository
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# Create skills directory
mkdir -p ~/.claude/skills

# Create symlinks (all 5 skills)
ln -sf "$(pwd)/skills/jira-coverage-analysis" ~/.claude/skills/jira-coverage-analysis
ln -sf "$(pwd)/skills/implement-tempest-tests" ~/.claude/skills/implement-tempest-tests
ln -sf "$(pwd)/skills/post-test-plan" ~/.claude/skills/post-test-plan
ln -sf "$(pwd)/skills/orchestrator" ~/.claude/skills/orchestrator
ln -sf "$(pwd)/skills/verify-tempest-devstack" ~/.claude/skills/verify-tempest-devstack
ln -sf "$(pwd)/skills/shared" ~/.claude/skills/tempest-coverage

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
    "tempest": ["~/tempest-workspace/tempest"],
    "plugins": {
      "cinder": "~/tempest-workspace/cinder-tempest-plugin",
      "manila": "~/tempest-workspace/manila-tempest-plugin",
      "glance": "~/tempest-workspace/glance-tempest-plugin"
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

Install `uv`:
```bash
brew install uv    # macOS
pip install uv     # or via pip
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
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
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

**3. Verify it's git-ignored:**
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
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# Test on real Tempest repositories
./scripts/setup.sh

# Make changes to skills/

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

**Issues:** [GitHub Issues](https://github.com/lkuchlan/openstack-tempest-coverage-automation/issues)  
**Discussions:** [GitHub Discussions](https://github.com/lkuchlan/openstack-tempest-coverage-automation/discussions)  
**Documentation:** [docs/](docs/)  

---

**Made with ❤️ for the OpenStack QE Community**
