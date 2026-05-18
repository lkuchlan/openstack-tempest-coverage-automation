---
name: tempest-coverage-orchestrator
description: Orchestrate the Tempest coverage pipeline — discover tickets, analyze gaps, post plans, monitor approval
trigger: User wants to run the coverage pipeline, process tickets through stages, or check pipeline status
model: sonnet
---

# Tempest Coverage Orchestrator

You are a pipeline orchestrator for OpenStack Tempest test coverage automation. You manage tickets through a state machine: Discovery → Analysis → Post Plan → Approval Monitoring.

## Purpose

Tie together existing skills (`/jira-coverage-analysis`, `/post-test-plan`) into a reliable, resumable pipeline that advances tickets through stages one at a time.

**Invoke as:**
```
/tempest-coverage-orchestrator TICKET-ID [TICKET-ID...]
/tempest-coverage-orchestrator --jql "project = OSPRH AND labels = needs-tempest-coverage"
/tempest-coverage-orchestrator --status              # Show all tracked tickets
/tempest-coverage-orchestrator TICKET-ID --retry      # Retry from current stage
/tempest-coverage-orchestrator TICKET-ID --reset-to ANALYZED  # Force stage
/tempest-coverage-orchestrator --dry-run --jql "..."  # Preview without acting
```

---

## Execution Workflow

### STEP 0: Parse Input and Load State

**Actions:**

1. **Parse user input** to determine operating mode:
   - If `--status` flag: skip to STEP 5 (report only)
   - If `--jql` provided: will query Jira in Stage 1
   - If ticket IDs provided: use those directly
   - If `--dry-run`: set dry_run mode (report what would happen, take no actions)
   - If `--retry` on a ticket in ERROR state: clear the error, re-enter the stage it failed at
   - If `--reset-to STAGE` on a ticket: force the ticket to that stage (for manual recovery)

2. **Load pipeline state** from `~/.claude/orchestrator-state/pipeline-state.json`:
   ```bash
   cat ~/.claude/orchestrator-state/pipeline-state.json
   ```
   - If file is empty or malformed, initialize with: `{"version":1,"last_run":null,"tickets":{}}`
   - Parse the JSON to understand current state of all tracked tickets

3. **Load config** from this skill's `config.json` for approval settings, JQL defaults, etc.

**Output:**
- List of ticket IDs to process
- Current state for each ticket (or null if new)
- Operating mode (normal, dry-run, status-only)

---

### STEP 1: Discovery — Identify Tickets

**Actions:**

**If ticket IDs provided directly:**
- Use those ticket IDs
- For any ticket not yet in state file, create entry with stage `DISCOVERED`

**If --jql provided (or using default JQL from config):**
1. Query Jira via MCP:
   ```
   Use mcp__mcp-atlassian__search_issues with JQL query
   ```
2. Extract ticket IDs from results
3. Filter out tickets already at terminal stages (APPROVED, REJECTED, TIMED_OUT) unless `--retry`
4. For new tickets, create state entries with stage `DISCOVERED`
5. Respect `max_tickets_per_run` limit from config

**Checkpoint:** Write state to disk after discovery:
```bash
# Write updated state to pipeline-state.json
```

**Output:**
- List of ticket IDs to process through remaining stages
- How many are new vs. resuming

---

### STEP 2: Process Each Ticket Through Stages

For each ticket, determine its current stage and advance to the next eligible stage. Process tickets **sequentially** (one at a time).

**IMPORTANT:** Only advance ONE stage per ticket per orchestrator run. This ensures:
- Each stage's output can be reviewed before proceeding
- State is checkpointed reliably
- Errors are caught early

#### Stage Handler: DISCOVERED → ANALYZED

**Condition:** Ticket is at stage `DISCOVERED`

**Actions:**
1. Invoke the coverage analysis skill:
   ```
   Use Skill tool to invoke: jira-coverage-analysis
   Pass the ticket ID as argument
   ```
2. Wait for analysis to complete
3. Capture the analysis output — look for:
   - Number of coverage gaps identified
   - Priority breakdown (HIGH/MEDIUM/LOW)
   - Service name (cinder, manila, glance, etc.)
   - Plugin name (cinder-tempest-plugin, etc.)
   - Effort estimate
4. Update ticket state:
   ```json
   {
     "stage": "ANALYZED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "service": "<detected service>",
     "plugin": "<detected plugin>",
     "analysis_summary": "<brief summary of gaps found>",
     "history": [..., {"stage": "ANALYZED", "at": "<timestamp>"}]
   }
   ```
5. **Checkpoint:** Write state to disk immediately

**If analysis fails:**
- Set stage to `ERROR` with error details
- Continue to next ticket

---

#### Stage Handler: ANALYZED → AWAITING_APPROVAL

**Condition:** Ticket is at stage `ANALYZED`

**Actions:**
1. Invoke the test plan posting skill:
   ```
   Use Skill tool to invoke: post-test-plan
   Pass the ticket ID as argument
   ```
2. Wait for plan posting to complete
3. Record the current timestamp as `plan_posted_at`
4. Calculate `approval_deadline` = now + `config.approval.timeout_days` days
5. Update ticket state:
   ```json
   {
     "stage": "AWAITING_APPROVAL",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "plan_posted_at": "<current ISO-8601 timestamp>",
     "approval_deadline": "<deadline ISO-8601 timestamp>",
     "approval_checks": 0,
     "last_check": null,
     "history": [..., {"stage": "PLAN_POSTED", "at": "<timestamp>"}, {"stage": "AWAITING_APPROVAL", "at": "<timestamp>"}]
   }
   ```
6. **Checkpoint:** Write state to disk immediately

**If posting fails:**
- Set stage to `ERROR` with error details
- Continue to next ticket

---

#### Stage Handler: AWAITING_APPROVAL → APPROVED / REJECTED / TIMED_OUT

**Condition:** Ticket is at stage `AWAITING_APPROVAL`

**Actions:**
1. **Check deadline first:**
   - Parse `approval_deadline` from state
   - If current time > deadline:
     - Set stage to `TIMED_OUT`
     - Checkpoint and continue to next ticket

2. **Fetch Jira ticket comments via MCP:**
   ```
   Use mcp__mcp-atlassian__get_issue with issue_key=TICKET-ID
   Request the comments field
   ```

3. **Filter comments:**
   - Only consider comments posted AFTER `plan_posted_at`
   - Ignore comments by automation/bot users (if identifiable)

4. **Check for rejection keywords:**
   - Search each comment body (case-insensitive) for: `rejected`, `not approved`, `decline`
   - If found:
     - Record rejector and timestamp
     - Set stage to `REJECTED`
     - Checkpoint and continue

5. **Check for approval keywords:**
   - Search each comment body (case-insensitive) for: `approved`, `LGTM`, `looks good`
   - If found:
     - Record approver and timestamp
     - Set stage to `APPROVED`
     - Checkpoint and continue

6. **No decision yet:**
   - Increment `approval_checks` counter
   - Update `last_check` to current timestamp
   - Stage stays at `AWAITING_APPROVAL`
   - Checkpoint and continue

**State update on approval:**
```json
{
  "stage": "APPROVED",
  "entered_stage_at": "<current ISO-8601 timestamp>",
  "approved_by": "<comment author>",
  "approved_at": "<comment timestamp>",
  "history": [..., {"stage": "APPROVED", "at": "<timestamp>"}]
}
```

---

#### Stage Handler: APPROVED → IMPLEMENTING

**Condition:** Ticket is at stage `APPROVED`

**Actions:**
1. Invoke the test implementation skill:
   ```
   Use Skill tool to invoke: implement-tempest-tests
   Pass the ticket ID as argument
   ```
2. Wait for implementation to complete
3. Capture implementation output — extract:
   - Test file paths (absolute and relative)
   - Branch name (e.g., `tempest-coverage-TICKET-ID`)
   - Test module path (e.g., `cinder_tempest_plugin.tests.api.test_feature`)
   - Service name
   - Test method names
4. Update ticket state:
   ```json
   {
     "stage": "IMPLEMENTING",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "implementation_details": {
       "test_files": ["path/to/test_file.py"],
       "branch": "tempest-coverage-TICKET-ID",
       "test_module": "plugin.tests.api.test_feature",
       "service": "cinder",
       "test_methods": ["test_method_1", "test_method_2"]
     },
     "history": [..., {"stage": "IMPLEMENTING", "at": "<timestamp>"}]
   }
   ```
5. **Checkpoint:** Write state to disk immediately

**If implementation fails:**
- Set stage to `ERROR` with `stage_when_failed: "APPROVED"` and error details
- Continue to next ticket

---

#### Stage Handler: IMPLEMENTING → VERIFYING

**Condition:** Ticket is at stage `IMPLEMENTING`

**Actions:**
1. Read implementation details from ticket state (`implementation_details` field)
2. Invoke the DevStack verification skill:
   ```
   Use Skill tool to invoke: verify-tempest-devstack
   Pass arguments: TICKET-ID --service {service} --test-module {test_module}
   ```
3. Wait for verification to complete (this takes 30-90 minutes due to DevStack deployment)
4. Parse verification result — look for:
   - `verification_status`: `PASSED` or `FAILED`
   - Test results (pass/fail counts)
   - Feedback JSON (if failed)
5. Update ticket state:
   ```json
   {
     "stage": "VERIFYING",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "verification_attempt": 1,
     "verification_result": {
       "status": "PASSED|FAILED",
       "tests_passed": 3,
       "tests_total": 3,
       "feedback": null
     },
     "history": [..., {"stage": "VERIFYING", "at": "<timestamp>"}]
   }
   ```
6. **Checkpoint:** Write state to disk immediately
7. **Determine next stage immediately** (do NOT wait for next orchestrator run):
   - If `verification_status == "PASSED"`: transition to `VERIFIED`
   - If `verification_status == "DEFERRED"`: the VM is locked by another ticket. Keep the ticket at `IMPLEMENTING` stage — do NOT advance, do NOT error. The next orchestrator run will retry automatically.
   - If `verification_status == "DEPLOYMENT_FAILED"`: transition to `ERROR` with `error_type: "deployment_failure"` — do NOT trigger fix+retry loop (this is an infrastructure issue, not a test code issue). Post Jira comment with deployment error details.
   - If `verification_status == "SKIPPED"`: transition to `VERIFICATION_SKIPPED` — the environment cannot be deployed on DevStack (e.g., requires Ceph, multi-node, SR-IOV). Post Jira comment explaining what manual verification is needed.
   - If `verification_status == "FAILED"` AND `verification_attempt < config.verification.max_retry_cycles + 1`: transition to `FIX_IN_PROGRESS`
   - If `verification_status == "FAILED"` AND retries exhausted: transition to `VERIFICATION_FAILED`

**If verification skill fails (crash, SSH error, etc.):**
- Set stage to `ERROR` with `stage_when_failed: "IMPLEMENTING"` and error details
- Continue to next ticket

---

#### Stage Handler: VERIFYING → VERIFIED

**Condition:** Ticket is at stage `VERIFYING` with `verification_result.status == "PASSED"`

**Actions:**
1. Update ticket state:
   ```json
   {
     "stage": "VERIFIED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "verified_at": "<current ISO-8601 timestamp>",
     "verification_summary": "{tests_passed}/{tests_total} tests passed on DevStack",
     "history": [..., {"stage": "VERIFIED", "at": "<timestamp>"}]
   }
   ```
2. **Update Jira** (if MCP available):
   - Post a comment with verification results:
     ```
     Use mcp__mcp-atlassian__add_comment
     Body: "✅ Tests verified on DevStack. {pass_count}/{total_count} tests passing.
     Branch: {branch_name}
     Ready for Gerrit submission: git review"
     ```
   - Add label: `automation-verified`
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: VERIFYING → FIX_IN_PROGRESS

**Condition:** Ticket is at stage `VERIFYING` with `verification_result.status == "FAILED"` AND `verification_attempt == 1`

**Actions:**
1. Extract structured feedback from verification result (`verification_result.feedback`)
2. Update ticket state:
   ```json
   {
     "stage": "FIX_IN_PROGRESS",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "fix_context": {
       "failed_tests": [...],
       "suggested_fixes": [...],
       "environment_info": {...}
     },
     "history": [..., {"stage": "FIX_IN_PROGRESS", "at": "<timestamp>"}]
   }
   ```
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: FIX_IN_PROGRESS → VERIFYING (Retry Cycle)

**Condition:** Ticket is at stage `FIX_IN_PROGRESS`

**Actions:**
1. Read fix context from ticket state (`fix_context` field)
2. Re-invoke the implementation skill with fix instructions:
   ```
   Use Skill tool to invoke: implement-tempest-tests
   Pass arguments: TICKET-ID --fix-context '{fix_context_json}'
   ```
   The fix context tells the implementation skill exactly what failed and what to fix.
3. Wait for re-implementation to complete
4. Re-invoke the verification skill with `--skip-deploy` (reuse existing DevStack):
   ```
   Use Skill tool to invoke: verify-tempest-devstack
   Pass arguments: TICKET-ID --service {service} --test-module {test_module} --skip-deploy --retry-context '{feedback_json}'
   ```
5. Parse re-verification result
6. Update ticket state:
   ```json
   {
     "stage": "VERIFYING",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "verification_attempt": 2,
     "verification_result": {
       "status": "PASSED|FAILED",
       "tests_passed": ...,
       "tests_total": ...,
       "feedback": ...
     },
     "history": [..., {"stage": "VERIFYING", "at": "<timestamp>", "attempt": 2}]
   }
   ```
7. **Checkpoint:** Write state to disk immediately
8. **Determine next stage immediately:**
   - If `verification_status == "PASSED"`: transition to `VERIFIED`
   - If `verification_status == "FAILED"`: transition to `VERIFICATION_FAILED` (max retries exhausted)

**If re-implementation or re-verification fails:**
- Set stage to `ERROR` with `stage_when_failed: "FIX_IN_PROGRESS"` and error details
- Continue to next ticket

---

#### Stage Handler: VERIFYING → VERIFICATION_FAILED

**Condition:** Ticket is at stage `VERIFYING` with `verification_result.status == "FAILED"` AND `verification_attempt >= config.verification.max_retry_cycles + 1`

**Actions:**
1. Update ticket state:
   ```json
   {
     "stage": "VERIFICATION_FAILED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "failure_summary": "{failed_count} tests failed after {attempt_count} attempt(s)",
     "final_feedback": {...},
     "history": [..., {"stage": "VERIFICATION_FAILED", "at": "<timestamp>"}]
   }
   ```
2. **Update Jira** (if MCP available):
   - Post a comment with failure details:
     ```
     Use mcp__mcp-atlassian__add_comment
     Body: "❌ Verification failed after {retry_count} retry(s).
     Failed tests: {failed_test_list}
     Branch: {branch_name}
     Manual investigation required."
     ```
   - Add label: `automation-verification-failed`
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: VERIFYING → VERIFICATION_SKIPPED

**Condition:** Ticket is at stage `VERIFYING` with `verification_result.status == "SKIPPED"`

**Actions:**
1. Update ticket state:
   ```json
   {
     "stage": "VERIFICATION_SKIPPED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "skip_reason": "{reason from verification result}",
     "unsupported_requirements": ["ceph backend", "multi-node"],
     "history": [..., {"stage": "VERIFICATION_SKIPPED", "at": "<timestamp>"}]
   }
   ```
2. **Update Jira** (if MCP available):
   - Post a comment:
     ```
     Use mcp__mcp-atlassian__add_comment
     Body: "⚠️ Automated verification skipped — DevStack cannot provide the required environment.
     Reason: {skip_reason}
     Unsupported requirements: {requirements_list}
     
     Tests were implemented on branch {branch_name} but need manual verification on a deployment with {requirements}.
     "
     ```
   - Add label: `automation-manual-verification-needed`
3. **Checkpoint:** Write state to disk immediately

**Note:** This is NOT a failure — the tests may be correct. They just need a real deployment (not DevStack) to verify.

---

#### Terminal Stages: VERIFIED / VERIFICATION_FAILED / VERIFICATION_SKIPPED / REJECTED / TIMED_OUT / ERROR

**Condition:** Ticket is at any terminal stage

**Actions:**
- Report current status for this ticket
- No further action taken
- If `--retry` flag was passed and stage is ERROR:
  - Read `error.stage_when_failed` from state
  - Reset stage to that value
  - Clear error field
  - Re-process through the appropriate stage handler above
- If `--retry` flag was passed and stage is VERIFICATION_FAILED:
  - Reset stage to `IMPLEMENTING`
  - Clear failure fields
  - Re-process through implementation and verification

---

### STEP 3: Write Final State

After all tickets are processed:

1. Update `last_run` timestamp in pipeline state
2. Write complete state to `~/.claude/orchestrator-state/pipeline-state.json`:
   ```bash
   # Use Write tool to save the updated JSON state
   ```
3. Also write per-ticket state files for easy inspection:
   ```bash
   # For each ticket, write to ~/.claude/orchestrator-state/tickets/TICKET-ID.json
   ```

---

### STEP 4: Log Run

Write a log entry for this run:

```bash
# Append to ~/.claude/orchestrator-state/logs/YYYY-MM-DD.log
```

Log format per ticket:
```
[2026-05-07T08:17:00Z] OSPRH-22613: DISCOVERED → ANALYZED (3 gaps found, 2 HIGH)
[2026-05-07T08:17:00Z] OSPRH-22614: AWAITING_APPROVAL → AWAITING_APPROVAL (check #3, no decision)
[2026-05-07T08:17:00Z] OSPRH-22615: AWAITING_APPROVAL → APPROVED (approved by jsmith)
[2026-05-07T08:17:00Z] OSPRH-22616: APPROVED → IMPLEMENTING (3 tests implemented)
[2026-05-07T08:17:00Z] OSPRH-22617: IMPLEMENTING → VERIFIED (3/3 tests passed on DevStack)
[2026-05-07T08:17:00Z] OSPRH-22618: VERIFYING → FIX_IN_PROGRESS (1 test failed, retrying)
[2026-05-07T08:17:00Z] OSPRH-22619: FIX_IN_PROGRESS → VERIFICATION_FAILED (retry exhausted)
[2026-05-07T08:17:00Z] OSPRH-22620: VERIFYING → VERIFICATION_SKIPPED (requires multi-node)
[2026-05-07T08:17:00Z] OSPRH-22621: IMPLEMENTING → IMPLEMENTING (deferred, VM locked by OSPRH-22617)
```

---

### STEP 5: Report Summary

**ALWAYS** end with a clear summary table. This is critical for trust.

**Format:**

```
╔══════════════════════════════════════════════════════════════╗
║              ORCHESTRATOR RUN SUMMARY                       ║
╠══════════════════════════════════════════════════════════════╣
║ Run time:     2026-05-07T08:17:00Z                          ║
║ Mode:         normal / dry-run                               ║
║ Tickets:      8 processed                                    ║
╠══════════════════════════════════════════════════════════════╣
║ Ticket         │ Previous Stage       │ Current Stage        ║
╠────────────────┼──────────────────────┼──────────────────────╣
║ OSPRH-22613    │ DISCOVERED           │ ANALYZED             ║
║ OSPRH-22614    │ APPROVED             │ IMPLEMENTING         ║
║ OSPRH-22615    │ AWAITING_APPROVAL    │ AWAITING_APPROVAL    ║
║ OSPRH-22616    │ IMPLEMENTING         │ VERIFIED             ║
║ OSPRH-22617    │ VERIFYING            │ FIX_IN_PROGRESS      ║
║ OSPRH-22618    │ DISCOVERED           │ ERROR                ║
║ OSPRH-22619    │ VERIFYING            │ VERIFICATION_SKIPPED ║
║ OSPRH-22620    │ IMPLEMENTING         │ IMPLEMENTING         ║
╠══════════════════════════════════════════════════════════════╣
║ Next actions:                                                ║
║ - OSPRH-22613: Run again to post test plan                   ║
║ - OSPRH-22614: Run again to verify on DevStack               ║
║ - OSPRH-22615: Waiting for approval (check #4, 3 days left)  ║
║ - OSPRH-22616: Tests verified! Ready for git review          ║
║ - OSPRH-22617: Fixing tests, will re-verify (attempt 2/2)    ║
║ - OSPRH-22618: ERROR - Jira fetch failed. Use --retry        ║
║ - OSPRH-22619: Manual verification needed (requires Ceph)    ║
║ - OSPRH-22620: Deferred - VM locked, will retry next run     ║
╚══════════════════════════════════════════════════════════════╝
```

**For --status mode:** Show the summary table for ALL tracked tickets without processing.

**For --dry-run mode:** Show what stages WOULD advance, but take no actions. Prefix each line with `[DRY-RUN]`.

---

## State File Management

### Reading State
```bash
cat ~/.claude/orchestrator-state/pipeline-state.json
```
Parse the JSON. If the file doesn't exist or is empty, initialize with default state.

### Writing State (Checkpoint)
Use the **Write** tool to write the entire updated JSON state back to `~/.claude/orchestrator-state/pipeline-state.json`. Always write the complete state, not partial updates.

**CRITICAL:** Write state to disk AFTER EVERY stage transition, not just at the end. This ensures crash recovery — if the orchestrator is interrupted, the last completed stage is preserved.

### Per-Ticket State Files
After processing, also write individual ticket state to `~/.claude/orchestrator-state/tickets/TICKET-ID.json`. These are for human inspection and debugging — the master state file is the source of truth.

---

## Error Handling

1. **Jira MCP unavailable:** Report error, suggest checking MCP configuration. Do NOT crash — mark affected tickets as ERROR and continue.
2. **Skill invocation fails:** Capture error message, set ticket to ERROR with `stage_when_failed` field for retry support.
3. **State file corruption:** If JSON parse fails, report the error and suggest manual inspection. Do NOT overwrite with empty state.
4. **Duplicate detection:** The `/post-test-plan` skill handles duplicate comment detection internally. Trust its output.

---

## Idempotency Guarantees

- **Re-running on DISCOVERED:** Analysis runs again, overwrites previous result. Safe.
- **Re-running on ANALYZED:** `/post-test-plan` has built-in duplicate detection. Safe.
- **Re-running on AWAITING_APPROVAL:** Comment check is read-only. Safe.
- **Re-running on APPROVED:** Re-runs implementation. Creates new branch. Safe.
- **Re-running on IMPLEMENTING:** Re-runs verification. Redeploys DevStack (30-60 min). Safe but slow.
- **Re-running on FIX_IN_PROGRESS:** Re-runs fix cycle. Safe.
- **Re-running on VERIFYING:** Re-evaluates verification result. Safe.
- **Re-running on VERIFICATION_SKIPPED:** No action unless `--retry`. Safe.
- **Re-running on terminal stages:** No action taken unless `--retry`. Safe.

---

## Configuration Reference

Read `config.json` (adjacent to this SKILL.md) for:
- `state_directory` — where state files live
- `jql_filter` — default JQL for ticket discovery
- `approval.timeout_days` — days before TIMED_OUT (default: 7)
- `approval.approval_keywords` — comment keywords that mean "approved"
- `approval.rejection_keywords` — comment keywords that mean "rejected"
- `verification.max_retry_cycles` — max fix+re-verify cycles (default: 1)
- `verification.update_jira_on_verified` — post success comment to Jira (default: true)
- `verification.update_jira_on_failed` — post failure comment to Jira (default: true)
- `max_tickets_per_run` — limit tickets processed per invocation (default: 5)
- `dry_run` — if true, report only (overridden by `--dry-run` flag)
