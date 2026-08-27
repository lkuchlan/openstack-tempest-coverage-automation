---
name: verify-tempest-devstack
description: Deploy DevStack on a VM and verify Tempest tests against a real OpenStack environment
trigger: User wants to verify Tempest tests on a real DevStack deployment or the orchestrator needs verification after implementation
model: sonnet
---

# DevStack Tempest Verification Skill

Verify Tempest tests against a real DevStack environment. Deploy DevStack from scratch, run tests against real OpenStack APIs, and produce structured feedback on failure.

**NOT for implementation** — use `implement-tempest-tests` to write tests first.  
**NOT for auto-retry** — the orchestrator handles the retry loop, not this skill.  
**NOT for modifying test code** — that is the implementation skill's job.

---

## STEP 0: Load Config, Resolve Env Vars, Validate SSH

1. Load `config.json` adjacent to this SKILL.md.
2. Resolve `env:` prefixed values from environment:
   ```bash
   echo $DEVSTACK_HOST && echo $DEVSTACK_USER && echo $DEVSTACK_SSH_KEY
   ```
   **If `DEVSTACK_HOST`, `DEVSTACK_USER`, or `DEVSTACK_SSH_KEY` are not set → STOP.** Report which variable is missing.
3. Validate SSH:
   ```bash
   ls -la {config.ssh.key_path}
   ssh -i {key} -p {port} {options} -o ConnectTimeout={timeout} {user}@{host} "echo 'SSH connection OK'"
   ```
   If SSH fails → STOP with troubleshooting suggestion.
4. Parse flags: `--service`, `--test-module`, `--retry-context`, `--skip-deploy`.

---

## STEP 1: Parse Test Code for Required Services

Read local test files (use `git diff main --name-only | grep test_` if no paths provided).

```bash
grep -n "CONF.service_available\|is_service_enabled" {test_files}
grep -A 10 "def skip_checks" {test_files}
grep -n "credentials = " {test_files}
grep -n "CONF.*_feature_enabled\|api_extensions\|required_extensions" {test_files}
```

Determine **service tier** by scanning for full-trigger patterns:
```bash
grep -n "servers_client\|create_server\|networks_client\|create_network\|attach_volume\|detach_volume" {test_files}
```
- ANY full-trigger found → **full tier** (enable `full_services` + `requires_for_full` from config)
- No triggers → **api-only tier** (faster, fewer resources)

---

## STEP 1.5: Feasibility Check (BEFORE deploying)

Check whether DevStack can satisfy the tests. If not feasible → return SKIPPED immediately.

```bash
grep -in "CONF.volume.backend_name\|CONF.share.backend_names\|CONF.volume.vendor_name" {test_files}
grep -in "min_compute_nodes\|CONF.compute.min_compute_nodes" {test_files}
grep -in "sr-iov\|sriov\|dpdk\|gpu\|vtpm\|pci_passthrough\|live_migration" {test_files}
```

- Unsupported backend (ceph, netapp, pure, dell_emc, hpe_3par, ibm_storwize, huawei, hitachi, infinidat) → **SKIPPED**
- `min_compute_nodes > 1` → **SKIPPED**
- Unsupported feature (sr-iov, dpdk, gpu, vtpm, pci_passthrough, live_migration) → **SKIPPED**

Return:
```json
{
  "verification_status": "SKIPPED",
  "ticket_id": "OSPRH-12345",
  "skip_reason": "DevStack cannot provide {requirement}. Manual verification on a real deployment is needed.",
  "unsupported_requirements": ["ceph backend"]
}
```
Generate the verification report (STEP 7) with SKIPPED status. Do NOT deploy.

---

## STEP 2: Deploy DevStack

**CRITICAL: Takes 30-60 minutes. Use nohup + ScheduleWakeup polling.**

**If `--skip-deploy`:** skip to VM lock + cache check, then go to STEP 3.

### 2a. Acquire VM lock

```bash
ssh ... "cat /opt/stack/.devstack-lock 2>/dev/null"
```

- Lock age < `config.vm_lock.stale_timeout_hours` → return **DEFERRED** immediately:
  ```json
  {"verification_status": "DEFERRED", "reason": "VM locked by {ticket}, retry next run"}
  ```
- Lock absent or stale → acquire:
  ```bash
  ssh ... "echo '{\"ticket_id\": \"{ticket_id}\", \"locked_at\": \"{ISO-8601 now}\"}' > /opt/stack/.devstack-lock"
  ```
- **Always release after verification (pass/fail/error):**
  ```bash
  ssh ... "rm -f /opt/stack/.devstack-lock"
  ```

### 2b. Check deployment cache

```bash
ssh ... "cat {config.deployment_cache.fingerprint_path} 2>/dev/null"
```
If topology matches (required services ⊆ deployed services AND branch matches) AND services running → **skip deployment**, go to STEP 3.

### 2c. Clean + clone

```bash
ssh ... "if [ -d /opt/stack/devstack ]; then cd /opt/stack/devstack && ./unstack.sh 2>/dev/null; sudo rm -rf /opt/stack/devstack /opt/stack/logs; fi"
ssh ... "git clone {config.devstack.git_url} -b {config.devstack.branch} /opt/stack/devstack"
ssh ... "hostname -I | awk '{print \$1}'"  # get VM IP for HOST_IP
```

### 2d. Generate and upload local.conf

Build `local.conf` using service tier from STEP 1 and `config.service_devstack_mapping`. Transfer via SSH heredoc:
```bash
ssh ... "cat > /opt/stack/devstack/local.conf << 'LOCALCONF'
[[local|localrc]]
ADMIN_PASSWORD={...}
HOST_IP={vm_ip}
enable_service {core_services}
enable_service {tier_services}
{plugin_lines}
LOCALCONF"
```

### 2e. Ubuntu 22.04 (jammy) workarounds

```bash
ssh ... "lsb_release -cs"
```

**If result is `jammy`**, apply all 8 workarounds:

| # | Workaround | Why |
|---|-----------|-----|
| 1 | Install Python 3.11 from deadsnakes PPA | DevStack needs >= 3.11 |
| 2 | Create venv with `python3.11 -m venv` + `pip install uwsgi` | System uwsgi compiled for 3.10 |
| 3 | Replace `/usr/bin/uwsgi` with pip-installed version | Match Python version in venv |
| 4 | Patch `lib/apache`: remove `plugins http,python3` lines | pip uwsgi has Python built in |
| 5 | Patch `lib/keystone`, `lib/nova`, `lib/cinder`: use `write_local_uwsgi_http_config` | Bypass mod_proxy_uwsgi incompatibility |
| 6 | Patch `functions`: fix `get_random_port` to use incrementing counter | Prevent port collisions in HTTP mode |
| 7 | Disable Apache `mod_wsgi` | Compiled for Python 3.10, crashes with 3.11 venv |
| 8 | `pip install libvirt-python` in venv | System package only covers Python 3.10 |

**If result is `noble` (Ubuntu 24.04+):** no workarounds needed. Prefer noble VMs.

### 2f. Run stack.sh via nohup + poll

```bash
# Start stack.sh in background (run_in_background: true)
ssh ... "cd /opt/stack/devstack && nohup bash -c './stack.sh > /tmp/stack-output.log 2>&1 && touch /tmp/stack-done || touch /tmp/stack-failed' &"
```

Poll with **ScheduleWakeup** at 270-second intervals:
```bash
ssh ... "ls /tmp/stack-done /tmp/stack-failed 2>/dev/null; tail -5 /tmp/stack-output.log"
```

Continue until `/tmp/stack-done` or `/tmp/stack-failed` appears, or `config.devstack.deploy_timeout` (3600s) exceeded.

**On success:** verify services with `openstack service list -f json`, then write topology fingerprint.

**On stack-failed or timeout → DEPLOYMENT_FAILED** (NOT the same as test FAILED):
```bash
ssh ... "tail -100 /opt/stack/logs/stack.sh.log 2>/dev/null || tail -100 /tmp/stack-output.log"
```
Return:
```json
{
  "verification_status": "DEPLOYMENT_FAILED",
  "deployment_error": "...",
  "deployment_logs": "last 100 lines",
  "suggested_action": "Check VM resources, network, and OS compatibility"
}
```
Do NOT execute tests. The orchestrator will NOT trigger fix+retry for deployment failures.

---

## STEP 3: Install Tempest + Plugin, Transfer Files, Verify Discovery

```bash
# Install Tempest
ssh ... "cd /opt/stack && git clone https://opendev.org/openstack/tempest.git; cd tempest && pip install -e ."

# Install plugin (URL from config.tempest_plugin_repos)
ssh ... "cd /opt/stack && git clone {plugin_repo_url}; cd {plugin_name} && pip install -e ."

# Transfer test files via SCP
scp -i {key} -P {port} {local_file} {user}@{host}:/opt/stack/{plugin}/{relative_path}
```

**SCP failure fallback:** transfer via SSH heredoc. If that also fails → return FAILED.

```bash
# Generate tempest.conf
ssh ... "cd /opt/stack/tempest && discover-tempest-config ... || tox -e tempest-generate-config"

# Verify test discovery (MANDATORY)
ssh ... "cd /opt/stack/tempest && tempest run --list-tests 2>/dev/null | grep '{test_module_pattern}'"
```

If tests are NOT discoverable → return FAILED with discovery error details.

---

## STEP 4: Execute Tests

```bash
ssh ... "cd /opt/stack/tempest && source /opt/stack/devstack/openrc admin admin && \
    tempest run --regex '{test_module_regex}' --concurrency {config.test_execution.concurrency}"
```
With `timeout: {config.test_execution.timeout * 1000}` ms (default 1800000 = 30 min).

For long runs, use nohup + poll pattern (same as stack.sh in STEP 2).

Parse output: total, passed, failed, skipped, errors. For each failure: method name, error type, message, traceback.

---

## STEP 5: Collect Results and Logs

```bash
# Service logs (non-fatal if unavailable)
ssh ... "tail -{config.log_collection.max_log_lines} /opt/stack/logs/{service}.log 2>/dev/null"
ssh ... "journalctl -u 'devstack@*' --since '1 hour ago' --no-pager | tail -200"
```

Log collection failure → warn in report, continue. Logs are supplementary.

Save locally (use Write tool):
```
~/.claude/orchestrator-state/verifications/{ticket_id}/test-results.json
~/.claude/orchestrator-state/verifications/{ticket_id}/test-output.log
~/.claude/orchestrator-state/verifications/{ticket_id}/service-logs.log
```

---

## STEP 6: Measure Coverage Delta

```bash
cat ~/.claude/orchestrator-state/tickets/{ticket_id}.json
```
Calculate: new passing tests vs. analysis baseline gaps.

---

## STEP 7: Verification Report (MANDATORY)

**Always generate this report, regardless of pass/fail/skip.**

```markdown
================================================================
DEVSTACK VERIFICATION REPORT
================================================================

Ticket: {TICKET-ID} | Service: {service} | Status: PASSED/FAILED/SKIPPED/DEPLOYMENT_FAILED
Attempt: {n} of {max}

DevStack: {user}@{host} | Branch: {devstack_branch} | Tier: {api-only|full}
Services: {service_list}

Test Execution:
  Total: {n} | Passed: {n} | Failed: {n} | Skipped: {n}

| # | Test Method | Status | Duration |
|---|-------------|--------|----------|
| 1 | test_method_1() | PASSED | 2.3s |
| 2 | test_method_2() | FAILED | 5.1s |

Failed Test Details (if any):
  test_method_2(): {error_type} — {error_message}
  Likely cause: {analysis}

Coverage Delta: +{n} tests ({percentage}% increase)

Logs: ~/.claude/orchestrator-state/verifications/{ticket_id}/
SSH: ssh -i {key_path} {user}@{host}

================================================================
```

---

## STEP 8: Write Artifact File and Structured Feedback

**Write verification artifact (always, regardless of result):**
```bash
mkdir -p ~/.claude/orchestrator-state/{ticket_id}
# Write to: ~/.claude/orchestrator-state/{ticket_id}/verification.json
# Contents: {"verification_status": "PASSED|FAILED|SKIPPED", "tests_passed": N, "tests_total": N, ...}
```
This makes the stage resumable and verifiable by the bash pipeline script.

**If tests failed:** classify each failure by root cause. For the 7 categories and JSON schema:
→ See `references/error-categories.md`

Save structured feedback to:
```
~/.claude/orchestrator-state/verifications/{ticket_id}/feedback.json
```

---

## Cleanup (Config-Driven)

- `config.cleanup.cleanup_after_verification == true` → run `./unstack.sh && ./clean.sh`
- `config.cleanup.unstack_on_failure == true` AND failed → run `./unstack.sh`
- **Default (both false): leave DevStack running.** Do not unstack automatically.

---

## Configuration

Read `config.json` adjacent to this SKILL.md. Key sections:
- `ssh.*` — connection settings (resolved from env vars)
- `devstack.*` — branch, timeout, passwords
- `vm_lock.*` — stale_timeout_hours, lock path
- `deployment_cache.*` — fingerprint path
- `service_tiers.*` — core services, full-trigger patterns
- `service_devstack_mapping` — service → DevStack service names + plugin lines
- `feasibility.*` — unsupported_backends, unsupported_features
- `tempest_plugin_repos` — plugin git URLs
- `test_execution.*` — timeout, concurrency
- `log_collection.*` — max_log_lines, local_storage_path
- `cleanup.*` — cleanup_after_verification, unstack_on_failure

For root cause taxonomy: `references/error-categories.md`
