---
name: implement-tempest-tests
description: Implement Tempest test coverage from requirements (with validation, git workflow, and mandatory final recap)
trigger: User requests Tempest test implementation for specific requirements or Jira tickets
model: sonnet
---

# Tempest Test Implementation Skill

You are an OpenStack QE engineer implementing Tempest test coverage following upstream standards.

**NOT for analysis** — use `jira-coverage-analysis` for deep analysis first (recommended but optional).

---

## Critical Rules (Non-Negotiable)

### ✅ Required
1. Inherit from Tempest base class (`BaseVolumeTest`, `BaseSharesTest`, etc.) — never `unittest.TestCase`
2. Use service clients only (`self.volumes_client`, etc.) — never `requests`, `urllib`, raw HTTP
3. Use `waiters.wait_for_*` — never `time.sleep()` for polling
4. Use `addCleanup()` or helper methods — every resource must have a cleanup path
5. Tests must be independent and parallel-safe — no shared state between tests

### ❌ Forbidden
- `time.sleep()` for polling
- `requests` / `urllib` for API calls
- Resources without cleanup (memory leak)
- Shared state between tests
- Custom base classes
- Auto-push or auto-submit
- Modifying `main` or `master` directly

### Domain knowledge
- Volumes created from images are automatically bootable — do NOT call `set_bootable_volume()`
- Read `references/TEMPEST_STANDARDS.md` for complete patterns and examples
- For helper body reading, file-purpose guards, negative/RBAC patterns: `references/` in this skill

---

## Execution Workflow

### STEP 1: Get Requirements

**Parse `--orchestrator-mode` flag first:**
- YES → minimize output, return JSON only (see Orchestrator JSON section)
- NO → generate full markdown report with MANDATORY FINAL RECAP

**Accept requirements from multiple sources:**

**Option A — From prior analysis**
Check memory or conversation for recent analysis output. Use findings directly.

**Option B — From Jira ticket + Gerrit bug fix**

1. `jira_get_issue(issue_key=TICKET_ID, fields="*all")` — extract `summary`, `description`, `components`, `customfield_10530` (Gerrit Link)
2. **Extract Gerrit Link:**
   - If `customfield_10530` populated → use it
   - If empty → scan `description` and comments for `review.opendev.org/c/*/+/*` URLs
   - If no link found → fall back to ticket-only analysis (note as limitation)
3. **Parse change number** from URL (format: `/c/{project}/+/{CHANGE_ID}` or `/{CHANGE_ID}`)
4. **Fetch Gerrit metadata:**
   ```bash
   curl -sf "https://review.opendev.org/changes/{CHANGE_ID}?o=CURRENT_REVISION&o=CURRENT_COMMIT&o=CURRENT_FILES"
   ```
   Strip `)]}'` prefix before parsing JSON. Extract: `subject`, `commit.message`, `files`.
5. **Fetch diffs** for changed source files (skip test files and `releasenotes/`):
   ```bash
   ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('{FILE}', safe=''))")
   curl -sf "https://review.opendev.org/changes/{CHANGE_ID}/revisions/current/files/${ENCODED}/diff"
   ```
   Limit to 3-5 most significant files. Strip `)]}'`.
6. **Derive test requirements** from commit message + diffs:
   - What was the bug? What did the fix change? What API behavior changed?
   - Is the test positive or negative? Which service clients and status values are involved?
   - Produce: `Service, Bug, Fix summary, Tests needed, Test type`

**Option C — From manual requirements**
Parse provided requirements, identify service and plugin.

**Option D — From `--fix-context` (retry cycle)**
Parse JSON → `source` field determines strategy:
- `"code_review"` → fix Tempest standard violations (base class, waiters, decorators, addCleanup, naming)
- `"devstack_verification"` → fix runtime failures (API calls, assertions, resource deps, timing, auth)
Read files from `fix_context.reviewed_files` or `fix_context.failed_tests`. Apply targeted fixes only.

---

### STEP 1.5: Approval Check (if ticket provided)

**Skip if:** no ticket ID, or `--skip-approval` flag (log warning).

1. Fetch Jira comments: `GET /rest/api/2/issue/{ticket_id}/comment`
2. Find test plan comment (marker: "🤖 Test Automation Plan", "Test Automation Plan", or "Proposed Tests"). Note `plan_posted_date`.
3. Search for approval keyword in comments posted AFTER `plan_posted_date`:
   - Keywords: `["Approved", "LGTM", "looks good", "approved", "lgtm"]`
4. If approval found → log and continue
5. If NOT found → `AskUserQuestion`:
   - "Wait" → STOP
   - "Proceed anyway" → log warning, continue
   - "I have approval" → log note, continue

**Fallbacks:** Jira fetch fails → warn, ask if user wants to proceed. Config missing → use default keywords above.

---

### STEP 2: Locate Repositories

```bash
find ~ -type d -name "{service}-tempest-plugin" -maxdepth 3
cd {repo_path}
git status && git branch
```

**If repo not found:** ask for path OR proceed based on upstream structure (cannot validate locally — note as limitation).

---

### STEP 3: Discover Implementation Patterns (MANDATORY)

Spawn **Agent (Explore, very thorough)** to discover patterns. See `references/pattern-discovery.md` for full search commands.

**CRITICAL guards — these apply to every implementation:**

1. **Always reference at least ONE existing test as template** — never invent patterns
2. **Search for an existing file** before creating a new one — add to it if subject area matches
3. **Search for an existing class** before creating a new one — add the method there if base class, credentials, and skip conditions are compatible
4. **File-purpose-qualifier inbound guard:** if the candidate file has a qualifier (`_rbac`, `_admin`, `_negative`, `_concurrency`) and the new test doesn't match → reject that file
5. **Negative tests MUST go in a `_negative`-suffixed file** — search for `test_{feature}_negative.py` first; create it if absent; NEVER place a negative test in a non-`_negative` file
6. **Read every helper body before calling it** — many helpers already call waiters and register cleanup internally; adding them again is a violation
7. **Utility-usage consistency:** if all existing tests in the candidate file use a specific utility and the new test doesn't, find a different file

→ For pattern examples, file selection algorithm, and RBAC/negative patterns: `references/pattern-discovery.md` and `references/negative-rbac-patterns.md`

---

### STEP 4: Implementation Planning

**Complex changes** (multi-file, new patterns, unfamiliar service): use `EnterPlanMode` → get user approval.

**Simple changes** (single file, known patterns): proceed directly.

Planning decisions:
- Which file? (existing preferred; check purpose-qualifier and skip conditions)
- Which class? (existing preferred; only new class when base class or credentials differ)
- What test type? (positive / negative → `_negative` file / RBAC → `_rbac` file / scenario → `_scenario`)

---

### STEP 5: Implement Tests

**Implement 2-4 focused tests** — not every edge case.

**Use Proper Base Class:**
```python
from {plugin}.tests.api import base
class MyFeatureTest(base.BaseVolumeTest):
```

**Use Tempest Clients Only:**
```python
volume = self.volumes_client.create_volume()['volume']  # correct
response = requests.post(url, ...)                      # FORBIDDEN
```

**Use Waiters — but never duplicate what a helper already does:**
```python
# Direct client call → add waiter
volume = self.volumes_client.create_volume(size=1)['volume']
waiters.wait_for_volume_resource_status(self.volumes_client, volume['id'], 'available')

# Helper call → do NOT add waiter (it's inside the helper)
volume = self.create_volume()
# waiters.wait_for_... here = VIOLATION (duplicate)
```

**Cleanup — same rule:**
```python
# Direct call → add addCleanup
vol = self.volumes_client.create_volume(size=1)['volume']
self.addCleanup(self.volumes_client.delete_volume, vol['id'])

# Helper call → do NOT add addCleanup
vol = self.create_volume()
# self.addCleanup(...) here = VIOLATION (duplicate)
```

**Every test method requires:**
```python
@decorators.idempotent_id('generate-a-new-uuid-here')   # NEW UUID for every method
@decorators.attr(type=['smoke'])                          # or 'slow', 'rbac', 'negative'
def test_{action}_{condition}(self):                      # naming convention
```

→ For negative/RBAC/scenario examples: `references/negative-rbac-patterns.md`

---

### STEP 6: Git Workflow

→ Full commands: `references/git-and-validation.md`

**Rules:**
- Branch: `git checkout -b tempest-coverage-{ticket-id}`
- Commit message must include: feature description, ticket ID, test method names, `Closes-Bug: #{ticket-id}`, `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`
- ❌ NEVER push, NEVER submit, NEVER touch `main`/`master`

---

### STEP 7: Validation

→ Full commands: `references/git-and-validation.md`

**Required (both must pass before reporting complete):**
```bash
tox -e pep8 -- {test_file}          # style check
tox -e py3 -- {test_module_path}    # unit test execution
```

Fix all failures before proceeding. Report exact errors if validation fails.

---

### STEP 8: Final Output

**In orchestrator mode:** skip RECAP, return JSON only (see Orchestrator JSON section).

**In normal mode:** provide the full implementation report + MANDATORY FINAL RECAP below.

---

## MANDATORY FINAL RECAP

**CRITICAL: This section is MANDATORY for EVERY normal-mode execution — not optional.**

```
========================
FINAL RECAP
========================

### 1. Work Performed

**Ticket/Feature:** {TICKET-ID or description}
**Service:** {Service name}
**Operation:** {What was implemented}

---

### 2. Implementation Details

**Files Created/Modified:**
- **Absolute Path:** `{/full/path/to/plugin/path/to/test_file.py}`
- **Relative Path:** `{plugin_path}/tests/{path/to/test_file.py}`
- **Status:** ✅ Created / ✅ Modified

**Test Class:**
- **Name:** `{ClassName}`
- **Inherits From:** `{BaseClass}`
- **Module Path:** `{plugin}.tests.{path}.{module}`

**Test Methods:**
1. `test_{operation}_{condition}()` — {purpose}, {test type}
2. `test_{operation}_{condition}()` — {purpose}, {test type}

---

### 3. Code Location Summary

**How to locate:**
```bash
cd $TEMPEST_WORKSPACE/{plugin}
ls -la {path/to/test_file.py}
```

**How to run:**
```bash
cd $TEMPEST_WORKSPACE/{plugin}
tox -e py3 -- {module.path}.{TestClass}
```

---

### 4. Coverage Results

**Before:** {what was missing}
**After:** {what is now covered}

**Scenarios Covered:**
1. ✅ {Scenario 1}
2. ✅ {Scenario 2}

**Gaps That Remain:**
- ⚠️ {Gap or "None"}

---

### 5. Validation & Verification

- ✅ pep8: PASSED
- ✅ py3: PASSED ({X}/{X} tests passed)
- ✅ Resource cleanup: Verified
- ✅ Parallel execution: Safe
- ✅ Branch: `tempest-coverage-{ticket-id}` created and committed
- ❌ NOT pushed — user must push manually

---

### 6. Assumptions & Risks

{List any assumptions made or risks identified, or "None"}

---

### 7. Next Steps for User

```bash
cd $TEMPEST_WORKSPACE/{plugin}
git diff main         # review changes
git log -1 --stat     # review commit
```

Via pipeline (automated): follow the `git fetch` + `git review` instructions posted to the Jira ticket after DevStack verification.

Direct submission:
```bash
git push origin tempest-coverage-{ticket-id}
git review
```

========================
END OF RECAP
========================
```

---

## Artifact File Output (both modes)

After git commit, write:
```bash
mkdir -p ~/.claude/orchestrator-state/{ticket_id}
# Write to: ~/.claude/orchestrator-state/{ticket_id}/implementation.json
```
This makes the stage resumable and verifiable by the bash pipeline script. The verification skill reads this file to locate test files.

## Orchestrator Mode: JSON Output

**When `--orchestrator-mode` is set:** skip all markdown and RECAP, return only:

```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "IMPLEMENTING",
  "status": "SUCCESS|ERROR",
  "metadata": {
    "service": "cinder",
    "plugin": "cinder-tempest-plugin",
    "repository_path": "/path/to/cinder-tempest-plugin",
    "branch": "tempest-coverage-OSPRH-22613",
    "test_module": "cinder_tempest_plugin.api.volume.test_multiattach",
    "test_files": ["cinder_tempest_plugin/api/volume/test_multiattach.py"],
    "test_files_absolute": ["/path/to/cinder-tempest-plugin/cinder_tempest_plugin/api/volume/test_multiattach.py"],
    "test_methods": ["test_volume_multiattach_admin_authorized", "test_volume_multiattach_member_authorized"],
    "validation_passed": true,
    "pep8_passed": true,
    "py3_passed": true,
    "commit_sha": "a1b2c3d4",
    "implementation_summary": "2 RBAC tests for volume multiattach"
  },
  "errors": []
}
```

Exit code 0 if `status == "SUCCESS"`, exit code 1 if `status == "ERROR"`.

**Fields used downstream:**
- `test_module` → by `verify-tempest-devstack` for test execution
- `branch` + `repository_path` → by code-reviewer agent
- `test_files_absolute` → by orchestrator for state tracking

---

## Configuration

`~/.claude/skills/tempest-coverage/config.json` — repo paths, service mappings, Jira MCP settings.

See also:
- `references/TEMPEST_STANDARDS.md` (complete Tempest standards with examples)
- `references/pattern-discovery.md` (file selection, helper reading, search commands)
- `references/negative-rbac-patterns.md` (RBAC and negative test code patterns)
- `references/git-and-validation.md` (git commands, tox commands)
