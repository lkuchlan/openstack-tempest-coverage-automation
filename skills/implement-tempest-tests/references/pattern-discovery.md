# Pattern Discovery Reference

Detailed instructions for STEP 3: Discover Implementation Patterns.

---

## What to Search For

Spawn **Agent (Explore, very thorough)** to find in the target plugin repo:

1. **Base test classes** — what class to inherit from
2. **Service clients** — which client attributes to use
3. **Similar existing tests** — templates to follow
4. **Waiter methods** available
5. **Cleanup patterns** used in that service
6. **Helper method implementations** — read the body, not just the signature

## Search Commands

```bash
# Find base classes
grep -r "class Base.*Test" {repo}/

# Find clients
grep -r "self\..*_client" {repo}/tests/

# Find waiters
grep -r "waiters\.wait_for" {repo}/

# Find similar tests
grep -r "test_{similar_operation}" {repo}/tests/

# Find cleanup patterns
grep -r "addCleanup" {repo}/tests/

# Find and READ helper method implementations
grep -rn "def create_volume\|def boot_instance\|def create_snapshot" {repo}/tests/api/base.py
# Then Read each matched file — do not trust signatures alone
```

## Helper Body Reading Rule

**MANDATORY before using any `self.{helper}()` call:**

Read the helper's implementation in the base class. Many helpers already:
- Call waiters internally (e.g., `create_volume` waits for `available`)
- Register `addCleanup` internally

If the helper already does X, adding X again after the call is a violation.

```python
# Example: create_volume already waits AND registers cleanup
volume = self.create_volume()
# DO NOT add:
waiters.wait_for_volume_resource_status(...)  # duplicate
self.addCleanup(...)                           # duplicate
```

## File Selection Rules

### Inbound guard (candidate file has purpose-qualifier suffix)

Check whether the new test belongs to that category:
- `_concurrency` → only tests using `run_concurrent_tasks()` or similar
- `_rbac` → only role-based access control tests
- `_admin` → only tests requiring admin credentials
- `_negative` → only tests for error paths, rejection, failure behavior

If the new test does NOT match the qualifier: reject that file, find or create another.

### Outbound rule (new test IS negative)

Negative tests (`assertRaises`, tests that verify error/rejection behavior) MUST go into a `_negative`-suffixed file:

1. Search for existing `test_{feature}_negative.py` in the same directory
2. If found: add the test there
3. If not found: create `test_{feature}_negative.py`
4. NEVER place a negative test in a non-`_negative` file

### Utility-usage consistency check

If every existing test in the candidate file uses a specific utility (e.g., `run_concurrent_tasks()`) and the new test does NOT, treat this as a mismatch. Find a different file or create a new one.

### Existing class check

Before creating a new class in a chosen file:
1. Look for an existing class that covers the same feature area
2. Add the test method there IF: base class, credential type, and skip conditions are compatible
3. Check `skip_checks`: if the candidate class guards on a condition unrelated to the new test (e.g., `CONF.volume_feature_enabled.concurrency_tests` for a non-concurrency test), find/create a different class

### File vs. class precedence

```
Search existing file in same service area → found?
  YES → check purpose-qualifier → fits?
    YES → check existing class → fits?
      YES → add test method to existing class
      NO  → create new class in existing file
    NO  → find different file or create new
  NO → create new test file
```

## Domain-Specific Knowledge

**Cinder volumes from images:**
Volumes created from an image (`source_type='image'`) are automatically bootable. Do NOT call `set_bootable_volume()` — it is redundant and causes a test failure.

**RBAC test structure:**
RBAC tests use three role credentials: `admin`, `member`, `reader`. Each role gets one test method. See `references/negative-rbac-patterns.md` for the full RBAC pattern.
