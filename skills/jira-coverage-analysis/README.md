# Jira Coverage Analysis Skill

Lightweight skill for analyzing Jira tickets and identifying Tempest test coverage gaps.

## Purpose

**Analysis only** - No implementation. Fast, focused coverage auditing.

Use this skill for:
- ✅ Sprint planning (analyze tickets, estimate effort)
- ✅ Coverage audits (identify gaps across projects)
- ✅ Prioritization (which tickets need tests most)
- ✅ Effort estimation (how long will implementation take)
- ✅ Batch analysis (analyze 10 tickets in minutes)

**NOT for implementation** - Use `implement-tempest-tests` for that.

## Features

- **Fast:** Analysis in seconds (no code generation)
- **Batch capable:** Analyze multiple tickets at once
- **MCP integrated:** Auto-fetch from Jira
- **Comprehensive:** Identifies ALL gaps with priority
- **Actionable:** Provides implementation recommendations

## Ticket Validation

Validates tickets before analysis to ensure they're ready for coverage work:

- ✅ **Ticket status** - Rejects closed/completed tickets (Closed, Done, Resolved, Won't Fix, etc.)
- ✅ **Automation relevance** - Validates ticket is automation-related work

**Bypass validation:**
```bash
/jira-coverage-analysis RHEL-12345 --force
```

**What gets validated:**

**Status validation:**
- Checks ticket is not in completed state
- Prevents wasting time on tickets that don't need work
- Customizable invalid statuses in config

**Automation relevance (any match):**
- Labels: automation, test-automation, tempest, qa-automation
- Issue types: Test, Testing, QE Task
- Keywords in summary/description: tempest, test coverage, test automation

**Configuration:**
Edit `skills/shared/config.json` → `jira_integration.ticket_validation` to customize:
- Which statuses are considered invalid
- Which labels/keywords indicate automation work
- Enable/disable validation

## Quick Start

### Analyze Single Ticket

```bash
/jira-coverage-analysis RHEL-12345
```

**Output:**
- Existing coverage found
- Gaps identified with priority
- Effort estimation
- Implementation recommendations

### Analyze Multiple Tickets

```bash
/jira-coverage-analysis RHEL-12345 RHEL-12346 RHEL-12347
```

**Output:**
- Analysis for each ticket
- Combined summary
- Total effort estimate
- Recommended implementation order

### Manual Requirements

```bash
/jira-coverage-analysis

Service: Cinder
Feature: Volume multi-attach RBAC
```

## Output Example

```markdown
# Coverage Analysis Report: RHEL-12345

## Executive Summary
- Service: Cinder
- Feature: Volume multi-attach RBAC
- Coverage Status: ❌ Missing
- Priority: HIGH
- Estimated Effort: 9 hours

## Existing Coverage
- File: test_volumes.py
- Tests: Basic CRUD operations covered
- Gaps: RBAC tests missing

## Coverage Gaps
1. RBAC for admin role (HIGH, 4 hours)
2. RBAC for member role (HIGH, 3 hours)
3. Negative tests (MEDIUM, 2 hours)

## Recommendations
- Implement Gap 1 first (security-critical)
- Use BaseVolumeTest pattern
- Reference: test_volume_attach_rbac.py

## Next Steps
Use: /implement-tempest-tests RHEL-12345
```

## Workflow

```
User provides Jira ticket(s)
         ↓
[Fetch ticket via MCP]
         ↓
[Find existing coverage]
         ↓
[Identify gaps]
         ↓
[Estimate effort]
         ↓
[Generate report]
         ↓
✅ Analysis complete (< 5 min)
```

## Integration with Implementation Skill

### Recommended Workflow

```bash
# Step 1: Analyze
/jira-coverage-analysis RHEL-12345

# Step 2: Review analysis report
# (Check priority, effort, recommendations)

# Step 3: Implement
/implement-tempest-tests RHEL-12345
```

### Why Two Steps?

1. **Analysis is fast** (seconds) - can analyze many tickets
2. **Implementation is slow** (minutes) - one at a time
3. **Sprint planning needs analysis** - not implementation
4. **Review before implementation** - ensure alignment

## Configuration

Shares configuration with `tempest-coverage` and `implement-tempest-tests`:
- **File:** `~/.claude/skills/tempest-coverage/config.json`
- Same Jira MCP setup
- Same repository paths
- Same service mappings

See main tempest-coverage documentation for configuration details.

## Output Guarantees

Every analysis provides:
- ✅ Structured report
- ✅ Gap identification with priority
- ✅ Effort estimation
- ✅ Implementation recommendations
- ✅ Fast execution (< 5 minutes)
- ✅ No code generation
- ✅ No git operations

## Use Cases

### Sprint Planning

```bash
# Analyze all tickets for sprint
/jira-coverage-analysis RHEL-12345 RHEL-12346 RHEL-12347

# Get combined effort estimate
# Prioritize tickets
# Assign to team
```

### Coverage Audit

```bash
# Audit Cinder coverage
/jira-coverage-analysis

Search Jira for all Cinder test coverage tickets and analyze
```

### Effort Estimation

```bash
# Estimate single ticket
/jira-coverage-analysis RHEL-12345

# Output includes: X-Y hours estimate
```

## Performance

- **Single ticket:** 30-60 seconds
- **Batch (5 tickets):** 2-3 minutes
- **Batch (10 tickets):** 4-5 minutes

Much faster than implementation skill!

## See Also

- **implement-tempest-tests** - Implement tests from analysis
- **tempest-coverage** - Original combined skill (deprecated)

## Documentation

- **skill.md** - Complete workflow (skill definition)
- **QUICKSTART.md** - Coming soon
- **Shared config:** See tempest-coverage/config.json

---

**Fast, focused, actionable coverage analysis! 🔍**
