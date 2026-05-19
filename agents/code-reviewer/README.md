# Code Review Agent

**Internal agent for Tempest test standards validation**

## Purpose

This agent performs automated code review on Tempest test implementations, validating against upstream OpenStack standards. It's invoked by the orchestrator as part of the pipeline, **not by users directly**.

**Catches 60-70% of failures before DevStack** (10 seconds vs. 60 minutes)

---

## Architecture

```
orchestrator (skills/orchestrator/)
    ↓
Agent(subagent_type="code-reviewer", ...)  ← This agent
    ↓
Returns structured JSON feedback
    ↓
orchestrator processes result (PASSED → VERIFYING, FAILED → FIX_IN_PROGRESS)
```

**This is an internal implementation detail**, not a user-facing skill.

---

## Files

- **prompt.md** - Agent instructions and workflow
- **rules.json** - Validation rules configuration
- **README.md** - This file

---

## Validation Checks (7 total)

1. **Base classes** (ERROR): Must inherit from BaseVolumeTest, etc. (not unittest.TestCase)
2. **Client usage** (ERROR): Must use service clients (not requests, urllib)
3. **Waiter usage** (ERROR): Must use waiters (not time.sleep)
4. **Cleanup** (ERROR): Direct API calls must have addCleanup
5. **Decorators** (ERROR): Must have @idempotent_id and @attr
6. **Test independence** (ERROR): No shared class-level state
7. **Naming** (WARNING): Descriptive test names

---

## Usage (Internal - Orchestrator Only)

**From orchestrator CODE_REVIEW stage:**

```python
Agent(
    subagent_type="code-reviewer",
    description="Review Tempest tests for TICKET-123",
    prompt=f"""
Review Tempest tests for {ticket_id}.

Repository: {repo_path}
Branch: {branch_name}
Service: {service}

Validate against TEMPEST_STANDARDS.md and return JSON.
"""
)
```

**Agent returns:**
```json
{
  "review_status": "PASSED|FAILED",
  "violations": [...],
  "summary": {"errors": 0, "warnings": 0, "files_reviewed": 1}
}
```

---

## Output Format

### Success (No Violations)
```json
{
  "review_status": "PASSED",
  "ticket_id": "OSPRH-22613",
  "reviewed_files": ["test_multiattach.py"],
  "violations": [],
  "warnings": [],
  "summary": {
    "total_violations": 0,
    "errors": 0,
    "warnings": 0,
    "files_reviewed": 1
  }
}
```

### Failure (Violations Found)
```json
{
  "review_status": "FAILED",
  "ticket_id": "OSPRH-22613",
  "reviewed_files": ["test_multiattach.py"],
  "violations": [
    {
      "file": "test_multiattach.py",
      "line": 67,
      "rule": "waiter",
      "severity": "ERROR",
      "message": "Uses time.sleep(10) instead of waiters",
      "suggested_fix": "Replace with: waiters.wait_for_volume_resource_status(...)"
    }
  ],
  "warnings": [],
  "summary": {
    "total_violations": 1,
    "errors": 1,
    "warnings": 0,
    "files_reviewed": 1
  }
}
```

---

## Integration with Pipeline

**Pipeline flow:**
```
IMPLEMENTING (tests written)
    ↓
CODE_REVIEW (this agent runs)
    ↓ PASSED
VERIFYING (DevStack)
    ↓
VERIFIED ✅

CODE_REVIEW (FAILED)
    ↓
FIX_IN_PROGRESS (re-implementation)
    ↓
CODE_REVIEW (retry with retry context)
```

**State tracking** (orchestrator's pipeline-state.json):
```json
{
  "tickets": {
    "OSPRH-22613": {
      "stage": "CODE_REVIEW",
      "code_review_attempt": 1,
      "code_review_result": {
        "status": "FAILED",
        "violations": 2
      }
    }
  }
}
```

---

## Configuration

**rules.json** contains:
- Allowed/forbidden patterns for each rule
- Severity levels (ERROR blocks, WARNING doesn't)
- `fail_on_warnings` flag (default: false)

**Modify rules:**
```json
{
  "rules": {
    "base_class": {
      "severity": "ERROR",
      "allowed_base_classes": ["BaseVolumeTest", "..."]
    }
  }
}
```

---

## Comparison with Skill Approach

**Why agent vs. skill?**

| Aspect | Agent (Current) | Skill (Alternative) |
|--------|-----------------|---------------------|
| **Invocation** | Internal (orchestrator only) | User-invokable (`/review-tempest-tests`) |
| **Complexity** | Simple (just agent prompt) | More complex (SKILL.md + wrapper) |
| **Discovery** | Hidden implementation detail | Visible in skill list |
| **Testing** | Test via orchestrator | Can test directly |
| **Architecture** | Clean (sub-task of pipeline) | More overhead |

**Decision:** Agent is cleaner for an internal pipeline step.

---

## References

- **Agent prompt**: `prompt.md`
- **Validation rules**: `rules.json`
- **Tempest standards**: `../../references/TEMPEST_STANDARDS.md`
- **Orchestrator integration**: `../../skills/orchestrator/SKILL.md` (CODE_REVIEW stage)
