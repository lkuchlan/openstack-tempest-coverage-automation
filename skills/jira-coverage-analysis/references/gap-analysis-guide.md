# Gap Analysis Guide

Detailed reference for STEP 4 (Gap Analysis), STEP 5 (Effort Estimation), and batch analysis.

---

## Gap Analysis Framework (STEP 4)

### Analysis Dimensions

1. **Scenario Coverage:**
   - ✅ What scenarios ARE tested (from MERGED tests)
   - ❌ What scenarios are MISSING (focus on critical gaps only)
   - ⚠️ What scenarios are PARTIALLY tested

2. **Test Types (add only if specifically needed):**
   - Core functionality (what the ticket requires) — always
   - RBAC tests — only if ticket mentions permissions
   - Negative tests — only if error handling is the issue
   - Scale/stress tests — only if ticket mentions performance

3. **Quality Assessment:**
   - Do tests use proper base classes?
   - Do tests use Tempest clients (not raw HTTP)?
   - Do tests use waiters (not `time.sleep`)?
   - Do tests have proper cleanup?

4. **Priority:**
   - HIGH — directly addresses the ticket requirement
   - MEDIUM — related scenarios mentioned in ticket
   - LOW — nice-to-have (often skip)

### Focused Coverage Examples

**Ticket about concurrent bootable volume creation:**
```
✅ GOOD: 2 tests
  - test_concurrent_boot_10_instances (reproduces the bug scenario)
  - test_concurrent_boot_20_instances_stress (validates at scale)

❌ TOO MANY: 5+ tests
  - test_concurrent_boot_10_instances
  - test_concurrent_boot_20_instances
  - test_cinder_api_timeout_during_boot
  - test_cinder_connection_failure_recovery
  - test_batch_boot_varying_volume_sizes
```

**Ticket about RBAC for volume multi-attach:**
```
✅ GOOD: 3 tests (one per role)
  - test_volume_multiattach_admin_authorized
  - test_volume_multiattach_member_authorized
  - test_volume_multiattach_reader_denied

❌ TOO MANY: 6+ tests with minor variations
```

---

## Effort Estimation (STEP 5)

| Scope | Tests | Estimate |
|-------|-------|---------|
| Simple | 1-2 tests, existing patterns | 2-3 hours |
| Medium | 3-5 tests, new patterns needed | 4-6 hours |
| Complex | 6+ tests, scenario tests, multi-service | 1-2 days |

**Complexity factors:**
- LOW: Nearly identical tests exist in the same file → copy pattern
- MEDIUM: New test patterns needed, moderate API complexity
- HIGH: New framework, complex multi-step setup, multi-service interactions

**Blockers to identify:**
- Missing repository (note in report)
- API not yet implemented in the target branch
- Requires a feature flag/config option
- Requires multi-node or specialized backend (→ VERIFICATION_SKIPPED when run)

---

## Batch Analysis

```bash
/jira-coverage-analysis RHEL-12345 RHEL-12346 RHEL-12347
```

- Process each ticket separately (individual report per ticket)
- Produce a combined summary at the end:
  - Total gaps across all tickets
  - Total estimated effort
  - Priority distribution (HIGH/MEDIUM/LOW)
  - Recommended implementation order (highest priority first)

---

## Memory & Learning

After each analysis, save to memory:

1. **Reference:** Service → Plugin mapping, common gap patterns per service
   - Example: "Cinder tickets often missing RBAC coverage for admin-only operations"

2. **Feedback:** Analysis patterns that were accurate, effort estimates that matched reality
   - Example: "RBAC tests for Cinder typically take 4-6 hours"

3. **Project:** Ongoing coverage initiatives, team focus areas
   - Example: "Team is focused on RBAC coverage across all services this sprint"

---

## Recommendations Format (STEP 6)

For each gap identified, provide:

1. **Which repository** to implement in (main Tempest vs. service plugin)
   - Core API operations (CRUD, attach, extend, upload) → main Tempest
   - Service-specific (replication, backends, advanced RBAC) → service plugin

2. **Which file** to add to (existing preferred; create new if no match)

3. **Which base class** to inherit from (from STEP 3 discovery)

4. **Which clients** to use (from STEP 3 discovery)

5. **Priority order** for implementation
