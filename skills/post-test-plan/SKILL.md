---
name: post-test-plan
description: Post test automation plan to Jira for stakeholder approval (with duplicate detection and manual fallback)
trigger: User wants to share test coverage plan in Jira or needs stakeholder approval
model: sonnet
---

# Post Test Plan to Jira Skill

Post a formatted test automation plan to a Jira ticket for stakeholder approval.

**NOT for:** creating analysis (use `/jira-coverage-analysis`) or implementing tests (use `/implement-tempest-tests`).

---

## STEP 1: Get Analysis

**Parse `--orchestrator-mode` first:** if set, minimize output, return JSON only; if no analysis available → return ERROR immediately.

In normal mode: check memory for recent analysis. If not found → offer to run analysis or accept manual input.

---

## STEP 2: Format as Jira Markdown

**Select template:**
- Default: `templates/jira_plan_format1.md` (first-time post)
- Revised: `templates/jira_plan_format_revised.md` (after discussion feedback — see STEP 2.5)

**Format the plan:**

```markdown
## 🤖 Test Automation Plan

**Feature:** {feature_description}

### Proposed Tests

| Test Method | What It Tests | Validates |
|---|---|---|
| `test_name_1` | {description} | {validation} |
| `test_name_2` | {description} | {validation} |

### Existing Coverage (No Changes)

| Test | Repository | Coverage | Status |
|---|---|---|---|
| `existing_test_1` | {plugin-name}/{path}/{file.py} (origin/master) | {coverage} | ✅ Covered |

### ✅ Approval Required

**Action:** Comment **"Approved"** below to implement these tests

Alternative: React with 👍 to this comment

**Implementation:** `{file_location}`
```

**CRITICAL rules for the plan:**
- Only include MERGED tests in "Existing Coverage" (verified on `origin/master` or `origin/main`)
- NEVER include local/feature-branch/uncommitted tests
- Repository column format: `{plugin-name}/{path}/{file.py} (origin/master)` or `(origin/main)`
- Keep test list focused (2-4 tests, not 5+)
- NEVER skip the approval section (both text comment AND 👍 reaction options must be present)

---

## STEP 2.5: Duplicate Detection

1. Read config: `jira_integration.post_test_plan.duplicate_detection.enabled`. If disabled → skip.
2. If Jira MCP available: `mcp__mcp-atlassian__jira_get_issue(issue_key, fields="comment", comment_limit=100)`
   If MCP not available → log warning, skip check.
3. Search comments for markers from `config.duplicate_detection.comment_markers`:
   `["🤖 Test Automation Plan", "Test Automation Plan", "## 🤖 Test Automation Plan"]`
4. If duplicate found, behavior from `config.duplicate_detection.on_duplicate_found`:
   - `"ask_user"` → show options: skip / repost / view
   - `"auto_skip"` → skip, inform user, END
   - `"auto_repost"` → add `[UPDATED]` prefix, proceed

**If user chooses repost AND `discussion_flagged` is present in pipeline state:**
```bash
cat ~/.claude/orchestrator-state/pipeline-state.json → tickets[ticket_id].discussion_flagged
```
Use `templates/jira_plan_format_revised.md`. Ask user for: revised test list, dropped tests + reasons. Populate:
- `{{REVIEWER_NAME}}` ← `discussion_flagged.comment_by`
- `{{FEEDBACK_DATE}}` ← `discussion_flagged.comment_at`
- `{{REVISED_TESTS_TABLE_ROWS}}` ← user-provided
- `{{DROPPED_TESTS_WITH_REASONS}}` ← user-provided
- `{{IMPLEMENTATION_LOCATION}}` ← from analysis
- `{{DATE}}` ← current date

**If user chooses repost but NO `discussion_flagged`:** prefix header with `[UPDATED]`, add timestamp line.

**Error handling:** comment fetch fails → skip check, proceed. Config missing → default to `ask_user`.

---

## STEP 3: Post to Jira

1. Check Jira MCP available AND `READ_ONLY_MODE == false`. If either fails → show formatted plan for manual posting (read-only fallback).
2. Post: `mcp__mcp-atlassian__jira_add_comment`
3. Add label: `automation-test-plan`

---

## STEP 3.5: Schedule Approval Monitoring

**Only run if STEP 3 successfully posted.**

1. `CronList` → search returned jobs for one whose `prompt` contains `"approval-monitor"`.
   - Found → log "approval monitoring already active", skip. Do NOT create a second job.
   - Not found → create:

2. Read `references/approval-monitor-cron-prompt.md` for the full cron prompt text. Then:
   ```
   CronCreate with:
     cron:      "17 */4 * * *"
     durable:   true
     recurring: true
     prompt:    <full prompt from references/approval-monitor-cron-prompt.md>
     reason:    "Polling Jira for test plan approval on pending tickets"
   ```

3. If CronCreate fails → log warning, do NOT fail the skill (plan was posted successfully).

---

## STEP 4: Save Metadata and Write Artifact

Write artifact file:
```bash
# Write to: ~/.claude/orchestrator-state/{ticket_id}/plan.json
# Contents: {"ticket_id": "...", "jira_comment_id": "...", "plan_posted_at": "..."}
```
This makes the stage resumable and verifiable by the bash pipeline script.

Save to memory: ticket ID → plan posted date. Optionally write to `.claude/test-plans/{TICKET-ID}.md`.

---

## Orchestrator JSON Output

**When `--orchestrator-mode` is set:**

```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "AWAITING_APPROVAL",
  "status": "SUCCESS|ERROR",
  "metadata": {
    "plan_posted": true,
    "plan_posted_at": "2026-05-19T14:30:00Z",
    "jira_comment_id": "12345",
    "approval_deadline": "2026-05-26T14:30:00Z",
    "plan_summary": "3 tests proposed for volume multiattach coverage",
    "approval_monitoring_scheduled": true
  },
  "errors": []
}
```

Exit code 0 on SUCCESS, 1 on ERROR.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| Analysis not found (normal mode) | Offer to run analysis or accept manual input |
| Analysis not found (orchestrator mode) | Return ERROR immediately |
| Jira MCP unavailable | Show formatted plan for manual posting |
| READ_ONLY_MODE | Show formatted plan for manual posting |
| Posting fails | Show error + formatted plan as fallback |
| Duplicate check fails | Skip check, proceed |
| CronCreate fails | Log warning, don't fail skill |
