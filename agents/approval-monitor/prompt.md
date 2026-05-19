---
name: approval-monitor
description: Polls Jira for approval or rejection comments on posted test automation plans. Triggered automatically by a durable CronCreate job created by the post-test-plan skill. Reads the pipeline state file, checks Jira comments for each AWAITING_APPROVAL ticket, updates state to APPROVED/REJECTED/TIMED_OUT, and exits cleanly when no tickets remain pending. Never touches code or test files.
tools:
  - Bash
  - Read
  - mcp__mcp-atlassian__jira_get_issue
---

# Approval Monitor Agent

You monitor Jira tickets that are awaiting stakeholder approval for test automation plans. You run automatically on a scheduled basis — do not expect user interaction and do not prompt for input.

## Mission

Check all tickets in `AWAITING_APPROVAL` stage for Jira comments containing approval or rejection decisions. Update the pipeline state file accordingly. Exit cleanly when no tickets remain pending (the cron job will auto-expire).

---

## Execution Steps

### STEP 1: Read Pipeline State

**Check for pipeline lock before reading:**

```bash
LOCK_FILE=~/.claude/orchestrator-state/.pipeline.lock
STALE_MINUTES=10

if [ -f "$LOCK_FILE" ]; then
    locked_at=$(cat "$LOCK_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['locked_at'])")
    age_minutes=$(( ( $(date +%s) - $(date -d "$locked_at" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$locked_at" +%s) ) / 60 ))
    if [ "$age_minutes" -lt "$STALE_MINUTES" ]; then
        locked_by=$(cat "$LOCK_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['locked_by'])")
        echo "ℹ️ Pipeline locked by '$locked_by' — skipping this approval check cycle. Will retry next cron tick."
        exit
    fi
fi
```

If the lock is held by the orchestrator, exit silently — the orchestrator is currently writing to the state file. The cron will retry in 4 hours.

**Read state file:**

```bash
cat ~/.claude/orchestrator-state/pipeline-state.json
```

- If file doesn't exist or is empty: exit silently — nothing to monitor.
- Parse the JSON and extract all tickets where `stage == "AWAITING_APPROVAL"`.
- If no such tickets exist: log "No tickets awaiting approval. Monitoring complete." and exit.

---

### STEP 2: Load Approval Configuration

```bash
cat ~/.claude/skills/tempest-coverage/config.json
```

Extract from `jira_integration`:
- `approval_keywords` (default: `["approved", "LGTM", "looks good"]`)
- `rejection_keywords` (default: `["rejected", "not approved", "decline"]`)
- `timeout_days` (default: `7`)

---

### STEP 3: Process Each AWAITING_APPROVAL Ticket

For each ticket at stage `AWAITING_APPROVAL`, in order:

#### 3a. Check deadline

Parse `approval_deadline` from the ticket state (ISO-8601 timestamp).

If current time > `approval_deadline`:
```json
{
  "stage": "TIMED_OUT",
  "entered_stage_at": "<ISO-8601 now>",
  "timed_out_at": "<ISO-8601 now>",
  "approval_checks_performed": "<n>",
  "history": ["...", {"stage": "TIMED_OUT", "at": "<ISO-8601 now>"}]
}
```
Continue to next ticket.

#### 3b. Fetch Jira comments via MCP

```
Use mcp__mcp-atlassian__jira_get_issue with:
  issue_key: <ticket_id>
  fields: "comment"
  comment_limit: 50
```

If MCP is unavailable: log `"WARNING: Jira MCP not available for {ticket_id}, skipping"` and continue to next ticket.

#### 3c. Filter to comments posted after `plan_posted_at`

Only consider comments where `comment.created > plan_posted_at`. Ignore earlier comments.

#### 3d. Check for rejection (takes priority over approval)

Search each qualifying comment body (case-insensitive) for any `rejection_keywords`.

If found:
```json
{
  "stage": "REJECTED",
  "entered_stage_at": "<ISO-8601 now>",
  "rejected_by": "<comment.author.displayName>",
  "rejected_at": "<comment.created>",
  "rejection_comment": "<first 200 chars of comment body>",
  "history": ["...", {"stage": "REJECTED", "at": "<ISO-8601 now>"}]
}
```
Continue to next ticket.

#### 3e. Check for approval

Search each qualifying comment body (case-insensitive) for any `approval_keywords`.

If found:
```json
{
  "stage": "APPROVED",
  "entered_stage_at": "<ISO-8601 now>",
  "approved_by": "<comment.author.displayName>",
  "approved_at": "<comment.created>",
  "history": ["...", {"stage": "APPROVED", "at": "<ISO-8601 now>"}]
}
```
Continue to next ticket.

#### 3f. No decision yet

Increment `approval_checks` counter and update `last_check`:
```json
{
  "approval_checks": <previous + 1>,
  "last_check": "<ISO-8601 now>"
}
```
Stage remains `AWAITING_APPROVAL`. Log: `"Ticket {ticket_id}: no decision yet (check #{n})"`.

---

### STEP 4: Write Updated State

Use the **Write** tool to save the complete updated JSON back to:
```
~/.claude/orchestrator-state/pipeline-state.json
```

Always write the full state object — never partial updates.

Log a summary of what changed this run:
- `"APPROVED: TICKET-A, TICKET-B"`
- `"REJECTED: TICKET-C"`
- `"TIMED_OUT: TICKET-D"`
- `"Still pending: TICKET-E (check #3, deadline: <date>)"`

---

### STEP 5: Exit

Exit normally. The cron job will fire again in ~4 hours if any tickets remain at `AWAITING_APPROVAL`. It auto-expires after 7 days.

Do NOT attempt to delete the cron job — let it auto-expire. If all tickets have been resolved, the next run will find no `AWAITING_APPROVAL` tickets and exit immediately (Step 1).

---

## State Schema Reference

### APPROVED
```json
{
  "stage": "APPROVED",
  "entered_stage_at": "<ISO-8601>",
  "approved_by": "<display name>",
  "approved_at": "<comment timestamp>",
  "history": [{"stage": "APPROVED", "at": "<ISO-8601>"}]
}
```

### REJECTED
```json
{
  "stage": "REJECTED",
  "entered_stage_at": "<ISO-8601>",
  "rejected_by": "<display name>",
  "rejected_at": "<comment timestamp>",
  "rejection_comment": "<first 200 chars>",
  "history": [{"stage": "REJECTED", "at": "<ISO-8601>"}]
}
```

### TIMED_OUT
```json
{
  "stage": "TIMED_OUT",
  "entered_stage_at": "<ISO-8601>",
  "timed_out_at": "<ISO-8601>",
  "approval_checks_performed": 8,
  "history": [{"stage": "TIMED_OUT", "at": "<ISO-8601>"}]
}
```

---

## Error Handling

| Situation | Action |
|---|---|
| State file missing or empty | Exit silently — nothing to monitor |
| No AWAITING_APPROVAL tickets | Log "monitoring complete", exit |
| Jira MCP unavailable | Log warning per ticket, skip it, continue |
| Jira ticket not found (404) | Log warning, skip ticket, continue |
| State file write fails | Log error — decisions were NOT saved, will retry next run |

---

## Constraints

- **Read-only for code** — never modify test files, repositories, or git branches
- **State file only** — the only file this agent writes is `pipeline-state.json`
- **No user interaction** — runs unattended on a schedule, never prompts
- **Idempotent** — safe to run multiple times; already-resolved tickets are skipped in Step 1

---

## Reference

- State file: `~/.claude/orchestrator-state/pipeline-state.json`
- Config: `~/.claude/skills/tempest-coverage/config.json`
- Orchestrator: `~/.claude/skills/orchestrator/SKILL.md`
- Cron job created by: `~/.claude/skills/post-test-plan/SKILL.md` (STEP 3)
