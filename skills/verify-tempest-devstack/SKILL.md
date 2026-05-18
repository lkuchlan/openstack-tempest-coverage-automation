---
name: verify-tempest-devstack
description: Deploy DevStack on a VM and verify Tempest tests against a real OpenStack environment
trigger: User wants to verify Tempest tests on a real DevStack deployment or the orchestrator needs verification after implementation
model: sonnet
---

# DevStack Tempest Verification Skill

You are an OpenStack QE engineer verifying Tempest tests against a real DevStack environment.

Your mission: Take implemented tests (from `implement-tempest-tests` or a local branch), deploy DevStack on a remote VM, run the tests against real OpenStack APIs, and report results. On failure, produce structured feedback for the implementation skill to fix issues.

## Purpose

This skill is for:
- **Verifying tests** on a real OpenStack deployment (not just tox/unit tests)
- **Deploying DevStack** from scratch with the correct services enabled
- **Detecting real-world failures** that unit tests miss (auth, API versions, extensions)
- **Providing structured feedback** to the implementation skill when tests fail
- **Measuring coverage increase** against the analysis baseline

**NOT for implementation** — Use `implement-tempest-tests` to write tests first.

---

## Execution Workflow

### STEP 0: Load Configuration and Parse Input

**Actions:**

1. **Parse user input** to determine operating mode:
   ```
   /verify-tempest-devstack TICKET-ID
   /verify-tempest-devstack TICKET-ID --service cinder --test-module cinder_tempest_plugin.tests.api.test_feature
   /verify-tempest-devstack TICKET-ID --retry-context '{"failed_tests": [...]}'
   /verify-tempest-devstack TICKET-ID --skip-deploy   # Reuse existing DevStack
   ```

2. **Load config** from this skill's `config.json`:
   ```bash
   # Read the config.json adjacent to this SKILL.md
   ```

3. **Resolve environment variables:**
   
   Config values prefixed with `"env:"` must be resolved from environment variables before use:
   ```bash
   # For each config value starting with "env:":
   #   "env:DEVSTACK_HOST" → read $DEVSTACK_HOST from environment
   #   "env:DEVSTACK_USER" → read $DEVSTACK_USER from environment
   #   etc.
   echo $DEVSTACK_HOST
   echo $DEVSTACK_USER
   echo $DEVSTACK_SSH_KEY
   echo $DEVSTACK_ADMIN_PASSWORD
   ```
   
   **If any required env var is not set:**
   - Report error: "Environment variable {VAR_NAME} is not set. See examples/.env.example for setup instructions."
   - STOP execution
   
   **Required env vars:** `DEVSTACK_HOST`, `DEVSTACK_USER`, `DEVSTACK_SSH_KEY`
   **Optional env vars:** `DEVSTACK_ADMIN_PASSWORD`, `DEVSTACK_DB_PASSWORD`, `DEVSTACK_RABBIT_PASSWORD`, `DEVSTACK_SERVICE_PASSWORD` (see `examples/.env.example` for defaults)

4. **Validate SSH connectivity:**
   ```bash
   ssh -i {config.ssh.key_path} -p {config.ssh.port} {config.ssh.options} \
       -o ConnectTimeout={config.ssh.connect_timeout} \
       {config.ssh.user}@{config.ssh.host} "echo 'SSH connection OK'"
   ```
   - If SSH fails: report error with troubleshooting steps, STOP execution
   - Verify SSH key file exists locally: `ls -la {config.ssh.key_path}`

4. **If `--retry-context` provided:**
   - This is a re-verification after a fix cycle
   - Parse the retry context JSON
   - Note which tests previously failed
   - Will compare against previous results in STEP 6

5. **If `--skip-deploy` provided:**
   - Skip STEP 2 (DevStack deployment)
   - Assume DevStack is already running on the VM
   - Verify with: `ssh ... "source /opt/stack/devstack/openrc admin admin && openstack service list"`

**Tool Usage:**
- **Read** (config.json)
- **Bash** (SSH connectivity test, key file check)

**Output:**
- Configuration loaded
- SSH connectivity confirmed
- Operating mode determined (fresh deploy, skip-deploy, retry)
- Ticket ID and service identified

---

### STEP 1: Parse Test Code for Required Services and Extensions

**Actions:**

This step runs LOCALLY — analyze the test files to determine what DevStack services and extensions are needed.

1. **Locate test files:**
   - If test file paths provided as argument: use those directly
   - If ticket ID provided: find the feature branch and identify changed files:
     ```bash
     cd {plugin_repo_path}
     git diff main --name-only | grep "test_"
     ```
   - Read each test file using the Read tool

2. **Parse for required services:**
   ```bash
   # Find service availability checks
   grep -n "CONF.service_available" {test_files}
   grep -n "is_service_enabled" {test_files}

   # Find skip_checks methods
   grep -A 10 "def skip_checks" {test_files}

   # Find credential requirements
   grep -n "credentials = " {test_files}
   ```

3. **Parse for required API extensions:**
   ```bash
   # Find extension checks
   grep -n "CONF.*_feature_enabled" {test_files}
   grep -n "api_extensions" {test_files}
   grep -n "required_extensions" {test_files}
   ```

4. **Parse for required config options:**
   ```bash
   # Find all CONF references
   grep -n "CONF\." {test_files} | grep -v "^#"
   ```

5. **Build requirements list:**
   ```json
   {
     "services": ["cinder", "nova", "glance"],
     "extensions": ["multiattach", "volume-encryption"],
     "credentials": ["admin", "primary", "alt"],
     "config_options": {
       "volume_feature_enabled": {"extend_attached_volume": true}
     }
   }
   ```

6. **Determine service tier (minimal vs. full):**
   
   Scan test code for patterns from `config.service_tiers.full_triggers.patterns`:
   ```bash
   grep -n "servers_client\|create_server\|networks_client\|create_network\|create_port\|attach_volume\|detach_volume" {test_files}
   ```
   
   - If ANY full-trigger pattern found → **full tier**: enable `full_services` + `requires_for_full` dependencies
   - If NO full-trigger patterns → **api-only tier**: enable only `api_only_services` (faster deploy, fewer resources)
   
   Add tier to requirements:
   ```json
   {
     "services": ["cinder"],
     "tier": "api-only",
     "devstack_services": "key,placement-api,c-api,c-vol,c-sch"
   }
   ```

**Tool Usage:**
- **Bash** (grep for patterns)
- **Read** (examine test files)

**Output:**
- List of required OpenStack services
- List of required API extensions
- Required credential types
- Config options needed
- Service tier (api-only or full)
- Exact list of DevStack services to enable

---

### STEP 1.5: Feasibility Check

**Purpose:** Determine if DevStack can provide the environment the tests need. Some tests require backends, hardware, or multi-node setups that DevStack cannot provide.

**Actions:**

1. **Check for unsupported backend requirements:**
   ```bash
   grep -in "CONF.volume.backend_name\|CONF.share.backend_names\|CONF.volume.vendor_name" {test_files}
   ```
   If found, extract the backend name. Check against `config.feasibility.unsupported_backends` list. If the backend is unsupported (ceph, netapp, etc.), the environment is **not feasible**.

2. **Check for multi-node requirements:**
   ```bash
   grep -in "min_compute_nodes\|CONF.compute.min_compute_nodes" {test_files}
   ```
   If the test requires more than 1 compute node, DevStack (single node) **cannot** satisfy this.

3. **Check for unsupported hardware/features:**
   ```bash
   grep -in "sr-iov\|sriov\|dpdk\|gpu\|vtpm\|pci_passthrough\|live_migration" {test_files}
   ```
   Check matches against `config.feasibility.unsupported_features`.

4. **Decision:**
   
   - If **feasible** → proceed to STEP 2
   - If **not feasible** → return immediately with:
     ```json
     {
       "verification_status": "SKIPPED",
       "ticket_id": "OSPRH-12345",
       "skip_reason": "DevStack cannot provide {requirement}. Manual verification on a real deployment is needed.",
       "unsupported_requirements": ["ceph backend", "min_compute_nodes > 1"]
     }
     ```
     Generate the verification report (STEP 7) with SKIPPED status and stop. Do NOT deploy.

**Tool Usage:**
- **Bash** (grep for patterns)
- **Read** (test files, config)

**Output:**
- Feasibility decision: proceed or skip
- If skipped: reason and list of unsupported requirements

---

### STEP 2: Deploy DevStack on VM

**CRITICAL: This step takes 30-60 minutes. Handle timeouts carefully.**

**If `--skip-deploy` flag is set, skip to the VM lock acquisition (step 1) and topology cache check (step 2), then skip to STEP 3.**

**Actions:**

1. **Acquire VM lock:**

   Prevent concurrent tickets from clobbering each other's deployment. Before any deployment or test execution:
   ```bash
   ssh -i {key} {options} {user}@{host} "cat /opt/stack/.devstack-lock 2>/dev/null"
   ```
   
   - **If lock exists AND was created < `config.vm_lock.stale_timeout_hours` hours ago:**
     Another ticket is using the VM. Return immediately:
     ```json
     {
       "verification_status": "DEFERRED",
       "ticket_id": "OSPRH-12345",
       "reason": "VM locked by {locked_ticket_id} since {lock_timestamp}. Will retry next run."
     }
     ```
     The orchestrator keeps the ticket at `IMPLEMENTING` and retries next run.
   
   - **If lock doesn't exist OR is stale (older than timeout):**
     Acquire the lock:
     ```bash
     ssh -i {key} {options} {user}@{host} "echo '{\"ticket_id\": \"{ticket_id}\", \"locked_at\": \"{ISO-8601 now}\"}' > /opt/stack/.devstack-lock"
     ```
     Proceed with deployment/verification.
   
   - **After verification completes (pass, fail, or error):**
     Always release the lock in the cleanup phase:
     ```bash
     ssh -i {key} {options} {user}@{host} "rm -f /opt/stack/.devstack-lock"
     ```

2. **Check deployment cache (topology reuse):**

   If `config.deployment_cache.enabled` is true, check if a compatible environment is already deployed:
   ```bash
   ssh -i {key} {options} {user}@{host} "cat {config.deployment_cache.fingerprint_path} 2>/dev/null"
   ```
   
   If the fingerprint file exists, parse it and compare:
   - Are all required services (from STEP 1) a **subset** of the deployed services?
   - Does the DevStack branch match?
   
   If topology matches, verify services are actually running:
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "source /opt/stack/devstack/openrc admin admin && openstack service list -f json 2>/dev/null"
   ```
   
   - If topology matches AND services are running → **skip deployment** (log: "Reusing existing DevStack deployment from {fingerprint.deployed_at}"). Jump to STEP 3.
   - If topology doesn't match OR services are down → proceed with fresh deployment below.

2. **Clean previous deployment (if any):**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "if [ -d /opt/stack/devstack ]; then cd /opt/stack/devstack && ./unstack.sh 2>/dev/null; sudo rm -rf /opt/stack/devstack /opt/stack/logs; fi"
   ```

3. **Clone DevStack repository:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "git clone {config.devstack.git_url} -b {config.devstack.branch} /opt/stack/devstack"
   ```

4. **Get VM IP address:**
   ```bash
   ssh -i {key} {options} {user}@{host} "hostname -I | awk '{print \$1}'"
   ```

5. **Generate local.conf (using service tier from STEP 1):**

   Build `local.conf` content based on STEP 1 requirements, the determined **service tier**, and `config.service_devstack_mapping`:
   
   - **api-only tier:** Only enable `config.service_tiers.core.services` + the target service's `api_only_services`
   - **full tier:** Enable `config.service_tiers.core.services` + the target service's `full_services` + all `requires_for_full` dependencies

   ```ini
   [[local|localrc]]
   ADMIN_PASSWORD={config.devstack.admin_password}
   DATABASE_PASSWORD={config.devstack.database_password}
   RABBIT_PASSWORD={config.devstack.rabbit_password}
   SERVICE_PASSWORD={config.devstack.service_password}
   HOST_IP={vm_ip}
   RECLONE={config.devstack.reclone}

   # Core services (always enabled)
   enable_service {config.service_tiers.core.services}

   # Target service (tier-dependent: api_only_services or full_services)
   enable_service {tier_services}

   # Dependencies (only for full tier)
   enable_service {dependency_services}

   # Service-specific (from STEP 1 + config mapping)
   enable_service {mapped_services}

   # Plugins (if service requires them)
   {plugin_enable_lines}

   # Extra config (from service mapping)
   {extra_config_lines}

   # Tempest
   enable_service tempest

   [[post-config|$NOVA_CONF]]
   [DEFAULT]
   # Any extension-specific config from STEP 1

   [[post-config|${SERVICE}_CONF]]
   # Extension-specific config options
   ```

   Transfer to VM:
   ```bash
   ssh -i {key} {options} {user}@{host} "cat > /opt/stack/devstack/local.conf << 'LOCALCONF'
   {generated_local_conf}
   LOCALCONF"
   ```

5. **Apply Ubuntu 22.04 (jammy) workarounds if needed:**

   Before running stack.sh, detect the OS version and apply workarounds if needed:
   ```bash
   ssh -i {key} {options} {user}@{host} "lsb_release -cs"
   ```
   
   **If result is `jammy` (Ubuntu 22.04),** apply these workarounds automatically:
   
   | # | Workaround | Why |
   |---|-----------|-----|
   | 1 | Install Python 3.11 from deadsnakes PPA | DevStack stable/2025.1+ needs >= 3.11 |
   | 2 | Create venv with `python3.11 -m venv` + `pip install uwsgi` | System uwsgi plugin compiled for 3.10 |
   | 3 | Replace `/usr/bin/uwsgi` with pip-installed version | Match Python version in venv |
   | 4 | Patch `lib/apache`: remove `plugins http,python3` lines | pip uwsgi has Python built in |
   | 5 | Patch `lib/keystone`, `lib/nova`, `lib/cinder`: use `write_local_uwsgi_http_config` | HTTP sockets bypass mod_proxy_uwsgi incompatibility |
   | 6 | Patch `functions`: fix `get_random_port` to use incrementing counter | Prevents port collisions in HTTP mode |
   | 7 | Disable Apache `mod_wsgi` | Compiled for Python 3.10, crashes with 3.11 venv |
   | 8 | `pip install libvirt-python` in venv | System package only covers Python 3.10 |
   
   **If result is `noble` (Ubuntu 24.04) or later:** No workarounds needed. DevStack works natively.
   
   **Recommended:** Use Ubuntu 24.04 (noble) VMs to avoid all workarounds.

6. **Run stack.sh (background execution):**

   Since `stack.sh` takes 30-60 minutes and exceeds the Bash tool's timeout:

   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/devstack && nohup bash -c './stack.sh > /tmp/stack-output.log 2>&1 && touch /tmp/stack-done || touch /tmp/stack-failed' &"
   ```

   Run this with `run_in_background: true` on the Bash tool.

6. **Poll for completion:**

   Check periodically for the marker files:
   ```bash
   ssh -i {key} {options} {user}@{host} "ls /tmp/stack-done /tmp/stack-failed 2>/dev/null; tail -5 /tmp/stack-output.log 2>/dev/null"
   ```

   Use **ScheduleWakeup** with 270-second intervals (stays within cache window) to poll. Continue polling until either `/tmp/stack-done` or `/tmp/stack-failed` appears, or `config.devstack.deploy_timeout` is exceeded.

7. **Verify deployment success:**

   If `stack-done` marker found:
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "source /opt/stack/devstack/openrc admin admin && openstack service list -f json"
   ```
   - Parse the service list JSON
   - Verify all required services from STEP 1 are present
   - If a required service is missing: report as deployment failure with details

   **On success — write topology fingerprint:**
   ```bash
   ssh -i {key} {options} {user}@{host} "cat > {config.deployment_cache.fingerprint_path} << 'TOPO'
   {
     \"services\": [\"cinder\", \"glance\", \"keystone\", \"nova\", \"placement\"],
     \"branch\": \"{config.devstack.branch}\",
     \"deployed_at\": \"{current ISO-8601 timestamp}\",
     \"ticket_id\": \"{ticket_id}\",
     \"tier\": \"{api-only|full}\"
   }
   TOPO"
   ```
   This allows future tickets with the same service requirements to skip deployment.

   **If `stack-failed` marker found or timeout exceeded → DEPLOYMENT_FAILED:**
   ```bash
   ssh -i {key} {options} {user}@{host} "tail -100 /opt/stack/logs/stack.sh.log 2>/dev/null || tail -100 /tmp/stack-output.log"
   ```
   - Capture failure logs
   - Return with `verification_status: "DEPLOYMENT_FAILED"` (NOT `"FAILED"` — this is an infrastructure issue, not a test code issue)
   - The orchestrator will NOT trigger the fix+retry loop for deployment failures
   - Include deployment error details in the response:
     ```json
     {
       "verification_status": "DEPLOYMENT_FAILED",
       "ticket_id": "OSPRH-12345",
       "deployment_error": "stack.sh failed at keystone startup",
       "deployment_logs": "... last 100 lines ...",
       "suggested_action": "Check VM resources, network connectivity, and OS compatibility"
     }
     ```
   - Skip remaining steps, generate verification report with DEPLOYMENT_FAILED status

**Tool Usage:**
- **Bash** (all SSH commands)
- **Bash (run_in_background)** (stack.sh execution)
- **ScheduleWakeup** (poll for completion at ~270s intervals)

**Output:**
- DevStack deployed and running
- All required services verified as available
- VM IP and admin credentials confirmed
- OR: Deployment failure report with logs

---

### STEP 3: Install Tempest and Plugin on VM

**Actions:**

1. **Install Tempest:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack && if [ ! -d tempest ]; then git clone https://opendev.org/openstack/tempest.git; fi && cd tempest && pip install -e ."
   ```

2. **Install the service's Tempest plugin:**

   Look up the plugin repo URL from `config.tempest_plugin_repos`:
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack && if [ ! -d {plugin_name} ]; then git clone {plugin_repo_url}; fi && cd {plugin_name} && pip install -e ."
   ```

3. **Copy test files from local to VM:**

   Transfer the implemented test files using `scp`:
   ```bash
   scp -i {key} -P {port} {ssh_options} \
       {local_test_file} \
       {user}@{host}:/opt/stack/{plugin_name}/{relative_path}
   ```

   For each test file that was created/modified by `implement-tempest-tests`.

4. **Generate Tempest configuration:**
   ```bash
   # Use DevStack's built-in tempest config generation
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/tempest && discover-tempest-config --deployer-input /opt/stack/devstack/tempest-deployer-input.conf --out etc/tempest.conf 2>/dev/null || tox -e tempest-generate-config"
   ```

5. **Verify Tempest can discover the tests:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/tempest && tempest run --list-tests 2>/dev/null | grep '{test_module_pattern}'"
   ```
   - If tests are not discovered: report error with troubleshooting suggestions
   - Possible causes: plugin not installed correctly, import errors in test code

**Tool Usage:**
- **Bash** (SSH commands, SCP)

**Output:**
- Tempest installed on VM
- Plugin installed on VM
- Test files transferred
- tempest.conf generated
- Tests discoverable by Tempest runner

---

### STEP 4: Execute Tests

**Actions:**

1. **Run the specific tests:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/tempest && source /opt/stack/devstack/openrc admin admin && tempest run --regex '{test_module_regex}' --concurrency {config.test_execution.concurrency} 2>&1"
   ```

   Use Bash tool with `timeout: {config.test_execution.timeout * 1000}` milliseconds (default: 1800000 = 30 min).

   If the timeout is too large for a single Bash call, use the same nohup + poll pattern as STEP 2:
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/tempest && source /opt/stack/devstack/openrc admin admin && nohup bash -c 'tempest run --regex \"{test_module_regex}\" --concurrency {concurrency} > /tmp/tempest-output.log 2>&1 && touch /tmp/tempest-done || touch /tmp/tempest-failed' &"
   ```

2. **Collect subunit results (if enabled):**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/tempest && stestr last --subunit 2>/dev/null | subunit2pyunit 2>/dev/null || cat /tmp/tempest-output.log"
   ```

3. **Parse test output:**
   - Count: total, passed, failed, skipped, errors
   - For each failed test: extract method name, error type, error message, traceback
   - For each skipped test: extract skip reason

**Tool Usage:**
- **Bash** (SSH commands with timeout)
- **Bash (run_in_background)** (if test run exceeds 10 min)

**Output:**
- Raw test output captured
- Pass/fail/skip/error counts
- Detailed failure information (if any)

---

### STEP 5: Collect Results and Logs

**Actions:**

1. **Parse test results into structured format:**
   ```json
   {
     "total": 5,
     "passed": 3,
     "failed": 1,
     "skipped": 1,
     "errors": 0,
     "duration": "45.2s",
     "tests": [
       {"name": "test_method_1", "status": "PASSED", "duration": "8.3s"},
       {"name": "test_method_2", "status": "FAILED", "duration": "12.1s",
        "error_type": "AssertionError",
        "error_message": "Expected 'available', got 'error'",
        "traceback": "..."},
       {"name": "test_method_3", "status": "SKIPPED", "reason": "Extension not available"}
     ]
   }
   ```

2. **Collect service logs (if enabled in config):**
   ```bash
   # For each relevant service
   ssh -i {key} {options} {user}@{host} \
       "tail -{config.log_collection.max_log_lines} /opt/stack/logs/{service}.log 2>/dev/null"
   ```

3. **Collect journald logs (if enabled):**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "journalctl -u 'devstack@*' --since '1 hour ago' --no-pager 2>/dev/null | tail -{config.log_collection.max_log_lines}"
   ```

4. **Collect DevStack deployment log:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "tail -{config.log_collection.max_log_lines} /opt/stack/logs/stack.sh.log 2>/dev/null"
   ```

5. **Save results locally:**
   ```bash
   mkdir -p {config.log_collection.local_storage_path}/{ticket_id}
   ```
   Use Write tool to save:
   - `{local_storage_path}/{ticket_id}/test-results.json` — structured test results
   - `{local_storage_path}/{ticket_id}/test-output.log` — raw test output
   - `{local_storage_path}/{ticket_id}/service-logs.log` — collected service logs

**Tool Usage:**
- **Bash** (SSH log collection, mkdir)
- **Write** (save results locally)

**Output:**
- Structured test results
- Service logs collected
- All data saved locally for reference

---

### STEP 6: Measure Coverage Increase

**Actions:**

1. **Read analysis baseline:**
   - Check orchestrator state for this ticket's analysis:
     ```bash
     cat ~/.claude/orchestrator-state/tickets/{ticket_id}.json
     ```
   - Extract: number of gaps identified, existing test count

2. **Calculate coverage delta:**
   - New tests run: count from STEP 5
   - New tests passing: passed count from STEP 5
   - Gaps addressed: compare against analysis gaps
   - Coverage increase: (new passing tests / total gaps identified) * 100

3. **If retry context provided:**
   - Compare current results against previous failed results
   - Note which previously-failed tests now pass
   - Note any new failures

**Tool Usage:**
- **Read** (orchestrator state files)
- **Bash** (cat state file)

**Output:**
- Coverage delta (before vs. after)
- Gaps addressed
- Percentage increase

---

### STEP 7: Generate Verification Report

**MANDATORY: Always generate this report, regardless of pass or fail.**

**Format:**

```markdown
================================================================
DEVSTACK VERIFICATION REPORT
================================================================

### Ticket: {TICKET-ID}
### Service: {service}
### Overall Status: PASSED / FAILED
### Verification Attempt: {attempt_number} of {max_attempts}

---

### DevStack Deployment
- VM: {user}@{host}
- DevStack Branch: {devstack_branch}
- Services Enabled: {service_list}
- Deployment Duration: {duration}
- Deployment Status: SUCCESS / FAILED

### Test Execution
- Tests Run: {total}
- Passed: {passed}
- Failed: {failed}
- Skipped: {skipped}
- Errors: {errors}
- Execution Duration: {duration}

### Test Results Detail
| # | Test Method | Status | Duration |
|---|-------------|--------|----------|
| 1 | test_method_1() | PASSED | 2.3s |
| 2 | test_method_2() | FAILED | 5.1s |
| 3 | test_method_3() | SKIPPED | 0.1s |

### Failed Tests Detail
(Only if there are failures)

**test_method_2():**
- File: {test_file_path}
- Error Type: {error_type}
- Error Message: {error_message}
- Traceback:
  ```
  {traceback}
  ```
- Likely Cause: {analysis_of_failure}

### Coverage Increase
- Before: {X} existing tests
- After: {X+N} tests (N new)
- Passing: {passed_count} of {total_count}
- Coverage Delta: +{percentage}%

### Logs Location
- Test output: {local_storage_path}/{ticket_id}/test-output.log
- Service logs: {local_storage_path}/{ticket_id}/service-logs.log
- Test results: {local_storage_path}/{ticket_id}/test-results.json

### VM Status
- DevStack: Running / Stopped
- SSH: {user}@{host} (key: {key_path})
- Manual access: ssh -i {key_path} {user}@{host}

================================================================
END OF VERIFICATION REPORT
================================================================
```

**Tool Usage:**
- Output formatted markdown directly

**Output:**
- Complete verification report displayed to user

---

### STEP 8: Return Structured Feedback (If Tests Failed)

**This step only runs if any tests failed.**

**Purpose:** Produce structured feedback that the orchestrator can pass to `implement-tempest-tests` for the retry cycle.

**Actions:**

1. **Analyze each failure:**
   - Identify the root cause category:
     - `missing_config` — Test requires a config option not set in DevStack
     - `api_error` — API returned unexpected error (wrong status, missing field)
     - `extension_unavailable` — Required extension not enabled
     - `auth_error` — Credentials or RBAC issue
     - `timeout` — Waiter or API call timed out
     - `test_logic` — Bug in the test code itself
     - `resource_conflict` — Resource naming or state conflict

2. **Generate feedback JSON:**
   ```json
   {
     "verification_status": "FAILED",
     "ticket_id": "OSPRH-12345",
     "attempt": 1,
     "max_retries": 1,
     "retry_eligible": true,
     "failed_tests": [
       {
         "method": "test_volume_multiattach_admin_authorized",
         "file": "cinder_tempest_plugin/tests/api/volume/test_multiattach_rbac.py",
         "error_type": "AssertionError",
         "error_message": "Expected status 'available', got 'error'",
         "traceback": "...",
         "root_cause_category": "test_logic",
         "likely_cause": "The test creates a multiattach volume but does not set the multiattach flag",
         "suggested_fix": "Add multiattach=True parameter to the create_volume() call"
       }
     ],
     "passed_tests": [
       "test_volume_create_admin_authorized",
       "test_volume_delete_admin_authorized"
     ],
     "environment_info": {
       "devstack_branch": "master",
       "services_available": ["cinder", "nova", "glance"],
       "extensions_available": ["multiattach"],
       "openstack_version": "..."
     }
   }
   ```

3. **If all tests passed:**
   ```json
   {
     "verification_status": "PASSED",
     "ticket_id": "OSPRH-12345",
     "attempt": 1,
     "tests_passed": 3,
     "tests_total": 3,
     "coverage_increase": "+3 tests"
   }
   ```

4. **Save feedback to state directory:**
   ```bash
   # Write to ~/.claude/orchestrator-state/verifications/{ticket_id}/feedback.json
   ```

**Tool Usage:**
- **Write** (save feedback JSON)

**Output:**
- Structured feedback JSON (for orchestrator to pass to implementation skill)
- Feedback saved to disk

---

## Cleanup (Optional — Based on Config)

After verification completes (pass or fail):

1. **If `config.cleanup.cleanup_after_verification` is true:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/devstack && ./unstack.sh && ./clean.sh"
   ```

2. **If `config.cleanup.unstack_on_failure` is true AND verification failed:**
   ```bash
   ssh -i {key} {options} {user}@{host} \
       "cd /opt/stack/devstack && ./unstack.sh"
   ```

3. **Default (both false):** Leave DevStack running for manual inspection.

---

## Error Handling

### SSH Connection Failure
- Report: "Cannot connect to VM at {host}. Verify VM is running and SSH key is valid."
- Suggest: `ssh -i {key_path} -v {user}@{host}` for manual debugging
- Action: STOP execution, return FAILED status

### DevStack Deployment Failure
- Capture: last 100 lines of `stack.sh.log`
- Report: specific failure point and error message
- Action: Return FAILED status with deployment error details, skip test execution

### Test Execution Timeout
- Kill the test run (if possible)
- Capture partial results from output log
- Report: which tests completed, which were interrupted
- Action: Return FAILED status with timeout details

### Service Log Collection Failure
- Warn in report but continue
- Test results are the primary output; logs are supplementary
- Action: Note missing logs in verification report

### File Transfer (SCP) Failure
- Attempt alternative: transfer via SSH heredoc for small files:
  ```bash
  ssh ... "cat > /opt/stack/{plugin}/{path} << 'PYEOF'
  {file_content}
  PYEOF"
  ```
- Action: If transfer fails completely, report FAILED

### Test Discovery Failure (tests not found by Tempest)
- Report: "Tests not discoverable. Possible causes: import errors, plugin not installed, module path incorrect."
- Capture: `tempest run --list-tests` output and any Python import errors
- Action: Return FAILED with discovery error details

---

## Invocation Examples

**Standalone (by user):**
```bash
/verify-tempest-devstack OSPRH-22613

/verify-tempest-devstack OSPRH-22613 --service cinder \
    --test-module cinder_tempest_plugin.tests.api.test_multiattach_rbac

/verify-tempest-devstack OSPRH-22613 --skip-deploy
```

**By orchestrator (via Skill tool):**
```
Skill tool: verify-tempest-devstack
Args: OSPRH-22613 --service cinder --test-module cinder_tempest_plugin.tests.api.test_multiattach_rbac
```

**Retry cycle (by orchestrator after fix):**
```
Skill tool: verify-tempest-devstack
Args: OSPRH-22613 --skip-deploy --retry-context '{...feedback JSON...}'
```

---

## Tool Usage Summary

| Phase | Primary Tools | Purpose |
|-------|---------------|---------|
| Config & SSH | Read, Bash | Load config, validate SSH |
| Parse Tests | Bash (grep), Read | Find required services |
| Deploy DevStack | Bash (SSH), Bash (background) | Remote deployment |
| Install Tempest | Bash (SSH, SCP) | Setup test environment |
| Execute Tests | Bash (SSH with timeout) | Run tests on real API |
| Collect Results | Bash (SSH), Write | Gather logs and results |
| Coverage | Read, Bash | Compare against baseline |
| Report | Direct output | Formatted markdown |
| Feedback | Write | Structured JSON |

---

## Success Criteria

A successful verification includes:
1. SSH connectivity confirmed
2. DevStack deployed with required services
3. Tempest and plugin installed on VM
4. Test files transferred to VM
5. Tests executed against real OpenStack APIs
6. Results collected and structured
7. Coverage delta measured
8. Verification report generated
9. Feedback JSON produced (if failures exist)

---

## Constraints & Rules

### DO:
- Validate SSH before any remote operations
- Clean previous DevStack before fresh deploy
- Enable only the services required by the tests
- Use nohup + polling for long-running commands (stack.sh, long test suites)
- Collect logs even on failure
- Always produce the verification report
- Save all results to local state directory
- Provide actionable feedback on test failures

### DON'T:
- Store SSH keys or passwords in state files or logs
- Auto-retry tests within this skill (orchestrator handles retry loop)
- Modify test code (that's the implementation skill's job)
- Push code or submit patches
- Leave orphaned processes on the VM
- Assume services are available — always verify after deployment
- Ignore partial results on timeout — report whatever completed

---

## Configuration Reference

Read `config.json` (adjacent to this SKILL.md) for all configurable values. Key sections:
- `ssh` — Connection details (MUST be configured before first use)
- `devstack` — Deployment settings (branch, passwords, timeout)
- `service_devstack_mapping` — Service to DevStack service names
- `tempest_plugin_repos` — Git URLs for plugin cloning
- `test_execution` — Timeout, concurrency
- `retry` — Max retries, feedback format
- `log_collection` — Which logs to collect, storage path
- `cleanup` — Whether to unstack after verification

---

END OF SKILL DEFINITION
