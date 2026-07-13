# OpenStack Tempest Coverage Automation

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![OpenStack](https://img.shields.io/badge/OpenStack-Tempest-red.svg)](https://docs.openstack.org/tempest/latest/)
[![Claude Code](https://img.shields.io/badge/Claude-Code-purple.svg)](https://claude.ai/code)

Automated OpenStack Tempest test coverage analysis and implementation using Claude Code. Analyzes Jira tickets, discovers existing patterns, implements upstream-compliant tests with automatic validation, and monitors stakeholder approval automatically in the background.

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
# After running git review manually:
/orchestrator OSPRH-22613 --submitted <gerrit_url>  # Update Jira with Gerrit link
```

**Automated workflow (batch) — runs every 4 hours via systemd:**
```bash
# On the VM, the systemd timer runs run-pipeline.sh every 4 hours automatically.
# It discovers tickets via JQL, advances each through stages, and posts plans to Jira.
# The only human step is commenting "Approved" on the Jira ticket.

# After tests are verified, a Jira comment is posted with ready-to-run commands:
#   git fetch ssh://git@github.com/lkuchlan/cinder-tempest-plugin tempest-coverage-OSPRH-22613
#   git checkout tempest-coverage-OSPRH-22613
#   git review
# No VM access needed — just run those three commands on your local machine.

# Manual operations (recovery, status, submission):
/orchestrator OSPRH-22613 --status               # Check pipeline state
/orchestrator OSPRH-22613 --submitted <gerrit_url>  # Update Jira after git review
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
- 🕐 **Background Approval Monitoring** - Automatically polls Jira every 4 hours for stakeholder approval, no manual re-triggering needed
- 🔀 **Secure Branch Handoff** - Verified branches pushed to a GitHub fork automatically; engineers receive fetch+`git review` instructions in Jira with no VM access required

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Credential Management](#-credential-management)
- [Agent Architecture](#-agent-architecture)
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
- Skills installed to `~/.claude/skills/` (5 skills)
- Agents installed to `~/.claude/agents/` (code-reviewer, approval-monitor)
- `.env` template created (edit with your credentials)
- Configuration ready to use
- Works immediately, even without Jira MCP

---

## 🏗️ Architecture

The system is built from **5 skills** (user-invocable slash commands) and **2 agents** (specialized background workers), connected through a shared state file.

```
systemd timer (every 4h)           USER (manual operations)
         │                                  │
         ▼                                  │
  run-pipeline.sh                  /jira-coverage-analysis
  (bash stage router)              /post-test-plan
         │                         /implement-tempest-tests
         ├─ calls per stage:       /verify-tempest-devstack
         │   /jira-coverage-analysis         /orchestrator --status
         │   /post-test-plan                 /orchestrator --submitted
         │   /orchestrator (approval check)
         │   /implement-tempest-tests
         │
         │  post-test-plan schedules ──────► CronCreate (4h)
         │                                        │ fires
         │                                        ▼
         │                               approval-monitor AGENT
         │  orchestrator spawns ───────► polls Jira → APPROVED/REJECTED
         │
         │  implement-tempest-tests spawns ─► code-reviewer AGENT
         │                                     7 Tempest rule checks
         ▼
  Shared State: pipeline-state.json
  Shared Config: config.json
```

> See [`docs/architecture.svg`](docs/architecture.svg) and [`docs/pipeline-flow.svg`](docs/pipeline-flow.svg) for full visual diagrams.

### Five Skills

**1. `/jira-coverage-analysis`** - Analysis Only (Fast)
- **Purpose:** Identify test coverage gaps
- **Speed:** < 5 minutes
- **Output:** Structured analysis report with priorities
- **Use for:** Sprint planning, effort estimation, gap audits

**2. `/post-test-plan`** - Stakeholder Approval
- **Purpose:** Post test plan to Jira for review before implementing
- **Speed:** < 1 minute
- **Output:** Jira comment with duplicate detection + automatic approval monitoring scheduled
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

**5. `/orchestrator`** - Approval Monitoring & Manual Recovery
- **Purpose:** Check approval status on AWAITING_APPROVAL tickets; manual stage recovery
- **Speed:** Seconds (read-only Jira comment check)
- **Output:** Approval decision + updated pipeline state
- **Use for:** `--status` checks, `--retry`, `--reset-to STAGE`, `--submitted` after git review
- **Note:** In automated runs, `run-pipeline.sh` drives the pipeline and calls this skill only for approval checking

### Two Agents

**`code-reviewer`** - Static Validation (Internal)
- **Purpose:** Validate implemented tests against Tempest standards before DevStack
- **Speed:** ~10 seconds
- **Invoked by:** Orchestrator automatically after implementation
- **Checks:** 7 rules — base class, clients, waiters, cleanup, decorators, independence, naming

**`approval-monitor`** - Background Approval Polling (Scheduled)
- **Purpose:** Poll Jira for approval/rejection/discussion comments on posted test plans
- **Speed:** Runs every 4 hours automatically via durable cron
- **Invoked by:** Scheduled automatically when `post-test-plan` posts a plan
- **Updates:** Pipeline state file with APPROVED / REJECTED / TIMED_OUT / NEEDS_DISCUSSION decisions

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
2. Creates symlinks to `~/.claude/skills/` (5 skills)
3. Creates symlinks to `~/.claude/agents/` (2 agents: code-reviewer, approval-monitor)
4. Copies `.env.example` to `.env`
5. Prompts for repository paths
6. Validates installation
7. Prints next steps

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

# Create skills and agents directories
mkdir -p ~/.claude/skills ~/.claude/agents

# Create symlinks (all 5 skills)
ln -sf "$(pwd)/skills/jira-coverage-analysis" ~/.claude/skills/jira-coverage-analysis
ln -sf "$(pwd)/skills/implement-tempest-tests" ~/.claude/skills/implement-tempest-tests
ln -sf "$(pwd)/skills/post-test-plan" ~/.claude/skills/post-test-plan
ln -sf "$(pwd)/skills/orchestrator" ~/.claude/skills/orchestrator
ln -sf "$(pwd)/skills/verify-tempest-devstack" ~/.claude/skills/verify-tempest-devstack
ln -sf "$(pwd)/skills/shared" ~/.claude/skills/tempest-coverage

# Create symlinks (2 agents)
ln -sf "$(pwd)/agents/code-reviewer/prompt.md" ~/.claude/agents/code-reviewer.md
ln -sf "$(pwd)/agents/code-reviewer/rules.json" ~/.claude/agents/code-reviewer-rules.json
ln -sf "$(pwd)/agents/approval-monitor/prompt.md" ~/.claude/agents/approval-monitor.md

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

# Step 3: Submit to Gerrit
# The pipeline pushes the branch to a GitHub fork and posts the exact commands to Jira.
# Check the Jira ticket for the comment, or run on your local machine:
git fetch ssh://git@github.com/lkuchlan/cinder-tempest-plugin tempest-coverage-OSPRH-22613
git checkout tempest-coverage-OSPRH-22613
git review

# Step 4: Mark as submitted in Jira (after git review)
> /orchestrator OSPRH-22613 --submitted <gerrit_url>
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

## 🤖 Agent Architecture

The system uses two types of components: **skills** (user-invocable slash commands) and **agents** (specialized workers with scoped responsibilities).

### Skills (User-Facing)

Skills are invoked directly by users with `/skill-name`. They run in the main conversation context and produce human-readable markdown output by default.

| Skill | User invocation | Automated invocation (run-pipeline.sh) |
|---|---|---|
| `jira-coverage-analysis` | `/jira-coverage-analysis TICKET` → markdown | `claude -p /jira-coverage-analysis TICKET` |
| `post-test-plan` | `/post-test-plan TICKET` → markdown | `claude -p /post-test-plan TICKET` |
| `implement-tempest-tests` | `/implement-tempest-tests TICKET` → markdown | `claude -p /implement-tempest-tests TICKET` |
| `verify-tempest-devstack` | `/verify-tempest-devstack TICKET` → markdown | `claude -p /verify-tempest-devstack TICKET` |
| `orchestrator` | `/orchestrator TICKET --status` → summary | `claude -p /orchestrator TICKET` (approval check only) |

### Agents (Specialized Workers)

Agents run with isolated context and scoped tool access. They are never invoked directly by users.

**`code-reviewer`** (tools: Bash, Read)
- Invoked by the orchestrator after implementation
- Validates test code against 7 Tempest standard rules
- Returns structured JSON — never modifies code

**`approval-monitor`** (tools: Bash, Read, MCP)
- Invoked by a durable 4-hour cron job created by `post-test-plan`
- Polls Jira for approval/rejection comments on pending test plans
- Updates the pipeline state file — never touches code or test files
- Runs automatically in the background without user intervention

### Explore Agent (Pattern Discovery)

Both `jira-coverage-analysis` and `implement-tempest-tests` spawn an **Explore agent** for codebase search:

- **jira-coverage-analysis Step 3:** Search both main Tempest and service plugin repos for existing tests
- **implement-tempest-tests Step 3:** Find base classes, clients, waiters, and template tests

The Explore agent is thorough and handles large repositories (100+ files) efficiently, freeing the main agent's token budget for analysis and implementation. It adds 30-60 seconds but significantly improves pattern matching quality.

---


## 📚 Documentation

### Quick References

- **[QUICKSTART.md](docs/QUICKSTART.md)** - 5-minute guide to first test
- **[INSTALLATION.md](docs/INSTALLATION.md)** - Comprehensive installation guide
- **[JIRA_SETUP.md](docs/JIRA_SETUP.md)** - MCP server configuration
- **[EXAMPLES.md](docs/EXAMPLES.md)** - Real-world workflow examples
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System design overview
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Diagrams

- **[architecture.svg](docs/architecture.svg)** - System architecture (skills, agents, shared state)
- **[pipeline-flow.svg](docs/pipeline-flow.svg)** - Full pipeline state machine with all transitions

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
