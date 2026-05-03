# OpenStack Tempest Coverage Automation

This repository provides Claude Code skills for automating OpenStack Tempest test coverage analysis and implementation following upstream standards.

## Purpose

When working in this repository, you are helping users:
1. Analyze Jira tickets for test coverage gaps
2. Post test plans to Jira for stakeholder approval
3. Implement Tempest tests following OpenStack standards
4. Validate tests meet upstream quality requirements
5. Maintain consistency with Tempest HACKING guidelines

**Target users:** OpenStack QE engineers automating test coverage for Tempest plugins (Cinder, Manila, Glance, etc.)

---

## Project Structure

```
openstack-tempest-coverage-automation/
├── skills/
│   ├── jira-coverage-analysis/     # Analysis-only skill (fast, read-only)
│   ├── post-test-plan/             # Post test plans to Jira (with fallback)
│   ├── implement-tempest-tests/    # Implementation skill (with validation)
│   └── shared/                     # Shared configuration and templates
├── docs/                           # User guides
├── references/                     # Reference documentation
├── examples/                       # Configuration templates
└── scripts/                        # Setup and utility scripts
```

---

## Skills Available

### /jira-coverage-analysis

**Purpose:** Analyze Jira tickets for test coverage gaps (NO implementation)

**When to use:** Sprint planning, effort estimation, identifying gaps before implementation, batch analysis

**Workflow:**
1. Fetch Jira ticket (or accept manual requirements)
2. **Validate ticket** (status and automation relevance)
3. Locate Tempest repositories
4. Discover existing test coverage (Explore agent)
5. Identify gaps with priority (HIGH/MEDIUM/LOW)
6. Estimate effort (hours per gap)
7. Provide implementation recommendations
8. Generate structured markdown report

**Validation:**
- Rejects closed/completed tickets (Closed, Done, Resolved, etc.)
- Validates automation relevance (labels, keywords, issue type)
- Override with `--force` flag if needed

→ **Details:** [skills/jira-coverage-analysis/README.md](skills/jira-coverage-analysis/README.md)

---

### /post-test-plan

**Purpose:** Post test automation plan to Jira for stakeholder approval

**When to use:** After coverage analysis, before implementing tests, sharing test plan with team

**Workflow:**
1. Get analysis report (from memory or run analysis)
2. Format as Jira markdown with tables
3. **Check for duplicate plans** (prevents re-posting)
4. Check Jira MCP write permissions
5. Post to Jira OR show formatted plan for manual posting
6. Include approval instructions (comment or emoji reaction)

**Duplicate Prevention:**
- Detects existing test plans in ticket comments
- Asks user: skip, repost, or view existing plan
- Marks updates with [UPDATED] prefix
- Configurable behavior (ask_user, auto_skip, auto_repost)

→ **Details:** [skills/post-test-plan/README.md](skills/post-test-plan/README.md)

---

### /implement-tempest-tests

**Purpose:** Implement Tempest tests from requirements with validation

**When to use:** After coverage analysis and approval, implementing tests from Jira tickets, creating RBAC/negative/scenario tests

**Workflow:**
1. Get requirements (from analysis, Jira, or manual)
2. Locate Tempest plugin repository
3. Discover implementation patterns (Explore agent)
4. Plan if complex (enter plan mode)
5. Implement tests following strict standards
6. Create git branch and commit
7. Run tox validation (pep8 + py3)
8. Generate mandatory final recap

→ **Details:** [skills/implement-tempest-tests/README.md](skills/implement-tempest-tests/README.md)

---

## Critical Tempest Patterns

**IMPORTANT:** When implementing tests, follow these 5 critical rules:

### ✅ Required

1. **Use Tempest base classes** - Inherit from `BaseVolumeTest`, `BaseSharesTest`, etc. NEVER create custom base classes.
2. **Use service clients** - Use `self.volumes_client`, `self.shares_client`. NEVER use raw HTTP (requests/urllib).
3. **Use waiters** - Use `waiters.wait_for_*`. NEVER use `time.sleep()` for polling.
4. **Cleanup resources** - Use helper methods (auto-cleanup) or `addCleanup()`. Check if helpers handle cleanup first.
5. **Test independence** - Each test creates its own resources. No shared state between tests.

### ❌ Forbidden

- ❌ `time.sleep()` for polling
- ❌ `requests`/`urllib` for API calls
- ❌ Resources without cleanup
- ❌ Shared state between tests
- ❌ Custom base classes

→ **Complete reference:** [references/TEMPEST_STANDARDS.md](references/TEMPEST_STANDARDS.md)

---

## Git Workflow

Skills follow these rules for git operations:

**Branch Management:**
- Create feature branch: `tempest-coverage-{ticket-id}`
- NEVER modify `main` or `master` directly
- NEVER auto-push to remote (user controls when to push)

**Commit Format:**
```
Add Tempest coverage for {feature}

Tests added:
- test_name_1
- test_name_2

Implements: {TICKET-ID}

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Validation:**
- `tox -e pep8` - PEP 8 style and import checking
- `tox -e py3` - Unit test validation
- Runs automatically before commit

---

## Development Environment

Users typically have:

**Local repositories:**
- Tempest: `~/tempest-workspace/tempest` (or custom path)
- Plugins: `~/tempest-workspace/{service}-tempest-plugin`
  - Examples: `cinder-tempest-plugin`, `manila-tempest-plugin`, `glance-tempest-plugin`

**Tools installed:**
- Python 3.8+ with tox
- Git configured for Gerrit review (if contributing upstream)
- Optional: Jira MCP server for ticket fetching

**Validation commands:**
- `tox -e pep8` - PEP 8 style checking
- `tox -e py3` - Unit tests in Python 3
- `git review` - Submit to Gerrit (upstream)

---

## Subagent Usage Strategy

The analysis and implementation skills use subagents intelligently for specific tasks:

### Explore Agent (Pattern Discovery)

**When used:**
- **jira-coverage-analysis:** STEP 3 - Discover Existing Coverage
- **implement-tempest-tests:** STEP 3 - Discover Implementation Patterns

**Purpose:**
- Deep codebase search for existing tests
- Finding base test classes to inherit from
- Discovering service clients and their methods
- Locating waiter implementations
- Identifying cleanup patterns
- Finding reference tests as templates

**Why delegated:**
- Thorough, methodical code discovery
- Handles large codebases (100+ files) efficiently
- Saves main agent token budget for analysis/implementation
- Better pattern matching across repositories

**Configuration:**
- Mode: "very thorough"
- Searches multiple file types and patterns
- Follows imports and inheritance chains
- Builds comprehensive pattern map

---

## Quick Start

**First time setup:**
```bash
git clone https://github.com/lkuchlan/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation
./scripts/setup.sh
```

**Basic workflow:**
```bash
/jira-coverage-analysis TICKET-123
/post-test-plan TICKET-123
/implement-tempest-tests TICKET-123
```

→ More workflows: [docs/EXAMPLES.md](docs/EXAMPLES.md)

---

## Documentation

**User Guides:**
| Topic | Document |
|-------|----------|
| Installation | [docs/INSTALLATION.md](docs/INSTALLATION.md) |
| Quick Start | [docs/QUICKSTART.md](docs/QUICKSTART.md) |
| Examples & Workflows | [docs/EXAMPLES.md](docs/EXAMPLES.md) |
| Troubleshooting | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Jira Setup | [docs/JIRA_SETUP.md](docs/JIRA_SETUP.md) |
| Architecture | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |

**Reference Documentation:**
| Topic | Document |
|-------|----------|
| **Tempest Standards** | [references/TEMPEST_STANDARDS.md](references/TEMPEST_STANDARDS.md) |
| **Configuration Options** | [references/CONFIGURATION.md](references/CONFIGURATION.md) |

**Contributing:**
| Topic | Document |
|-------|----------|
| Contributing Guide | [CONTRIBUTING.md](CONTRIBUTING.md) |

---

## References

**Upstream Documentation:**
- Tempest HACKING: https://docs.openstack.org/tempest/latest/HACKING.html
- Tempest Plugin Interface: https://docs.openstack.org/tempest/latest/plugin.html
- OpenStack API Reference: https://docs.openstack.org/api-ref/
- Tempest Configuration: https://docs.openstack.org/tempest/latest/configuration.html

**Service-specific API docs:**
- Cinder API: https://docs.openstack.org/api-ref/block-storage/
- Manila API: https://docs.openstack.org/api-ref/shared-file-system/
- Glance API: https://docs.openstack.org/api-ref/image/
- Nova API: https://docs.openstack.org/api-ref/compute/

**Jira MCP:**
- Official MCP Server: https://github.com/modelcontextprotocol/servers
