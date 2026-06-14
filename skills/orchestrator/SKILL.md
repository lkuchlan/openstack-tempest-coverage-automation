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
/tempest-coverage-orchestrator --jql "project = OSPRH AND labels = agentic-tempest-coverage"
/tempest-coverage-orchestrator --status              # Show all tracked tickets
/tempest-coverage-orchestrator TICKET-ID --retry      # Retry from current stage
/tempest-coverage-orchestrator TICKET-ID --reset-to ANALYZED  # Force stage
/tempest-coverage-orchestrator --dry-run --jql "..."  # Preview without acting
/tempest-coverage-orchestrator TICKET-ID --submitted <gerrit_url>  # Mark as submitted after git review
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
   - If `--submitted <gerrit_url>`: run the VERIFIED → SUBMITTED handler for that ticket (skip all other stages)
   - If `--force` is also present alongside `--submitted`: set `force_submit = true` (skips repo verification; use only when the repo name is non-standard but correct)

2. **Acquire pipeline lock** (skip if `--status` or `--dry-run`):

   ```bash
   LOCK_FILE=~/.claude/orchestrator-state/.pipeline.lock
   STALE_MINUTES=10

   if [ -f "$LOCK_FILE" ]; then
       locked_at=$(cat "$LOCK_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['locked_at'])")
       age_minutes=$(( ( $(date +%s) - $(date -d "$locked_at" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%SZ" "$locked_at" +%s) ) / 60 ))
       if [ "$age_minutes" -lt "$STALE_MINUTES" ]; then
           locked_by=$(cat "$LOCK_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['locked_by'])")
           echo "⚠️ Pipeline is locked by '$locked_by' (started ${age_minutes}m ago). Exiting to avoid state corruption."
           echo "If this is stale, delete: $LOCK_FILE"
           exit
       fi
       echo "ℹ️ Stale lock found (${age_minutes}m old) — overwriting"
   fi

   # Write lock
   echo "{\"locked_by\": \"orchestrator\", \"locked_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$LOCK_FILE"
   ```

   **CRITICAL:** Always release the lock at the end of the run (STEP 4) or on any early exit:
   ```bash
   rm -f ~/.claude/orchestrator-state/.pipeline.lock
   ```

3. **Load pipeline state** from `~/.claude/orchestrator-state/pipeline-state.json`:
   ```bash
   cat ~/.claude/orchestrator-state/pipeline-state.json
   ```
   - If file is empty or malformed, initialize with: `{"version":1,"last_run":null,"tickets":{}}`
   - Parse the JSON to understand current state of all tracked tickets

3. **Check for incomplete parallel batch (crash recovery):**
   
   If `state.parallel_execution_batch` is not null:
   - A previous orchestrator run crashed mid-batch
   - Extract batch details: `batch_id`, `started_at`, `stage`, `in_progress` tickets
   - Calculate time elapsed: `now - started_at`
   - If elapsed > `config.parallel_execution.batch_timeout_minutes`:
     - **Batch timed out** - mark all `in_progress` tickets as ERROR:
       ```json
       {
         "stage": "ERROR",
         "error": {
           "message": "Parallel batch timeout after crash/restart",
           "batch_id": "{batch_id}",
           "stage_when_failed": "{original_stage}",
           "timeout_minutes": 30
         }
       }
       ```
     - Clear batch record: `state.parallel_execution_batch = null`
     - Write state to disk
   - Otherwise:
     - **Batch still within timeout** - keep tickets at current stage, will retry
     - Clear batch record: `state.parallel_execution_batch = null`
     - Write state to disk

4. **Load config** from this skill's `config.json` for approval settings, JQL defaults, etc.

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

### STEP 1.5: Batch Tickets by Stage

**Actions:**

1. **Group tickets by current stage:**
   - Iterate through all tickets from STEP 1
   - Create a map: `stage → [ticket_id, ticket_id, ...]`
   - Example: `{"DISCOVERED": ["TICKET-1", "TICKET-2"], "APPROVED": ["TICKET-3", "TICKET-4", "TICKET-5"]}`

2. **Determine execution mode for each stage:**
   
   For each stage group:
   
   **Check if stage is parallelizable:**
   - If stage in `config.parallel_execution.parallelizable_stages` (DISCOVERED, ANALYZED, APPROVED, IMPLEMENTING)
   - AND `config.parallel_execution.enabled == true`
   - AND ticket count >= `config.parallel_execution.min_tickets_for_parallel`
   - → Set execution mode to **PARALLEL**
   
   **Otherwise:**
   - Set execution mode to **SEQUENTIAL**
   - This applies to:
     - DevStack stages (CODE_REVIEW, VERIFYING) — VM lock prevents parallel execution
     - Small batches (< min_tickets_for_parallel)
     - Parallel execution disabled in config

3. **Output batches:**
   - Group tickets by (stage, execution_mode)
   - Example:
     ```
     - Batch 1: DISCOVERED (2 tickets, PARALLEL)
     - Batch 2: APPROVED (5 tickets, PARALLEL)
     - Batch 3: CODE_REVIEW (1 ticket, SEQUENTIAL)
     - Batch 4: VERIFYING (1 ticket, SEQUENTIAL)
     ```

**Tool Usage:**
- Dictionary/map operations
- Config lookups

**Output:**
- List of batches with execution mode
- Each batch: {stage, tickets, execution_mode}

---

### STEP 2: Process Each Batch Through Stages

For each batch from STEP 1.5, process tickets based on execution mode:
- **PARALLEL:** Spawn multiple skill/agent invocations concurrently (I/O-bound stages)
- **SEQUENTIAL:** Process tickets one at a time (DevStack stages with VM lock)

**IMPORTANT:** Only advance ONE stage per ticket per orchestrator run. This ensures:
- Each stage's output can be reviewed before proceeding
- State is checkpointed reliably
- Errors are caught early

---

#### Execution Mode: PARALLEL

**Condition:** Batch has `execution_mode == "PARALLEL"` (stages: DISCOVERED, ANALYZED, APPROVED, IMPLEMENTING)

**Actions:**

1. **Create parallel execution batch record:**
   ```json
   {
     "parallel_execution_batch": {
       "batch_id": "batch-{ISO-8601-timestamp}",
       "stage": "{CURRENT_STAGE} → {NEXT_STAGE}",
       "started_at": "{ISO-8601 timestamp}",
       "tickets_in_batch": ["TICKET-1", "TICKET-2", ...],
       "completed": [],
       "failed": [],
       "in_progress": ["TICKET-1", "TICKET-2", ...]
     }
   }
   ```
   Write to state immediately (recovery marker)

2. **Spawn parallel skill/agent invocations** (one per ticket, up to `max_parallel_agents`):
   
   For each ticket in batch:
   - Invoke appropriate stage handler (see stage handlers below)
   - Run all invocations concurrently using multiple tool calls in one message
   - Each skill/agent returns structured output
   
   **Wait for all to complete** (blocking, with timeout = `config.parallel_execution.batch_timeout_minutes`)

3. **Collect structured outputs:**
   - Parse each ticket's result
   - Track: completed successfully, failed with error, deferred (VM locked)

4. **Update state for each ticket:**
   - For successful tickets: advance to next stage, update fields
   - For failed tickets: set stage to ERROR with details
   - For deferred tickets: keep at current stage (retry next run)
   - Update batch record: move tickets from `in_progress` to `completed` or `failed`

5. **Clear batch record and checkpoint:**
   ```json
   {
     "parallel_execution_batch": null
   }
   ```
   Write full state to disk

6. **Handle batch timeout:**
   - If batch doesn't complete within `batch_timeout_minutes`:
     - Mark all `in_progress` tickets as ERROR
     - Error message: "Parallel batch timeout after {timeout} minutes"
     - Clear batch record
     - Checkpoint state
     - Continue to next batch

**Tool Usage:**
- Skill tool (for skill-based stages)
- Agent tool (for agent-based stages)
- Multiple tool calls in one message (parallel execution)
- State file writes (checkpointing)

---

#### Execution Mode: SEQUENTIAL

**Condition:** Batch has `execution_mode == "SEQUENTIAL"` (DevStack stages, small batches, or parallel disabled)

**Actions:**

1. **Process tickets one at a time:**
   - For each ticket in batch:
     - Invoke appropriate stage handler (see stage handlers below)
     - Wait for completion
     - Update ticket state
     - Checkpoint state to disk
     - Continue to next ticket

2. **No batch record needed:**
   - Sequential execution doesn't need crash recovery batch tracking
   - Each ticket checkpointed individually

**Tool Usage:**
- Skill tool (for skill-based stages)
- Agent tool (for agent-based stages)
- One tool call at a time (sequential execution)
- State file writes after each ticket

---

#### Stage Handlers

Below are the stage-specific handlers referenced by both PARALLEL and SEQUENTIAL execution modes. Each handler defines the transition logic for advancing a ticket from one stage to the next.

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

#### Stage Handler: AWAITING_APPROVAL (delegated to approval-monitor)

**Condition:** Ticket is at stage `AWAITING_APPROVAL`

**Actions:**

**Skip this ticket.** The `approval-monitor` agent owns this stage and runs independently on a durable 4-hour cron schedule created by the `post-test-plan` skill.

When the approval-monitor detects a decision (approved, rejected, or timed out), it updates the state file directly. The next orchestrator run will see the ticket at its new stage (`APPROVED`, `REJECTED`, or `TIMED_OUT`) and process it accordingly.

```
# Orchestrator action for AWAITING_APPROVAL tickets:
Log: "Ticket {ticket_id}: AWAITING_APPROVAL — monitored by approval-monitor agent (check #{n}, last checked: {last_check})"
No further action. Continue to next ticket.
```

**If approval monitoring was NOT scheduled** (e.g., plan was posted manually without the skill, or cron creation failed):
- Inform the user in the summary: "⚠️ {ticket_id} is awaiting approval but no automatic monitoring is active. Use `/post-test-plan {ticket_id}` to re-post and activate monitoring, or manually advance with `--reset-to APPROVED` once approved."

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

#### Stage Handler: IMPLEMENTING → CODE_REVIEW

**Condition:** Ticket is at stage `IMPLEMENTING` (implementation complete)

**Actions:**
1. Read implementation details from ticket state (`implementation_details` field)
2. Invoke the code review agent:
   ```
   Use Agent tool with:
   subagent_type: code-reviewer
   description: Review Tempest tests for {TICKET-ID}
   prompt: """
   Review Tempest tests for {TICKET-ID}.
   
   Repository: {implementation_details.repository_path}
   Branch: {implementation_details.branch}
   Service: {implementation_details.service}
   
   Validate against TEMPEST_STANDARDS.md:
   1. Base class usage (no unittest.TestCase)
   2. Client usage (no raw HTTP - requests, urllib)
   3. Waiter usage (no time.sleep)
   4. Cleanup patterns (addCleanup required)
   5. Required decorators (@idempotent_id, @attr)
   6. Test independence (no shared state)
   7. Naming conventions
   
   Return structured JSON with violations and suggested fixes.
   """
   ```
3. Wait for agent to complete
4. Parse agent result — look for:
   - `review_status`: `PASSED` or `FAILED`
   - Violation count and severity
   - Feedback JSON (if failed)
4. Update ticket state:
   ```json
   {
     "stage": "CODE_REVIEW",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "code_review_attempt": 1,
     "code_review_result": {
       "status": "PASSED|FAILED",
       "violations": 0,
       "reviewed_files": [...]
     },
     "history": [..., {"stage": "CODE_REVIEW", "at": "<timestamp>"}]
   }
   ```
5. **Checkpoint:** Write state to disk immediately
6. **Determine next stage immediately:**
   - If `review_status == "PASSED"`: transition to `VERIFYING`
   - If `review_status == "FAILED"` AND `code_review_attempt < config.code_review.max_retry_cycles`: transition to `FIX_IN_PROGRESS` with `fix_context.source = "code_review"`
   - If `review_status == "FAILED"` AND retries exhausted: transition to `CODE_REVIEW_FAILED`

**If code review skill fails (crash, etc.):**
- Set stage to `ERROR` with `stage_when_failed: "IMPLEMENTING"` and error details
- Continue to next ticket

---

#### Stage Handler: CODE_REVIEW → VERIFYING

**Condition:** Ticket is at stage `CODE_REVIEW` with `code_review_result.status == "PASSED"`

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
   - If `verification_status == "DEFERRED"`: the VM is locked by another ticket. Keep the ticket at `CODE_REVIEW` stage — do NOT advance, do NOT error. The next orchestrator run will retry automatically.
   - If `verification_status == "DEPLOYMENT_FAILED"`: transition to `ERROR` with `error_type: "deployment_failure"` — do NOT trigger fix+retry loop (this is an infrastructure issue, not a test code issue). Post Jira comment with deployment error details.
   - If `verification_status == "SKIPPED"`: transition to `VERIFICATION_SKIPPED` — the environment cannot be deployed on DevStack (e.g., requires Ceph, multi-node, SR-IOV). Post Jira comment explaining what manual verification is needed.
   - If `verification_status == "FAILED"` AND `verification_attempt < config.verification.max_retry_cycles + 1`: transition to `FIX_IN_PROGRESS` with `fix_context.source = "devstack_verification"`
   - If `verification_status == "FAILED"` AND retries exhausted: transition to `VERIFICATION_FAILED`

**If verification skill fails (crash, SSH error, etc.):**
- Set stage to `ERROR` with `stage_when_failed: "CODE_REVIEW"` and error details
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
   - Post a comment using the `verified_jira_comment` template from `config.json`:
     ```
     Use mcp__mcp-atlassian__add_comment
     Body: config.verification.verified_jira_comment
           Substitute: {pass_count}, {total_count}, {devstack_host}, {backend_info}
           {test_results_table} = Markdown table with columns: Test | Status | Duration
     ```
   - Add label: `automation-verified`
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: CODE_REVIEW → FIX_IN_PROGRESS

**Condition:** Ticket is at stage `CODE_REVIEW` with `code_review_result.status == "FAILED"` AND `code_review_attempt < config.code_review.max_retry_cycles`

**Actions:**
1. Extract violations from code review result (`code_review_result.violations`)
2. Update ticket state:
   ```json
   {
     "stage": "FIX_IN_PROGRESS",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "fix_context": {
       "source": "code_review",
       "violations": [...],
       "suggested_fixes": [...],
       "reviewed_files": [...]
     },
     "history": [..., {"stage": "FIX_IN_PROGRESS", "at": "<timestamp>"}]
   }
   ```
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: CODE_REVIEW → CODE_REVIEW_FAILED

**Condition:** Ticket is at stage `CODE_REVIEW` with `code_review_result.status == "FAILED"` AND `code_review_attempt >= config.code_review.max_retry_cycles`

**Actions:**
1. Update ticket state:
   ```json
   {
     "stage": "CODE_REVIEW_FAILED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "failure_summary": "{violation_count} violations after {attempt_count} attempt(s)",
     "final_violations": [...],
     "history": [..., {"stage": "CODE_REVIEW_FAILED", "at": "<timestamp>"}]
   }
   ```
2. **Checkpoint:** Write state to disk immediately

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
       "source": "devstack_verification",
       "failed_tests": [...],
       "suggested_fixes": [...],
       "environment_info": {...}
     },
     "history": [..., {"stage": "FIX_IN_PROGRESS", "at": "<timestamp>"}]
   }
   ```
3. **Checkpoint:** Write state to disk immediately

---

#### Stage Handler: FIX_IN_PROGRESS → CODE_REVIEW (Retry Cycle - Code Review)

**Condition:** Ticket is at stage `FIX_IN_PROGRESS` with `fix_context.source == "code_review"`

**Actions:**
1. Read fix context from ticket state (`fix_context` field)
2. Re-invoke the implementation skill with fix instructions:
   ```
   Use Skill tool to invoke: implement-tempest-tests
   Pass arguments: TICKET-ID --fix-context '{fix_context_json}'
   ```
   The fix context tells the implementation skill to fix Tempest standard violations.
3. Wait for re-implementation to complete
4. Re-invoke the code review agent:
   ```
   Use Agent tool with:
   subagent_type: code-reviewer
   description: Re-review Tempest tests for {TICKET-ID} after fixes
   prompt: """
   Re-review Tempest tests for {TICKET-ID} after fixing violations.
   
   Repository: {implementation_details.repository_path}
   Branch: {implementation_details.branch}
   Service: {implementation_details.service}
   
   Previous violations that should be fixed:
   {fix_context.violations}
   
   Verify these violations are resolved and check for new issues.
   Return structured JSON comparing current vs. previous violations.
   """
   ```
5. Parse agent re-review result
6. Update ticket state:
   ```json
   {
     "stage": "CODE_REVIEW",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "code_review_attempt": 2,
     "code_review_result": {
       "status": "PASSED|FAILED",
       "violations": ...,
       "feedback": ...
     },
     "history": [..., {"stage": "CODE_REVIEW", "at": "<timestamp>", "attempt": 2}]
   }
   ```
7. **Checkpoint:** Write state to disk immediately
8. **Determine next stage immediately:**
   - If `review_status == "PASSED"`: transition to `VERIFYING`
   - If `review_status == "FAILED"`: transition to `CODE_REVIEW_FAILED` (max retries exhausted)

**If re-implementation or re-review fails:**
- Set stage to `ERROR` with `stage_when_failed: "FIX_IN_PROGRESS"` and error details
- Continue to next ticket

---

#### Stage Handler: FIX_IN_PROGRESS → VERIFYING (Retry Cycle - DevStack)

**Condition:** Ticket is at stage `FIX_IN_PROGRESS` with `fix_context.source == "devstack_verification"`

**Actions:**
1. Read fix context from ticket state (`fix_context` field)
2. Re-invoke the implementation skill with fix instructions:
   ```
   Use Skill tool to invoke: implement-tempest-tests
   Pass arguments: TICKET-ID --fix-context '{fix_context_json}'
   ```
   The fix context tells the implementation skill to fix runtime test failures.
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

#### Stage Handler: VERIFIED → SUBMITTED (triggered by --submitted <gerrit_url>)

**Condition:** `--submitted <gerrit_url>` flag is passed, ticket exists in state (any stage is accepted — user may call this immediately after `git review` without waiting for the next orchestrator run).

**PRE-ACTION: Repo Name Verification**

Skip this entire block if `force_submit == true` (print `⚠️  --force flag set — skipping repo verification` and proceed to Action 1).

**Step A — Extract repo name from URL:**

Examine `<gerrit_url>` using these rules in order:

1. **Standard format** — URL matches `review.opendev.org/c/{repo-path}/+/{number}`:
   - Extract `{repo-path}` (the segment between `/c/` and `/+/`)
   - Example: `https://review.opendev.org/c/openstack/cinder-tempest-plugin/+/12345` → `REPO_NAME = openstack/cinder-tempest-plugin`, `REPO_SOURCE = "url"`

2. **Hash/query format** — URL matches `review.opendev.org/#/q/{hash}` or `/q/{hash}`:
   - Repo is not in the URL; need a minimal API call
   - Extract `{hash}` → `GERRIT_CHANGE_ID = {hash}`, `REPO_SOURCE = "api"`

3. **Fallback** — URL doesn't match any known format:
   - Print: `⚠️  Cannot parse repo from URL '<gerrit_url>'. Skipping verification and proceeding.`
   - Skip to Action 1.

**Step B — Fetch repo via API if needed (hash format only):**

Only run if `REPO_SOURCE == "api"`. Call:
```bash
GERRIT_RAW=$(curl -sf --max-time 15 "https://review.opendev.org/changes/${GERRIT_CHANGE_ID}" 2>&1)
CURL_EXIT=$?
```
No `o=` options — the default response includes the `project` field.

If `CURL_EXIT != 0`: print `⚠️  Gerrit API unreachable (exit {CURL_EXIT}). Skipping verification and proceeding.` and skip to Action 1.

Strip the `)]}'\n` prefix from the response and parse JSON. Extract the `project` field as `REPO_NAME`. If malformed or `project` missing: print a one-line warning and skip to Action 1.

**Step C — Check if repo name contains "tempest":**

Check whether `REPO_NAME` contains the string `tempest` (case-insensitive).

- If **yes**: print `✅ Gerrit repo verified: '{REPO_NAME}' contains 'tempest'` and proceed to Action 1.
- If **no**:
  ```
  ❌ Gerrit verification failed: repo '{REPO_NAME}' does not appear to be a Tempest repository.
     Ticket: {TICKET-ID}
     URL: <gerrit_url>

     Expected a repo whose name contains 'tempest' (e.g., cinder-tempest-plugin).
     If this is correct (e.g., Tempest tests live in a non-standard repo), re-run with:
       /orchestrator {TICKET-ID} --submitted <gerrit_url> --force
  ```
  Stop. Do NOT write state. Do NOT proceed to Action 1. Release the pipeline lock.

**Actions:**
1. Update Jira issue:
   - Set `customfield_10530` (Gerrit Link field) to `<gerrit_url>`:
     ```
     Use mcp__mcp-atlassian__jira_update_issue
     fields: {"customfield_10530": "<gerrit_url>"}
     ```
   - Post comment using `config.verification.submitted_jira_comment`:
     ```
     Use mcp__mcp-atlassian__jira_add_comment
     Body: config.verification.submitted_jira_comment
     ```
2. Update ticket state:
   ```json
   {
     "stage": "SUBMITTED",
     "entered_stage_at": "<current ISO-8601 timestamp>",
     "submitted_at": "<current ISO-8601 timestamp>",
     "gerrit_url": "<gerrit_url>",
     "gerrit_verification": {
       "repo": "<REPO_NAME>",
       "passed": true
     },
     "history": [..., {"stage": "SUBMITTED", "at": "<timestamp>"}]
   }
   ```
   If `--force` was used, set `"gerrit_verification": {"skipped": true}` instead.
3. **Checkpoint:** Write state to disk immediately
4. Print confirmation:
   ```
   ✅ TICKET-ID marked as SUBMITTED
      Repo: <REPO_NAME>
      Gerrit Link field updated: <gerrit_url>
      Jira comment posted.
   ```

---

#### Terminal Stages: VERIFIED / SUBMITTED / CODE_REVIEW_FAILED / VERIFICATION_FAILED / VERIFICATION_SKIPPED / REJECTED / TIMED_OUT / ERROR

**Condition:** Ticket is at any terminal stage

**Actions:**
- Report current status for this ticket
- No further action taken
- If `--retry` flag was passed and stage is ERROR:
  - Read `error.stage_when_failed` from state
  - Reset stage to that value
  - Clear error field
  - Re-process through the appropriate stage handler above
- If `--retry` flag was passed and stage is CODE_REVIEW_FAILED:
  - Reset stage to `IMPLEMENTING`
  - Clear code review failure fields
  - Re-process through implementation and code review
- If `--retry` flag was passed and stage is VERIFICATION_FAILED:
  - Reset stage to `IMPLEMENTING`
  - Clear failure fields
  - Re-process through implementation, code review, and verification

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

### STEP 4: Log Run and Release Lock

**Release pipeline lock first:**
```bash
rm -f ~/.claude/orchestrator-state/.pipeline.lock
```

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

**ERROR handling in the summary:**

For every ticket at stage `ERROR` or any terminal failure stage (`CODE_REVIEW_FAILED`, `VERIFICATION_FAILED`):

1. **Highlight clearly in the summary table** — mark with `❌` prefix
2. **Post a Jira comment** (if MCP available):
   ```
   Use mcp__mcp-atlassian__jira_add_comment:
     issue_key: {ticket_id}
     body: "❌ Automation pipeline error on {ticket_id}.
            Stage failed: {error.stage_when_failed}
            Error: {error.message}
            
            To retry: /orchestrator {ticket_id} --retry"
   ```
3. **Print a dedicated ERROR section** after the summary table:
   ```
   ⚠️  ACTION REQUIRED — {n} ticket(s) need attention:
   ─────────────────────────────────────────────────────
   ❌ OSPRH-22618  ERROR at ANALYZED: Jira ticket not found
      → Fix: /orchestrator OSPRH-22618 --retry
   
   ❌ OSPRH-22619  CODE_REVIEW_FAILED: 3 violations after 1 retry
      → Fix: Review violations manually, then:
             /orchestrator OSPRH-22619 --reset-to IMPLEMENTING
   ─────────────────────────────────────────────────────
   ```

If no errors: omit the ERROR section entirely.

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
