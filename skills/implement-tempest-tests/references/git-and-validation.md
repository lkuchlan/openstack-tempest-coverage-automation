# Git Workflow and Validation Reference

Detailed steps for STEP 6 (Git) and STEP 7 (Validation).

---

## STEP 6: Git Workflow

### Commands

```bash
# Ensure repo is current
cd {repo}
git fetch origin
git status

# Create feature branch
git checkout -b tempest-coverage-{ticket-id}

# Stage test files only (not unrelated changes)
git add {test_files}

# Commit
git commit -m "Add Tempest coverage for {feature}

Implements test coverage for {ticket-id}
- test_scenario_1
- test_scenario_2

Closes-Bug: #{ticket-id}

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Verify
git status
git diff main
git log -1 --stat
```

### NEVER rules (non-negotiable)

- ❌ NEVER modify `main` or `master` directly
- ❌ NEVER run `git push` automatically
- ❌ NEVER run `git review` automatically
- ✅ Always create a `tempest-coverage-{ticket-id}` branch
- ✅ Always include `Closes-Bug: #{ticket-id}` in the commit message
- ✅ Always include `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>`
- ✅ Always reference the specific test method names in the commit body

### If branch already exists

If `tempest-coverage-{ticket-id}` already exists (retry cycle):
```bash
git checkout tempest-coverage-{ticket-id}
# Apply fixes to existing files
git add {changed_files}
git commit -m "Fix Tempest standards violations in {feature} tests

Previous violations:
{list violations}

Closes-Bug: #{ticket-id}

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## STEP 7: Validation

### Commands

```bash
# Run pep8 style check (must pass before any commit)
cd {repo}
tox -e pep8 -- {test_file}

# Run unit tests for the new test module
tox -e py3 -- {test_module_path}
# Example:
# tox -e py3 -- cinder_tempest_plugin.api.volume.test_multiattach
```

Both commands must pass. If pep8 fails, fix all violations before committing. If py3 fails, investigate and fix the test logic.

### Common pep8 violations

- Long lines (> 79 characters) — wrap at logical boundaries
- Missing blank line after class docstring
- Import ordering (stdlib, then third-party, then local)
- Trailing whitespace
- Missing whitespace around operators

### Common py3 failures

- Import errors — module path is wrong
- Missing `__init__.py` in a new directory
- Syntax errors in the test file
- Wrong test class name (must match filename convention)
- Missing `@decorators.idempotent_id` — causes test framework error

### Resource cleanup verification (manual check)

Before committing, verify:
1. Every direct `{client}.create_{resource}()` call has a corresponding `addCleanup`
2. Every `self.create_{resource}()` helper does NOT also have an `addCleanup` (duplicate)
3. No test creates resources without any cleanup path
4. Tests do not depend on resources created by other test methods

### Parallel safety check

- No `cls.{attribute}` that is written by one test and read by another
- No file-system state shared between tests
- No global variables modified by tests
