# Pipeline Stage Reference

Complete definition of all pipeline stages, transitions, and handlers.

This reference is used by:
- The orchestrator skill (manual recovery operations)
- The bash pipeline runner (`scripts/run-pipeline.sh`)

---

## Stage Machine

```
DISCOVERED → ANALYZED → AWAITING_APPROVAL → APPROVED → IMPLEMENTING → CODE_REVIEW
                                                                          │
                                                         ┌────────────────┤
                                                         │ PASSED         │ FAILED
                                                         ▼                ▼
                                                      VERIFYING    CODE_REVIEW_FAILED
                                                         │
                              ┌──────────────────────────┼──────┐
                        PASSED│            DEPLOYMENT_    │FAILED │SKIPPED
                              ▼            FAILED         ▼       ▼
                           VERIFIED          ERROR  VERIFICATION_SKIPPED
                              │
                              │ --submitted
                              ▼
                           SUBMITTED
```

> **Note:** The automated pipeline does not implement a retry loop. A code review failure goes directly to `CODE_REVIEW_FAILED` (terminal). A DevStack failure goes directly to `VERIFICATION_SKIPPED`. Manual recovery is possible via `--retry` + `--reset-to IMPLEMENTING`.

**Terminal stages:** SUBMITTED, VERIFIED (pending --submitted), VERIFICATION_SKIPPED, CODE_REVIEW_FAILED, REJECTED, TIMED_OUT, ERROR

---

## Stage Definitions

| Stage | Meaning |
|-------|---------|
| DISCOVERED | Ticket found via JQL or manual input |
| ANALYZED | Coverage analysis completed |
| PLAN_POSTED | Test plan posted to Jira (transitional) |
| AWAITING_APPROVAL | Waiting for stakeholder approval in Jira |
| APPROVED | Plan approved, ready for implementation |
| IMPLEMENTING | Test implementation complete, ready for code review |
| CODE_REVIEW | Code review completed (checking Tempest standards) |
| VERIFYING | Tests being verified against DevStack |
| FIX_IN_PROGRESS | Re-implementing tests after code review or verification failure (manual only — not entered automatically) |
| VERIFIED | Tests passed on real DevStack environment |
| SUBMITTED | Patch submitted for upstream review on Gerrit |
| CODE_REVIEW_FAILED | Code review failed after retry cycle exhausted |
| VERIFICATION_SKIPPED | Tests cannot be verified on DevStack (specific backend/hardware/multi-node) |
| REJECTED | Plan rejected by stakeholder |
| TIMED_OUT | Approval deadline passed without response |
| ERROR | Stage failed with error |

---

## Automated Pipeline (bash-driven)

`scripts/run-pipeline.sh` drives all stage transitions in the automated pipeline:

| Bash stage | State transition | Skill called |
|-----------|-----------------|--------------|
| Stage 2 | DISCOVERED → ANALYZED | `/jira-coverage-analysis` |
| Stage 3 | ANALYZED → AWAITING_APPROVAL | `/post-test-plan` |
| Stage 4 | AWAITING_APPROVAL → APPROVED/REJECTED/TIMED_OUT | `/tempest-coverage-orchestrator` (approval check) |
| Stage 5 | APPROVED → IMPLEMENTING | `/implement-tempest-tests` |
| Stage 5.6 | IMPLEMENTING → CODE_REVIEW | inline claude code-review call |
| Stage 5.7 | CODE_REVIEW → VERIFYING/VERIFICATION_SKIPPED | `/verify-tempest-devstack` |
| Stage 5.8 | sync GitHub fork master branches | bash git commands |
| Stage 6 | push VERIFIED/VERIFICATION_SKIPPED branches | bash git push via SSH key |

**Parallel execution:** DISCOVERED, ANALYZED, APPROVED, IMPLEMENTING stages can run in parallel (up to `config.parallel_execution.max_parallel_agents` = 5). CODE_REVIEW and VERIFYING are always SEQUENTIAL due to the VM lock.

---

## Stage Handler Details

### DISCOVERED → ANALYZED

1. Invoke `jira-coverage-analysis` skill with `--orchestrator-mode`
2. Parse JSON output: `service`, `plugin`, `coverage_status`, `gaps_identified`, `analysis_summary`
3. Update state:
   ```json
   {
     "stage": "ANALYZED",
     "entered_stage_at": "<timestamp>",
     "service": "<detected service>",
     "plugin": "<detected plugin>",
     "analysis_summary": "<brief summary>",
     "history": [..., {"stage": "ANALYZED", "timestamp": "<timestamp>"}]
   }
   ```
4. Checkpoint state immediately

**On failure:** Set stage to ERROR with `stage_when_failed: "DISCOVERED"`

---

### ANALYZED → AWAITING_APPROVAL

1. Invoke `post-test-plan` skill with `--orchestrator-mode`
2. Calculate `approval_deadline` = now + `config.approval.timeout_days` days
3. Update state:
   ```json
   {
     "stage": "AWAITING_APPROVAL",
     "entered_stage_at": "<timestamp>",
     "plan_posted_at": "<timestamp>",
     "jira_comment_id": "<comment id>",
     "approval_deadline": "<deadline>",
     "approval_checks": 0,
     "last_check": null,
     "history": [..., {"stage": "AWAITING_APPROVAL", "timestamp": "<timestamp>"}]
   }
   ```
4. Checkpoint state immediately

**On failure:** Set stage to ERROR with `stage_when_failed: "ANALYZED"`

---

### AWAITING_APPROVAL (approval check — performed by orchestrator at stage 4)

See `orchestrator/SKILL.md` STEP 1 for the approval checking procedure.

If approval monitoring was NOT scheduled (cron creation failed):
- Warn in summary: "⚠️ {ticket_id} is awaiting approval but no automatic monitoring is active."

---

### APPROVED → IMPLEMENTING

1. Invoke `implement-tempest-tests` skill with `--orchestrator-mode`
2. Parse JSON: `branch`, `test_files`, `test_files_absolute`, `test_methods`, `commit_sha`, `repository_path`, `test_module`
3. Update state:
   ```json
   {
     "stage": "IMPLEMENTING",
     "entered_stage_at": "<timestamp>",
     "implementation_details": {
       "test_files": [...],
       "test_files_absolute": [...],
       "branch": "tempest-coverage-TICKET-ID",
       "repository_path": "/path/to/plugin",
       "test_module": "plugin.tests.api.test_feature",
       "service": "cinder",
       "test_methods": ["test_method_1"]
     },
     "history": [..., {"stage": "IMPLEMENTING", "timestamp": "<timestamp>"}]
   }
   ```
4. Checkpoint state immediately

**On failure:** Set stage to ERROR with `stage_when_failed: "APPROVED"`

---

### IMPLEMENTING → CODE_REVIEW (inline code review)

Performed by `run-pipeline.sh` stage 5.6 as an inline Claude call. Checks 7 Tempest standards:

1. Base class usage (no `unittest.TestCase` — must inherit from Tempest base class)
2. Client usage (no raw HTTP — no `requests`, `urllib`, direct API calls)
3. Waiter usage (no `time.sleep()` — must use `waiters.wait_for_*`)
4. Cleanup patterns (`addCleanup` required; not redundant with helper cleanup)
5. Required decorators (`@decorators.idempotent_id`, `@decorators.attr`)
6. Test independence (no shared state between tests)
7. Naming conventions (`test_{action}_{condition}`)

Max retry cycles: `config.code_review.max_retry_cycles` (default: 1)

**On PASSED:**
```json
{"stage": "CODE_REVIEW", "code_review_result": {"status": "PASSED", "violations": 0}}
```
→ transition to VERIFYING

**On FAILED:**
```json
{"stage": "CODE_REVIEW_FAILED", "final_violations": [...]}
```
Terminal. Manual recovery: `/orchestrator TICKET-ID --retry` after `/orchestrator TICKET-ID --reset-to IMPLEMENTING`.

---

### CODE_REVIEW → VERIFYING

Performed by `run-pipeline.sh` stage 5.7:

1. Invoke `verify-tempest-devstack` skill
2. Parse result: `verification_status` (PASSED/FAILED/SKIPPED/DEFERRED/DEPLOYMENT_FAILED)

**PASSED** → VERIFIED stage handler (see below)

**DEFERRED** (VM locked): keep at CODE_REVIEW, do NOT advance, do NOT error

**DEPLOYMENT_FAILED** → ERROR with `error_type: "deployment_failure"`. Post Jira comment using `config.verification.deployment_failed_jira_comment` template. This is an infrastructure issue — do NOT trigger fix+retry.

**SKIPPED** → VERIFICATION_SKIPPED stage handler (see below)

**FAILED** → VERIFICATION_SKIPPED. Post ⚠️+🚀 Jira comment with `git fetch` + `git review` instructions. Terminal. Manual recovery: `/orchestrator TICKET-ID --reset-to IMPLEMENTING` then re-run the pipeline.

---

### VERIFIED (post-transition actions)

When `verify-tempest-devstack` returns PASSED:

1. Update state:
   ```json
   {
     "stage": "VERIFIED",
     "verified_at": "<timestamp>",
     "verification_summary": "{tests_passed}/{tests_total} tests passed on DevStack ({host})"
   }
   ```

2. Push branch to GitHub fork (`run-pipeline.sh` stage 6):
   ```bash
   SSH_KEY=~/.ssh/github_fork_push
   FORK_URL=config.verification.github_forks[plugin_name]
   GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
     git push fork-push {branch_name}
   ```
   If no fork URL found: skip push, note in Jira comment.

3. Post Jira comment (`config.verification.verified_jira_comment` template):
   - Substitute: `{pass_count}`, `{total_count}`, `{devstack_host}`, `{backend_info}`, `{branch_name}`, `{plugin_name}`, `{test_file_path}`, `{test_results_table}`
   - Add label: `automation-verified`

---

### VERIFICATION_SKIPPED

Post Jira comment:
- Use `config.verification.skipped_jira_comment` template
- Add label: `automation-manual-verification-needed`

**Note:** VERIFICATION_SKIPPED is a terminal success state. The tests are implemented and ready; they just need manual verification on a real deployment.

---

### FIX_IN_PROGRESS (manual recovery only)

`FIX_IN_PROGRESS` is not entered automatically by the pipeline. It is available for manual recovery:

1. `/orchestrator TICKET-ID --reset-to FIX_IN_PROGRESS` (or `--reset-to IMPLEMENTING`)
2. Run `/implement-tempest-tests TICKET-ID --fix-context '{...}'` with the violations/failures from the previous attempt
3. The pipeline will pick the ticket up at IMPLEMENTING on its next run and re-run code review and verification

---

## Parallel Execution (batch management)

When a stage is parallelizable and has >= `min_tickets_for_parallel` tickets:

1. Write batch record to state before starting:
   ```json
   {
     "parallel_execution_batch": {
       "batch_id": "batch-{ISO-8601-timestamp}",
       "stage": "{CURRENT} → {NEXT}",
       "started_at": "<timestamp>",
       "tickets_in_batch": [...],
       "in_progress": [...],
       "completed": [],
       "failed": []
     }
   }
   ```

2. Spawn skill invocations concurrently (multiple tool calls in one message)

3. After all complete: clear batch record (`parallel_execution_batch: null`), checkpoint

4. **Crash recovery:** On orchestrator startup, if `parallel_execution_batch` is not null:
   - Calculate elapsed time: `now - started_at`
   - If elapsed > `batch_timeout_minutes`: mark all `in_progress` as ERROR, clear batch
   - Otherwise: clear batch (will retry on next run)

---

## Idempotency Guarantees

| Stage | Re-run behavior |
|-------|----------------|
| DISCOVERED | Analysis runs again, overwrites previous result. Safe. |
| ANALYZED | post-test-plan has duplicate detection. Safe. |
| AWAITING_APPROVAL | Comment check is read-only. Safe. |
| APPROVED | Re-runs implementation. Creates new branch if needed. Safe. |
| IMPLEMENTING | Re-runs verification. Redeploys DevStack (30-60 min). Safe but slow. |
| FIX_IN_PROGRESS | Re-runs fix cycle. Safe. |
| VERIFYING | Re-evaluates verification result. Safe. |
| VERIFICATION_SKIPPED | No action unless --retry. Safe. |
| Terminal stages | No action unless --retry. Safe. |
