# Orchestrator Skill

Pipeline orchestrator that ties all Tempest coverage skills into a reliable, resumable automated workflow.

## Purpose

Manage Jira tickets through a state machine — Discovery → Analysis → Post Plan → Approval Monitoring → Implementation → Verification → Submitted — without requiring manual hand-offs between stages.

## Usage

```bash
/orchestrator TICKET-ID [TICKET-ID...]            # Process one or more tickets
/orchestrator --jql "project = OSPRH AND ..."     # Discover tickets via JQL
/orchestrator --status                             # Show all tracked tickets and their stages
/orchestrator --dry-run --jql "..."               # Preview what would happen, take no action
/orchestrator TICKET-ID --retry                   # Retry a ticket stuck in ERROR state
/orchestrator TICKET-ID --reset-to STAGE          # Force a ticket to a specific stage
/orchestrator TICKET-ID --submitted <gerrit_url>  # Mark as submitted after git review
```

## Pipeline Stages

```
DISCOVERED
    ↓  /jira-coverage-analysis
ANALYZED
    ↓  /post-test-plan
AWAITING_APPROVAL
    ↓  (approval-monitor polls every 4h)
APPROVED
    ↓  /implement-tempest-tests
IMPLEMENTING
    ↓  automated code review (Stage 5.6)
VERIFYING
    ↓  /verify-tempest-devstack
    ↓  Pass                          Fail
VERIFIED                    VERIFICATION_SKIPPED
    ↓  git review (manual),         ↓  manual verify recommended,
       then --submitted                 then git review + --submitted
SUBMITTED  ← terminal

REJECTED           ← terminal (approval denied)
TIMED_OUT          ← terminal (no response in 7 days)
CODE_REVIEW_FAILED ← terminal (Tempest standards violations)
VERIFICATION_SKIPPED ← DevStack did not pass; branch pushed to fork, manual verify needed
```

**discussion_flagged:** A sub-state of AWAITING_APPROVAL. Set when the approval-monitor detects a neutral stakeholder comment (neither approval nor rejection). The ticket stays at AWAITING_APPROVAL; user is notified. Re-running `/post-test-plan` after addressing feedback uses the revised template automatically.

## State File

Pipeline state is stored at:
```
~/.claude/orchestrator-state/pipeline-state.json
```

The state file tracks every ticket's current stage, timestamps, errors, and metadata. It is safe to inspect directly. All orchestrator operations are idempotent — re-running a stage that already completed is a no-op.

## The --submitted Flag

After running `git review` manually, use `--submitted` to close the loop in Jira:

```bash
git review
# Copy the Gerrit URL from the output, then:
/orchestrator TICKET-ID --submitted https://review.opendev.org/c/openstack/...
```

This:
1. Sets the Gerrit Link field (`customfield_10530`) on the Jira issue
2. Posts a submission comment to the ticket
3. Advances the ticket to the SUBMITTED terminal stage

## Integration with Other Skills

The orchestrator invokes each skill in `--orchestrator-mode`, which returns structured JSON instead of markdown. The skills themselves are unchanged — the mode flag only switches the output format.

| Stage | Skill invoked |
|---|---|
| Analysis | `/jira-coverage-analysis --orchestrator-mode` |
| Plan posting | `/post-test-plan --orchestrator-mode` |
| Approval check | `approval-monitor` agent (via CronCreate) |
| Implementation | `/implement-tempest-tests --orchestrator-mode` |
| Verification | `/verify-tempest-devstack --orchestrator-mode` |
| Submission | `--submitted` handler (inline, no separate skill) |

## See Also

- **[jira-coverage-analysis/README.md](../jira-coverage-analysis/README.md)** - Analysis skill
- **[post-test-plan/README.md](../post-test-plan/README.md)** - Plan posting skill
- **[implement-tempest-tests/README.md](../implement-tempest-tests/README.md)** - Implementation skill
- **[verify-tempest-devstack/README.md](../verify-tempest-devstack/README.md)** - Verification skill
- **[ARCHITECTURE.md](../../docs/ARCHITECTURE.md)** - System design and data flow
- **[EXAMPLES.md](../../docs/EXAMPLES.md)** - End-to-end workflow examples
