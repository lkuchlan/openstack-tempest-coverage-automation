# Usage Examples

Real-world workflows for OpenStack Tempest Coverage Automation.

## Example 1: Analyze and Implement from Jira

**Scenario:** Customer bug requires RBAC test coverage

```bash
claude

# Step 1: Analyze ticket
> /jira-coverage-analysis OSPRH-22613

# Output:
# ✅ Existing: Basic volume tests
# ❌ Missing: RBAC tests for multi-attach (HIGH priority, 4-6 hours)
# 💡 Recommendation: Implement RBAC coverage first

# Step 2: Implement after review
> /implement-tempest-tests OSPRH-22613

# Output:
# ✅ Created: test_volume_multiattach_rbac.py
# ✅ Validated: tox pep8 + py3 passed
# ✅ Branch: tempest-coverage-OSPRH-22613

# Step 3: Review and push
cd ~/automation_projects/cinder-tempest-plugin
git diff HEAD~1
git push origin tempest-coverage-OSPRH-22613
```

## Example 2: Sprint Planning with Batch Analysis

**Scenario:** Plan sprint capacity for 5 tickets

```bash
> /jira-coverage-analysis OSPRH-1 OSPRH-2 OSPRH-3 OSPRH-4 OSPRH-5

# Output:
# Total gaps: 15
# Total effort: 32-40 hours
# Priority distribution:
#   HIGH: 6 gaps (18-22 hours)
#   MEDIUM: 6 gaps (10-14 hours)
#   LOW: 3 gaps (4-6 hours)

# Decision: Assign HIGH priority to sprint, defer LOW
```

## Example 3: Without Jira MCP

**Scenario:** Work without Jira integration

```bash
> /implement-tempest-tests

# Claude prompts:
# - Service name? → Cinder
# - Feature/API? → Volume multi-attach
# - Test scenarios needed? → RBAC tests for admin/member/reader roles
# - Acceptance criteria? → Admin can multi-attach, member can attach own volumes, reader denied

# Same quality implementation as with Jira
```

## Example 4: Pre-commit Hooks in Action

**Scenario:** Hooks catch violations before commit

```bash
cd ~/automation_projects/cinder-tempest-plugin

# Create test with violation
cat > test_example.py << 'EOF'
import time

class TestExample:
    def test_something(self):
        time.sleep(10)  # Violation!
EOF

git add test_example.py
git commit -m "Add test"

# Output:
# 🔍 Checking Tempest standards...
# ❌ Waiter violations in test_example.py:
#    Line 5: Using time.sleep() - Use Tempest waiters
# ❌ Commit blocked

# Fix and retry
# Now uses: waiters.wait_for_volume_resource_status(...)
git commit -m "Add test (fixed)"
# ✅ All checks passed!
```

See [README.md](../README.md) for more workflows and [QUICKSTART.md](QUICKSTART.md) for setup.
