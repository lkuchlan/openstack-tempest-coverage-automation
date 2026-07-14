# Verify Tempest DevStack Skill

Verification skill for running Tempest tests against a real DevStack environment.

## Purpose

**Verification focused** - Takes implemented tests and validates them against real OpenStack APIs on a DevStack VM.

Use this skill for:
- Verifying Tempest tests on a real OpenStack deployment
- Deploying DevStack from scratch with required services
- Detecting real-world failures that unit tests miss
- Providing structured feedback for test fixes
- Measuring coverage increase against analysis baseline

**NOT for implementation** - Use `implement-tempest-tests` to write tests first.

## Features

- **SSH-based remote execution:** Operates on a remote VM via SSH
- **Automated DevStack deployment:** Clones, configures, and deploys DevStack from scratch
- **Service auto-detection:** Parses test code to determine which services to enable
- **Structured feedback:** On failure, produces actionable JSON for the retry loop
- **Coverage measurement:** Compares results against analysis baseline
- **Log collection:** Gathers service logs for debugging failures

## Quick Start

### Basic Verification

```bash
/verify-tempest-devstack OSPRH-22613
```

**Does:**
- Validates SSH connectivity to VM
- Parses test files for required services
- Deploys DevStack with correct services enabled
- Installs Tempest and plugin
- Copies test files to VM
- Runs tests against real OpenStack APIs
- Collects results and logs
- Generates verification report

### With Explicit Service and Module

```bash
/verify-tempest-devstack OSPRH-22613 --service cinder \
    --test-module cinder_tempest_plugin.tests.api.test_multiattach_rbac
```

### Skip DevStack Deploy (reuse existing)

```bash
/verify-tempest-devstack OSPRH-22613 --skip-deploy
```

### After Implementation

```bash
# Step 1: Implement
/implement-tempest-tests OSPRH-22613

# Step 2: Verify on DevStack
/verify-tempest-devstack OSPRH-22613
```

## Output Example

```markdown
================================================================
DEVSTACK VERIFICATION REPORT
================================================================

### Ticket: OSPRH-22613
### Service: Cinder
### Overall Status: PASSED
### Verification Attempt: 1 of 2

---

### DevStack Deployment
- VM: stack@192.168.1.10
- DevStack Branch: master
- Services Enabled: c-api, c-vol, c-sch, c-bak, key, n-api, g-api
- Deployment Duration: 42m 15s
- Deployment Status: SUCCESS

### Test Execution
- Tests Run: 3
- Passed: 3
- Failed: 0
- Skipped: 0
- Duration: 45.2s

### Test Results Detail
| # | Test Method | Status | Duration |
|---|-------------|--------|----------|
| 1 | test_volume_multiattach_admin_authorized() | PASSED | 12.3s |
| 2 | test_volume_multiattach_member_authorized() | PASSED | 15.1s |
| 3 | test_volume_multiattach_unauthorized_negative() | PASSED | 8.8s |

### Coverage Increase
- Before: 0 multiattach RBAC tests
- After: 3 tests
- Coverage Delta: +100%

================================================================
END OF VERIFICATION REPORT
================================================================
```

## Workflow

```
User provides ticket ID
         |
[Validate SSH connectivity]
         |
[Parse test code for required services]
         |
[Deploy DevStack on VM (30-60 min)]
         |
[Install Tempest + plugin on VM]
         |
[SCP test files to VM]
         |
[Run tempest tests against real APIs]
         |
[Collect results + service logs]
         |
[Measure coverage delta]
         |
[Generate verification report]
         |
    +----+----+
    |         |
 PASSED    NOT PASSED
    |         |
    |    [Post ⚠️ + 🚀 Jira comment]
    |         |
 VERIFIED  VERIFICATION_SKIPPED
           (manual verify recommended)
```

## Configuration

### Required: Set Environment Variables

The skill reads VM connection details and passwords from environment variables. Set these before first use:

```bash
# Option 1: Copy and edit .env file
cp examples/.env.example .env
vi .env  # Set DEVSTACK_HOST, DEVSTACK_USER, DEVSTACK_SSH_KEY

# Option 2: Export directly
export DEVSTACK_HOST=your-vm-ip
export DEVSTACK_USER=ubuntu
export DEVSTACK_SSH_KEY=~/.ssh/devstack_key
```

| Variable | Required | Description |
|----------|----------|-------------|
| `DEVSTACK_HOST` | Yes | VM hostname or IP |
| `DEVSTACK_USER` | Yes | SSH username (must have sudo) |
| `DEVSTACK_SSH_KEY` | Yes | Path to SSH private key |
| `DEVSTACK_ADMIN_PASSWORD` | No | DevStack admin password (default: secretadmin) |
| `DEVSTACK_DB_PASSWORD` | No | Database password (default: secretdb) |
| `DEVSTACK_RABBIT_PASSWORD` | No | RabbitMQ password (default: secretrabbit) |
| `DEVSTACK_SERVICE_PASSWORD` | No | Service password (default: secretservice) |

### Optional: Tune Settings

Non-sensitive settings are in `skills/verify-tempest-devstack/config.json`:

| Setting | Description | Default |
|---------|-------------|---------|
| `devstack.branch` | DevStack git branch | `master` |
| `devstack.deploy_timeout` | Max deploy time (seconds) | `3600` |
| `test_execution.timeout` | Max test run time (seconds) | `1800` |
| `test_execution.concurrency` | Parallel test workers | `1` |
| `cleanup.cleanup_after_verification` | Unstack after done | `false` |

## Retry Loop (Auto-Retry Once)

When tests fail, the skill produces structured JSON feedback:

```json
{
  "verification_status": "FAILED",
  "ticket_id": "OSPRH-22613",
  "failed_tests": [
    {
      "method": "test_volume_multiattach_admin_authorized",
      "error_type": "AssertionError",
      "likely_cause": "Missing multiattach flag in create_volume call",
      "suggested_fix": "Add multiattach=True to create_volume()"
    }
  ]
}
```

If DevStack verification does not pass, the pipeline advances to VERIFICATION_SKIPPED, posts a ⚠️ DevStack Verification Skipped comment with 🚀 Gerrit submission instructions, and the engineer is recommended to verify manually before merging.

## Performance

- **DevStack deployment:** 30-60 minutes (one-time per verification)
- **Test execution:** 1-30 minutes (depends on test count)
- **Log collection:** < 1 minute
- **Total:** ~35-90 minutes per verification

Use `--skip-deploy` to skip deployment when DevStack is already running (~5-35 minutes).

## Prerequisites

### VM Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| OS | Ubuntu 22.04 (jammy) | **Ubuntu 24.04 (noble)** |
| RAM | 8GB + 4GB swap | **16GB** |
| CPUs | 4 | **8** |
| Disk | 40GB | 60GB |
| Network | Reach `opendev.org` | Same |

**Ubuntu 24.04 is strongly recommended.** Ubuntu 22.04 works but requires 8 automated workarounds (Python 3.11 PPA, pip uwsgi, Apache patches, etc.). Ubuntu 24.04 works out of the box with zero workarounds.

### Setup

1. **VM with SSH access** — reachable via SSH from the machine running Claude Code
2. **SSH key configured** — set `DEVSTACK_HOST`, `DEVSTACK_USER`, `DEVSTACK_SSH_KEY` env vars
3. **Network access** — VM must reach `opendev.org` for git clones

## Integration with Pipeline

This skill is Stage 5.7 in the pipeline:

```
Stage 1:   Discovery (JQL → ticket IDs)
Stage 2:   DISCOVERED → ANALYZED (/jira-coverage-analysis)
Stage 3:   ANALYZED → AWAITING_APPROVAL (/post-test-plan)
Stage 4:   AWAITING_APPROVAL → APPROVED (approval monitoring)
Stage 5:   APPROVED → IMPLEMENTING (/implement-tempest-tests)
Stage 5.6: IMPLEMENTING → VERIFYING (automated code review)
Stage 5.7: VERIFYING → VERIFIED (/verify-tempest-devstack)  <-- THIS SKILL
Stage 5.8: Fork sync (keep fork master current)
Stage 6:   Push VERIFIED branches to GitHub fork
```

## See Also

- **implement-tempest-tests** - Implement tests first (prerequisite)
- **jira-coverage-analysis** - Analyze coverage gaps
- **orchestrator** - Full pipeline automation

## Documentation

- **SKILL.md** - Complete workflow (skill definition)
- **config.json** - All configurable settings
- **Shared config:** See `skills/shared/config.json` for service mappings

---

**Real-world test verification on actual OpenStack APIs!**
