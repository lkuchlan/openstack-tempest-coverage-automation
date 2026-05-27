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
│   ├── orchestrator/               # Pipeline orchestrator (ties all skills together)
│   ├── jira-coverage-analysis/     # Analysis-only skill (fast, read-only)
│   ├── post-test-plan/             # Post test plans to Jira (with fallback)
│   ├── implement-tempest-tests/    # Implementation skill (with validation)
│   ├── verify-tempest-devstack/   # DevStack verification skill (SSH + real tests)
│   └── shared/                     # Shared configuration and templates
├── docs/                           # User guides
├── references/                     # Reference documentation
├── examples/                       # Configuration templates
└── scripts/                        # Setup and utility scripts
```

---

## Skills Available

### /tempest-coverage-orchestrator

Pipeline orchestrator that ties all skills into an automated workflow. Manages tickets through stages: Discovery → Analysis → Post Plan → Approval Monitoring.

**Use for:** End-to-end pipeline execution • Batch ticket processing • Approval monitoring • Pipeline status checks

**Key features:** File-based state management • Idempotent stages (safe to re-run) • Crash recovery • Dry-run mode • JQL-based ticket discovery

**State:** `~/.claude/orchestrator-state/pipeline-state.json`

**Usage:**
```bash
/tempest-coverage-orchestrator TICKET-ID            # Process single ticket
/tempest-coverage-orchestrator --jql "..."           # Discover via JQL
/tempest-coverage-orchestrator --status              # Show all tracked tickets
/tempest-coverage-orchestrator --dry-run --jql "..."  # Preview without acting
/tempest-coverage-orchestrator TICKET-ID --submitted <gerrit_url>  # Mark as submitted after git review
```

**Pipeline terminal stages:** SUBMITTED (after `--submitted`), REJECTED, TIMED_OUT, CODE_REVIEW_FAILED, VERIFICATION_FAILED

**discussion_flagged:** When the approval-monitor detects a neutral stakeholder comment (neither approval nor rejection), the ticket stays at AWAITING_APPROVAL and is flagged as NEEDS DISCUSSION. Re-running `/post-test-plan` after addressing feedback uses the revised template automatically.

### /jira-coverage-analysis

Analyze Jira tickets for test coverage gaps (NO implementation). Fast, read-only analysis for sprint planning and effort estimation.

**Use for:** Sprint planning • Effort estimation • Gap identification • Batch analysis

**Key features:** Validates tickets (status + automation relevance) • Discovers existing coverage • Identifies gaps with priority • Estimates effort

→ [Full documentation](skills/jira-coverage-analysis/README.md)

### /post-test-plan

Post test automation plan to Jira for stakeholder approval. Prevents duplicate posts, works in read-only mode.

**Use for:** Stakeholder approval • Plan sharing • Team collaboration

**Key features:** Duplicate detection • Formatted Jira markdown • Manual fallback if write disabled

→ [Full documentation](skills/post-test-plan/README.md)

### /implement-tempest-tests

Implement Tempest tests from requirements with automatic validation. Creates branch, commits, runs tox.

**Use for:** Post-approval implementation • RBAC/negative/scenario tests • Jira ticket implementation

**Key features:** Pattern discovery • Strict standards enforcement • Tox validation • Git workflow automation • Prefers existing test files and classes over creating new ones

→ [Full documentation](skills/implement-tempest-tests/README.md)

### /verify-tempest-devstack

Verify Tempest tests against a real DevStack deployment. Deploys DevStack from scratch on a VM, installs tests, runs them against real OpenStack APIs, and reports results.

**Use for:** Post-implementation verification • Real OpenStack API testing • Integration validation

**Key features:** SSH-based remote execution • Automated DevStack deployment • Structured failure feedback for retry loops • Coverage measurement

**Configuration:** `skills/verify-tempest-devstack/config.json` (SSH + DevStack settings)

→ [Full documentation](skills/verify-tempest-devstack/README.md)

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

**Repositories:** Tempest plugins in `~/tempest-workspace/{service}-tempest-plugin` (configurable)

**Tools:** Python 3.8+ with tox • Git (Gerrit for upstream) • Optional: Jira MCP

**Validation:** `tox -e pep8,py3` (automatic before commit)

---

## Quick Start

```bash
/jira-coverage-analysis TICKET-123
/post-test-plan TICKET-123
/implement-tempest-tests TICKET-123
/verify-tempest-devstack TICKET-123
```

→ Setup: [docs/INSTALLATION.md](docs/INSTALLATION.md) • Workflows: [docs/EXAMPLES.md](docs/EXAMPLES.md)

---

## Documentation

**Guides:** [Installation](docs/INSTALLATION.md) • [Quick Start](docs/QUICKSTART.md) • [Examples](docs/EXAMPLES.md) • [Troubleshooting](docs/TROUBLESHOOTING.md) • [Jira Setup](docs/JIRA_SETUP.md)

**Reference:** [Tempest Standards](references/TEMPEST_STANDARDS.md) • [Configuration](references/CONFIGURATION.md)

**Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md)
