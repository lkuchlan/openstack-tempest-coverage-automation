# Failure Root Cause Categories

Used in STEP 8 to classify each test failure for the structured feedback JSON.

---

## The 7 Categories

| Category | When to use | Common fix |
|----------|------------|------------|
| `missing_config` | Test requires a `CONF.*` option that is not set in the generated tempest.conf, or a DevStack flag that was not enabled | Add the config value to local.conf and re-deploy, or update the test's `skip_checks` to skip when config is absent |
| `api_error` | API returned an unexpected status code, missing field, or wrong value — the test assertion fails due to an API behavior difference | Investigate the API behavior in the DevStack environment; update the assertion or add a skip condition |
| `extension_unavailable` | The test requires an API extension (`required_extensions`, `CONF.*_feature_enabled`) that is not enabled in this DevStack | Add the extension to local.conf `enable_service` or `enable_plugin`, or add a skip condition |
| `auth_error` | Credentials mismatch, RBAC policy denial not expected by the test, or authentication token issue | Check that the correct credential type (`admin`, `primary`, `alt`) is used; verify the RBAC policy aligns with the test expectation |
| `timeout` | A `waiters.wait_for_*` call exceeded its limit, or an API call took too long | Investigate whether the service is slow in DevStack; increase waiter timeout, or check for a resource state that never transitions |
| `test_logic` | The test itself has a bug — wrong parameter, incorrect assertion, resource not created before use, or import error | Fix the test code: wrong client call, missing parameter (e.g., `multiattach=True`), wrong expected value |
| `resource_conflict` | Naming collision, resource already exists, or state conflict from a previous test run that left orphaned resources | Add random suffix to resource names, or clean up orphaned resources on the VM |

---

## Feedback JSON Schema

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
      "likely_cause": "Volume created without multiattach=True flag",
      "suggested_fix": "Add multiattach=True parameter to create_volume() call"
    }
  ],
  "passed_tests": [
    "test_volume_create_admin_authorized"
  ],
  "environment_info": {
    "devstack_branch": "master",
    "services_available": ["cinder", "nova", "glance"],
    "extensions_available": ["multiattach"],
    "openstack_version": "2025.1"
  }
}
```

## Passed JSON Schema

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

---

## Decision Tree: retry_eligible

- `retry_eligible: true` when `root_cause_category` is `test_logic` or `timeout` or `api_error` AND `attempt < max_retries`
- `retry_eligible: false` when category is `extension_unavailable` or `missing_config` that cannot be fixed without redeployment AND `attempt >= max_retries`
- Orchestrator determines actual retry — this field is advisory
