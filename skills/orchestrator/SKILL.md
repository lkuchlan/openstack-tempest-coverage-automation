---
name: tempest-coverage-orchestrator
description: Approval monitoring and manual pipeline control for the Tempest coverage pipeline
trigger: User wants to check approval status, manually recover a ticket, or mark a patch as submitted
model: sonnet
---

# Tempest Coverage Orchestrator

## Role

**The automated pipeline is driven by `scripts/run-pipeline.sh` (bash), not this skill.**

This skill handles two things:
1. **Approval checking** — called by `run-pipeline.sh` at stage 4 to check whether AWAITING_APPROVAL tickets got approved in Jira
2. **Manual operations** — `--status`, `--retry`, `--reset-to`, `--submitted`

For the full stage machine definition and all stage transition logic, see `references/pipeline-stages.md`.

**Rule:** Only advance ONE stage per ticket per orchestrator invocation. State is checkpointed after every transition.

---

## Usage

```bash
/tempest-coverage-orchestrator TICKET-ID                        # Check approval (stage 4)
/tempest-coverage-orchestrator TICKET-ID --status               # Show ticket state
/tempest-coverage-orchestrator TICKET-ID --retry                # Retry from failed stage
/tempest-coverage-orchestrator TICKET-ID --reset-to ANALYZED    # Force to a stage
/tempest-coverage-orchestrator TICKET-ID --submitted <gerrit_url>  # Mark as submitted
/tempest-coverage-orchestrator TICKET-ID --submitted <gerrit_url> --force  # Skip repo check
/tempest-coverage-orchestrator --dry-run TICKET-ID              # Preview without acting
```

---

## STEP 0: Parse Input, Acquire Lock, Load State

**Parse flags:**
- `--status` → skip to STEP 4 (report only, no lock needed)
- `--dry-run` → report what would happen, take no actions, prefix output with `[DRY-RUN]`
- `--retry` → after state load, reset ticket to `error.stage_when_failed` or IMPLEMENTING (if CODE_REVIEW_FAILED)
- `--reset-to STAGE` → after state load, force ticket to that stage
- `--submitted <gerrit_url>` → go directly to --submitted handler in STEP 2
- `--force` alongside `--submitted` → skip Gerrit repo verification

**Acquire pipeline lock** (skip for `--status` and `--dry-run`):

```bash
LOCK_FILE=~/.claude/orchestrator-state/.pipeline.lock
STALE_MINUTES=10

if [ -f "$LOCK_FILE" ]; then
    locked_at=$(cat "$LOCK_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['locked_at'])")
    age_minutes=$(( ( $(date +%s) - $(date -jf "%Y-%m-%dT%H:%M:%SZ" "$locked_at" +%s 2>/dev/null \
                      || date -d "$locked_at" +%s) ) / 60 ))
    if [ "$age_minutes" -lt "$STALE_MINUTES" ]; then
        echo "⚠️ Pipeline locked (started ${age_minutes}m ago). Exiting."
        exit
    fi
    echo "ℹ️ Stale lock (${age_minutes}m) — overwriting"
fi
echo '{"locked_by": "orchestrator", "locked_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > "$LOCK_FILE"
```

**CRITICAL:** Always release the lock on every exit path:
```bash
rm -f ~/.claude/orchestrator-state/.pipeline.lock
```

**Load state:**
```bash
cat ~/.claude/orchestrator-state/pipeline-state.json
```
- If empty or malformed: initialize with `{"version":1,"last_run":null,"tickets":{}}`
- If JSON parse fails: report the error, do NOT overwrite with empty state, release lock and exit

**Crash recovery** — if `state.parallel_execution_batch` is not null:
- Calculate elapsed: `now - parallel_execution_batch.started_at`
- If elapsed > `config.parallel_execution.batch_timeout_minutes`: mark all `in_progress` tickets as ERROR, clear batch (`parallel_execution_batch: null`), write state
- Otherwise: clear batch record, write state

**Load config** from `config.json` adjacent to this SKILL.md.

---

## STEP 1: Approval Check (Primary Use — Stage 4)

**When called without --submitted, --retry, --reset-to, or --status.**

For the target ticket at stage `AWAITING_APPROVAL`:

1. Check `approval_deadline`. If `now > approval_deadline`:
   - Update state: `stage: "TIMED_OUT", history: [...]`
   - Post Jira comment: "⏰ Approval deadline passed. Ticket timed out."
   - Checkpoint state. Go to STEP 3.

2. Fetch Jira comments:
   ```
   Use mcp__mcp-atlassian__jira_get_issue(issue_key=TICKET-ID, fields="comment")
   ```
   If Jira MCP unavailable: mark ticket as ERROR with message "Jira MCP unavailable", continue.

3. Find the test plan comment (contains "🤖 Test Automation Plan") and note its timestamp as `plan_posted_at`.

4. For each comment posted AFTER `plan_posted_at`:
   - Skip comments by authors whose name contains "Automation" or "Claude"
   - Check for rejection keywords (from `config.approval.rejection_keywords`): `["rejected", "not approved", "decline", "Rejected"]`
   - Check for approval keywords (from `config.approval.approval_keywords`): `["approved", "LGTM", "looks good", "Approved"]`
   - Check for 👍 reaction on the plan comment via Jira REST API:
     ```bash
     curl -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
       "$JIRA_URL/rest/api/3/issue/$TICKET_ID/comment/$PLAN_COMMENT_ID"
     ```
     (Credentials from `~/.config/tempest-pipeline/.env`)

5. Decision:
   - **Rejection found** → `stage: "REJECTED"`, post Jira comment, checkpoint
   - **Approval found (keyword or 👍)** → `stage: "APPROVED"`, record `approved_by`, `approved_at`, post Jira comment "✅ Approved by {name}", checkpoint
   - **Neutral comment found** (neither approval nor rejection, but a substantive question/concern):
     - Set `discussion_flagged: {comment_by, comment_at, comment_text}` in ticket state
     - Do NOT advance stage (stays AWAITING_APPROVAL)
     - Note in summary: "NEEDS DISCUSSION — address stakeholder feedback, then re-run /post-test-plan"
   - **No decision** → increment `approval_checks`, update `last_check`, checkpoint

---

## STEP 2: Manual Operations

### --status

Read `pipeline-state.json`. Print summary table for the specified ticket (or all tickets). Go to STEP 4.

### --retry

- If ticket stage is `ERROR`: reset to `error.stage_when_failed`, clear error fields
- If ticket stage is `CODE_REVIEW_FAILED`: reset to `IMPLEMENTING`, clear code review failure fields
- Write state. Log the reset. Go to STEP 3.
- (The bash script will pick up the ticket at its new stage on the next run.)

### --reset-to STAGE

Force ticket to the specified stage. Clear any error/failure fields. Write state. Log the reset. Go to STEP 3.

### --submitted \<gerrit_url\>

**PRE-ACTION: Verify the Gerrit URL points to a Tempest repository.**

Skip if `--force` is set (print `⚠️ --force set — skipping repo verification`).

**Step A — Extract repo name:**

1. **Standard URL** (`review.opendev.org/c/{repo-path}/+/{number}`):
   - Extract `{repo-path}` between `/c/` and `/+/`
   - Set `REPO_NAME = {repo-path}`, `REPO_SOURCE = "url"`

2. **Hash/query URL** (`review.opendev.org/#/q/{hash}` or `/q/{hash}`):
   - Extract `{hash}`, set `REPO_SOURCE = "api"`

3. **Unrecognized format:**
   - Print `⚠️ Cannot parse repo from URL. Skipping verification and proceeding.`
   - Skip to Actions below.

**Step B — Fetch from Gerrit API (hash format only):**
```bash
GERRIT_RAW=$(curl -sf --max-time 15 "https://review.opendev.org/changes/${GERRIT_CHANGE_ID}" 2>&1)
```
- If curl fails: `⚠️ Gerrit API unreachable (exit {code}). Skipping verification and proceeding.`
- Strip `)]}'` prefix, parse JSON, extract `project` field as `REPO_NAME`
- If malformed: print one-line warning, skip to Actions.

**Step C — Check repo name contains "tempest" (case-insensitive):**
- YES → `✅ Gerrit repo verified: '{REPO_NAME}'` → proceed to Actions
- NO → print error, **STOP. Do NOT write state. Release lock.**
  ```
  ❌ Repo '{REPO_NAME}' does not appear to be a Tempest repository.
     Re-run with --force to override: /orchestrator TICKET-ID --submitted <url> --force
  ```

**Actions:**

1. Update Jira — set Gerrit Link field:
   ```
   Use mcp__mcp-atlassian__jira_update_issue
   fields: {"customfield_10530": "<gerrit_url>"}
   ```

2. Post Jira comment:
   ```
   Use mcp__mcp-atlassian__jira_add_comment
   Body: config.verification.submitted_jira_comment
   ```

3. Update state:
   ```json
   {
     "stage": "SUBMITTED",
     "submitted_at": "<timestamp>",
     "gerrit_url": "<gerrit_url>",
     "gerrit_verification": {"repo": "<REPO_NAME>", "passed": true},
     "history": [..., {"stage": "SUBMITTED", "timestamp": "<timestamp>"}]
   }
   ```
   If `--force`: `"gerrit_verification": {"skipped": true}`

4. Checkpoint state immediately.

5. Print confirmation:
   ```
   ✅ TICKET-ID marked as SUBMITTED
      Repo: <REPO_NAME>
      Gerrit Link (customfield_10530) updated: <gerrit_url>
      Jira comment posted.
   ```

---

## STEP 3: Write State, Release Lock, Log

1. Update `last_run` timestamp in state.
2. Write **complete** state to `~/.claude/orchestrator-state/pipeline-state.json` using the Write tool.
   - Always write the complete state object, never partial updates.
3. Write per-ticket file: `~/.claude/orchestrator-state/tickets/TICKET-ID.json`
4. Release lock: `rm -f ~/.claude/orchestrator-state/.pipeline.lock`
5. Append to log: `~/.claude/orchestrator-state/logs/YYYY-MM-DD.log`
   ```
   [2026-05-07T08:17:00Z] OSPRH-22613: AWAITING_APPROVAL → APPROVED (approved by jsmith)
   ```

**CRITICAL:** Write state to disk AFTER EVERY stage transition. This ensures crash recovery.

---

## STEP 4: Summary Table

**Always** end with a clear summary table.

```
╔══════════════════════════════════════════════════════════════════╗
║              ORCHESTRATOR RUN SUMMARY                           ║
╠══════════════════════════════════════════════════════════════════╣
║ Ticket         │ Previous Stage       │ Current Stage           ║
╠────────────────┼──────────────────────┼─────────────────────────╣
║ OSPRH-22613    │ AWAITING_APPROVAL    │ APPROVED                ║
╚══════════════════════════════════════════════════════════════════╝
```

For `--dry-run`: prefix each action line with `[DRY-RUN]`, take no actual actions.

**Error escalation** — for tickets in ERROR or CODE_REVIEW_FAILED:
1. Mark with `❌` in the summary table
2. Post Jira comment (if MCP available):
   ```
   ❌ Pipeline error on {ticket_id} at stage {stage_when_failed}: {error_message}
   To retry: /orchestrator {ticket_id} --retry
   ```
3. Print dedicated ERROR section after the table.

---

## Error Handling

- **Jira MCP unavailable:** Mark affected tickets as ERROR, continue (do not crash)
- **State file corruption:** Report error, suggest manual inspection, do NOT overwrite with empty state, release lock and exit
- **Stale lock (> 10 min):** Overwrite lock and proceed

---

## State File Management

State path: `~/.claude/orchestrator-state/pipeline-state.json`

Key ticket state fields:
```json
{
  "stage": "AWAITING_APPROVAL",
  "entered_stage_at": "2026-05-28T10:40:45Z",
  "service": "cinder",
  "plugin": "cinder-tempest-plugin",
  "plan_posted_at": "2026-05-28T10:40:45Z",
  "jira_comment_id": "17105989",
  "approval_deadline": "2026-06-04T10:40:45Z",
  "approval_checks": 3,
  "last_check": "2026-06-01T13:47:22Z",
  "discussion_flagged": null,
  "approved_by": null,
  "approved_at": null,
  "implementation_details": null,
  "history": [...]
}
```

The `discussion_flagged` field: when a neutral comment (neither approval nor rejection) is detected, this field is set to `{comment_by, comment_at, comment_text}`. When `post-test-plan` is re-run and the user chooses to repost, the revised template is used automatically.

---

## Configuration Reference

Read `config.json` (adjacent to this SKILL.md):
- `state_directory` — where state files live (`~/.claude/orchestrator-state`)
- `approval.timeout_days` — days before TIMED_OUT (default: 7)
- `approval.approval_keywords` — `["approved", "LGTM", "looks good", "Approved"]`
- `approval.rejection_keywords` — `["rejected", "not approved", "decline", "Rejected"]`
- `verification.submitted_jira_comment` — template for submitted comment
- `verification.github_forks` — plugin name → GitHub fork URL mapping
- `verification.fork_push_ssh_key` — `~/.ssh/github_fork_push`
- `parallel_execution.batch_timeout_minutes` — for crash recovery

For the full stage machine, transition handlers, and parallel execution details:
→ See `references/pipeline-stages.md`
