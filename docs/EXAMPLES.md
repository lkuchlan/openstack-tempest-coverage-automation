# Usage Examples

Real-world workflows for OpenStack Tempest Coverage Automation.

## Example 1: Analyze and Implement from Jira

**Scenario:** Customer bug requires RBAC test coverage

```bash
claude

# Step 1: Analyze ticket
> /jira-coverage-analysis OSPRH-22613

# Output:
# ✅ Existing: Basic volume tests
# ❌ Missing: RBAC tests for multi-attach (HIGH priority, 4-6 hours)
# 💡 Recommendation: Implement RBAC coverage first

# Step 2: Implement after review
> /implement-tempest-tests OSPRH-22613

# Output:
# ✅ Created: test_volume_multiattach_rbac.py
# ✅ Validated: tox pep8 + py3 passed
# ✅ Branch: tempest-coverage-OSPRH-22613

# Step 3: Review and push
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
git diff HEAD~1
git push origin tempest-coverage-OSPRH-22613
```

## Example 2: Sprint Planning with Batch Analysis

**Scenario:** Plan sprint capacity for 5 tickets

```bash
> /jira-coverage-analysis OSPRH-1 OSPRH-2 OSPRH-3 OSPRH-4 OSPRH-5

# Output:
# Total gaps: 15
# Total effort: 32-40 hours
# Priority distribution:
#   HIGH: 6 gaps (18-22 hours)
#   MEDIUM: 6 gaps (10-14 hours)
#   LOW: 3 gaps (4-6 hours)

# Decision: Assign HIGH priority to sprint, defer LOW
```

## Example 3: Without Jira MCP

**Scenario:** Work without Jira integration

```bash
> /implement-tempest-tests

# Claude prompts:
# - Service name? → Cinder
# - Feature/API? → Volume multi-attach
# - Test scenarios needed? → RBAC tests for admin/member/reader roles
# - Acceptance criteria? → Admin can multi-attach, member can attach own volumes, reader denied

# Same quality implementation as with Jira
```

---

## Common Workflows

### Workflow 1: Analyze, Post Plan, and Implement from Jira

**Complete workflow with stakeholder approval**

```bash
# Step 1: Analyze ticket for coverage gaps
/jira-coverage-analysis OSPRH-22613

# Review analysis report
# ✅ Existing coverage identified
# ❌ Gaps prioritized (HIGH/MEDIUM/LOW)
# ⏱️ Effort estimated (X-Y hours)

# Step 2: Post plan to Jira for stakeholder approval
/post-test-plan OSPRH-22613
# Posts formatted plan as Jira comment (or shows for manual posting)
# ✅ Posted to OSPRH-22613
# 📌 Added label: automation-test-plan

# Step 3: Wait for stakeholder approval in Jira
# Stakeholder reviews plan
# Stakeholder comments: "Approved" or reacts with 👍

# Step 4: Implement approved tests
/implement-tempest-tests OSPRH-22613
# ✅ Tests generated following Tempest standards
# ✅ Branch created: tempest-coverage-OSPRH-22613
# ✅ Validated: tox -e pep8,py3 passed
# ✅ Committed with proper message

# Step 5: Review generated tests, run additional validation
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
git diff HEAD~1  # Review changes
tox -e pep8,py3  # Additional validation

# Step 6: Push to remote for review
git push origin tempest-coverage-OSPRH-22613
git review  # If using Gerrit for upstream
```

**When to use:**
- Team requires formal approval before implementation
- Stakeholders want visibility into test plans
- Working on high-priority or complex features

---

### Workflow 2: Analyze and Implement Directly (No Approval)

**Fast-track workflow for straightforward tickets**

```bash
# Step 1: Analyze ticket for coverage gaps
/jira-coverage-analysis OSPRH-22613

# Review analysis report, decide to implement

# Step 2: Implement tests directly
/implement-tempest-tests OSPRH-22613
# ✅ Tests implemented and validated
# ✅ Branch: tempest-coverage-OSPRH-22613

# Step 3: Review and push
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
tox -e pep8,py3
git push origin tempest-coverage-OSPRH-22613
```

**When to use:**
- Straightforward coverage gaps
- Quick bug fixes
- Internal team work (no external stakeholders)
- Trust in automation quality

---

### Workflow 3: Batch Analysis for Sprint Planning

**Analyze multiple tickets to estimate sprint capacity**

```bash
# Analyze multiple tickets at once
/jira-coverage-analysis OSPRH-22613 OSPRH-22614 OSPRH-22615

# Output:
# 📊 Analyzed 3 tickets
# 
# OSPRH-22613 (Cinder RBAC):
#   ❌ Missing: 3 tests (HIGH priority)
#   ⏱️ Effort: 4-6 hours
#
# OSPRH-22614 (Manila Quotas):
#   ✅ Complete: All scenarios covered
#   ⏱️ Effort: 0 hours
#
# OSPRH-22615 (Glance Multi-backend):
#   ❌ Missing: 5 tests (MEDIUM priority)
#   ⏱️ Effort: 6-8 hours
#
# 📈 Total effort: 10-14 hours
# 🎯 Recommended: Implement OSPRH-22613 and OSPRH-22615

# Review effort estimates
# Plan sprint based on total hours
# Implement tickets in priority order
/implement-tempest-tests OSPRH-22613
# (After completion)
/implement-tempest-tests OSPRH-22615
```

**When to use:**
- Sprint planning sessions
- Capacity estimation
- Prioritizing backlog
- Team resource allocation

---

### Workflow 4: Without Jira MCP (Manual Requirements)

**Work without Jira integration (fully manual mode)**

```bash
# Skills work without Jira integration
# Provide requirements manually when prompted

/implement-tempest-tests

# Claude will ask for:
# - Service name (e.g., Cinder)
# - Feature/API description
# - Test scenarios needed
# - Acceptance criteria

# Example interaction:
# > Service name?
# Cinder

# > Feature/API description?
# Volume multi-attach RBAC

# > Test scenarios needed?
# - Admin can multi-attach volumes
# - Member can attach own volumes
# - Reader cannot attach volumes (negative test)

# > Acceptance criteria?
# - Admin role: All multi-attach operations succeed
# - Member role: Can attach own volumes, denied for other users' volumes
# - Reader role: All attach operations denied with 403

# Same quality implementation as with Jira
# ✅ Tests generated following Tempest standards
# ✅ Validated with tox
# ✅ Branch created and committed
```

**When to use:**
- Jira not available or not configured
- Working from documentation instead of tickets
- Testing the skills locally
- Custom requirements not in Jira

---

### Workflow 5: Post Plan After Analysis

**Separate analysis and posting for review**

```bash
# Step 1: Analyze ticket
/jira-coverage-analysis OSPRH-22613
# Review output, make notes

# Step 2: Review analysis with team
# Discuss priorities and approach
# Decide on implementation strategy

# Step 3: Post plan for approval
/post-test-plan OSPRH-22613
# ⚠️ Duplicate detected: Plan already exists
# Options: Skip / Repost / View
# Choose: Repost
# ✅ Posted with [UPDATED] prefix

# Step 4: Implement after approval
/implement-tempest-tests OSPRH-22613
```

**When to use:**
- Need time to review analysis before posting
- Want team discussion before stakeholder approval
- Updating existing plans with new information

---

## See Also

- [README.md](../README.md) - Project overview
- [QUICKSTART.md](QUICKSTART.md) - 5-minute setup guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
