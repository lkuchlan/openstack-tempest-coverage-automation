---
name: jira-coverage-analysis
description: Analyze Jira tickets to identify existing Tempest test coverage and gaps (analysis only, no implementation)
trigger: User requests test coverage analysis for Jira tickets or wants to audit existing coverage
model: sonnet
---

# Jira Coverage Analysis Skill

Analyze Jira tickets to identify existing Tempest test coverage and gaps. **Analysis only — NO implementation.**

## ⚠️ CRITICAL: Two-Repository Rule

OpenStack tests live in TWO repositories. **Search BOTH in every analysis — main Tempest FIRST.**

- **Main Tempest** (`~/automation_projects/tempest`) — 70-80% of tests. Contains core API tests: `tempest/api/{service}/`
- **Service Plugin** (`~/automation_projects/{service}-tempest-plugin`) — 20-30%. Advanced features: `{service}_tempest_plugin/api/`

**Example:** `tempest/api/volume/test_volumes_actions.py` covers volume upload-to-image in main Tempest. Searching only the plugin would produce a false "missing coverage" report.

---

## Execution Workflow

### STEP 1: Fetch Ticket and Extract Requirements

**Parse `--orchestrator-mode` first:** if set, return JSON only (see Output section).

1. `jira_get_issue(issue_key=TICKET_ID, fields="*all")` — must use `fields="*all"` to capture parent and Epic Link fields.
   If Jira MCP unavailable → ask user for ticket details.

2. **Sufficiency check:** ticket is sufficient if it has identifiable OpenStack service + specific feature/API + at least one of: description, acceptance criteria, scenario. Generic summaries ("Improve upstream coverage") and empty descriptions are insufficient.

3. **Parent traversal if insufficient** — do NOT ask the user first; always try the hierarchy first:

   ```
   max_levels = 3
   level = 0
   while ticket insufficient AND level < max_levels:
       level += 1
       # Extract parent key in order:
       parent_key = ticket["fields"].get("parent", {}).get("key")        # next-gen Jira
       if not parent_key: parent_key = ticket["fields"].get("customfield_10014")  # Epic Link
       if not parent_key: parent_key = ticket["fields"].get("customfield_10008")  # alt Epic Link
       if parent_key is None: break
       parent_ticket = jira_get_issue(parent_key, fields="*all")
       context_tickets.append(parent_ticket)
       if parent_ticket is sufficient: break
       current_ticket = parent_ticket
   ```

   Merge context from all levels. Most specific (lowest) ticket wins on conflicts.
   Note in report: `"Requirements derived from parent ticket OSPRH-XXXXX (Epic: "...")"`

4. Parse requirements: service, API/operation, expected behavior, acceptance criteria.

---

### STEP 2: Locate Repositories

```bash
find ~ -type d -name "tempest" -maxdepth 3 | grep -E "/(tempest|openstack-tempest)$"
find ~ -type d -name "{service}-tempest-plugin" -maxdepth 3
```

- Main Tempest missing → report as **major blocker** (do not silently skip)
- Plugin missing → note in report, continue

---

### STEP 3: Discover Existing Coverage

Spawn **Agent (Explore, very thorough)** to search BOTH repos. Search main Tempest first.

**Main Tempest (PRIMARY):**
```bash
cd {tempest_path}
git grep -i "{feature}" origin/master -- "tempest/api/{service}/*.py" | grep test
git ls-tree -r origin/master --name-only | grep "tempest/api/{service}/test_"
git grep "def test.*{operation}" origin/master -- tempest/api/
```

**Service Plugin (SECONDARY):**
```bash
cd {plugin_path}
git grep -i "{feature}" origin/master -- "{service}_tempest_plugin/**/*.py" | grep test
git ls-tree -r origin/master --name-only | grep "test_"
```

---

### STEP 3.5: Remote State Check (CRITICAL — Prevent False Coverage Reports)

Only MERGED tests count as existing coverage. Tests on local/feature branches or uncommitted **do not exist** — omit them completely.

For each test file found in STEP 3, in BOTH repos:

```bash
cd {repo}
git fetch origin
DEFAULT_BRANCH=$(git remote show origin | grep "HEAD branch" | awk '{print $NF}')

# Check file exists on remote
if git ls-tree -r origin/$DEFAULT_BRANCH --name-only | grep -q "^${FILE_PATH}$"; then
    # Check method exists on remote
    if git show origin/$DEFAULT_BRANCH:$FILE_PATH | grep -q "def test_{method_name}"; then
        CATEGORY="merged"       # ✅ Report as existing coverage
    else
        CATEGORY="in_dev"       # ❌ COMPLETELY IGNORE — do not mention
    fi
else
    CATEGORY="in_dev"           # ❌ COMPLETELY IGNORE — do not mention
fi

# Also check uncommitted changes
if git diff --name-only | grep -q "^${FILE_PATH}$"; then
    CATEGORY="local"            # ❌ COMPLETELY IGNORE — do not mention
fi
```

Only merged tests appear in the report.

---

### STEP 4: Gap Analysis

Compare requirements against MERGED coverage. Identify 2-4 focused gaps — not every possible edge case.

- HIGH priority: directly addresses the ticket requirement
- MEDIUM: related scenarios explicitly mentioned in ticket
- LOW: nice-to-have (skip unless the ticket is explicitly broad)

→ For examples and the full framework: `references/gap-analysis-guide.md`

---

### STEP 5: Effort Estimation + Recommendations

Estimate hours per gap. Specify: which repo, which file, which base class, which clients.

→ For estimation tables and details: `references/gap-analysis-guide.md`

---

### STEP 6: Generate Report (MANDATORY — every execution)

**Markdown format (normal mode):**
```markdown
# Coverage Analysis: {TICKET-ID}

**Ticket:** {TICKET-ID} - {Summary}
**Service:** {Service} | **Feature:** {Feature}

## 1. Coverage Status
✅ COMPLETE / ⚠️ PARTIAL / ❌ MISSING

## 2. Existing Tests (MERGED only — both repos)

### A. Main Tempest
**Repository:** `tempest` (origin/{default_branch})
**File:** `tempest/api/{service}/test_{feature}.py`
- `test_{scenario}()` — {what it tests}

### B. Service Plugin
**Repository:** `{service}-tempest-plugin` (origin/{default_branch})
- `test_{scenario}()` — {what it tests}
- OR: **No service-specific tests found**

## 3. Implementation Plan (if gaps exist)
- `test_{scenario}()` — {validates} — Priority: HIGH
- `test_{scenario}()` — {validates} — Priority: HIGH

**Repository:** `{tempest OR service-tempest-plugin}`
**Directory:** `{path}`
**Base class:** `Base{Service}Test`
**Clients:** `{service}_client`

**Next step:** `/implement-tempest-tests {TICKET-ID}` OR "No action needed"
```

**Write artifact file (always, both modes):**
```bash
mkdir -p ~/.claude/orchestrator-state/{ticket_id}
# Write to: ~/.claude/orchestrator-state/{ticket_id}/analysis.json
```
This makes the stage resumable and verifiable by the bash pipeline script.

**JSON format (orchestrator mode):**
```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "ANALYZED",
  "status": "SUCCESS|ERROR",
  "metadata": {
    "service": "cinder",
    "plugin": "cinder-tempest-plugin",
    "coverage_status": "COMPLETE|PARTIAL|MISSING",
    "gaps_identified": 3,
    "priority_breakdown": {"HIGH": 2, "MEDIUM": 1, "LOW": 0},
    "effort_estimate_hours": 6,
    "existing_test_files": ["tempest/api/volume/test_volumes_actions.py"],
    "recommended_repository": "cinder-tempest-plugin",
    "analysis_summary": "Brief summary of gaps found"
  },
  "errors": []
}
```

Exit code 0 on SUCCESS, 1 on ERROR.

---

## Critical Rules

### ✅ DO
- Search **BOTH** repos — main Tempest FIRST
- Use `fields="*all"` when fetching Jira tickets
- Traverse parent hierarchy (up to 3 levels) before asking user for more info
- Note in report which parent(s) provided context
- Report only tests that exist on `origin/master` or `origin/main` in BOTH repos
- Recommend 2-4 focused tests — not 5+ granular variations
- Note in report if main Tempest is missing (it's a major blocker)

### ❌ DON'T
- Search only the plugin — missing 70% of tests
- Report tests from local/feature branches as "existing coverage"
- Ask user for more info before attempting parent traversal
- Implement tests, run tox, create git branches, or modify code
- Recommend excessive coverage beyond ticket scope
