# Implement Tempest Tests Skill

Implementation skill for creating Tempest test coverage from requirements.

## Purpose

**Implementation focused** - Takes requirements and implements complete, validated tests.

Use this skill for:
- ✅ Implementing tests from analyzed requirements
- ✅ Direct implementation from Jira tickets
- ✅ Manual implementation from provided requirements
- ✅ Following discovered patterns strictly
- ✅ Complete validation and git workflow

**NOT for analysis** - Use `jira-coverage-analysis` for deep analysis first (recommended).

## Features

- **Pattern-based:** Discovers and follows existing patterns
- **Standards-compliant:** Strict Tempest HACKING adherence
- **Validated:** Automatic tox pep8 + py3
- **Git workflow:** Branch + commit (no auto-push)
- **Mandatory recap:** Precise final summary with exact paths

## Quick Start

### From Jira Ticket

```bash
/implement-tempest-tests RHEL-12345
```

**Does:**
- Fetches ticket (via MCP if available)
- Discovers patterns
- Implements tests
- Validates with tox
- Creates git commit
- Provides mandatory recap

### From Manual Requirements

```bash
/implement-tempest-tests

Requirements:
- Service: Cinder
- Feature: Volume multi-attach RBAC
- Tests: admin, member, reader roles
```

### After Analysis

```bash
# First: Analyze
/jira-coverage-analysis RHEL-12345

# Review analysis...

# Then: Implement
/implement-tempest-tests RHEL-12345
```

Uses analysis findings for faster implementation.

## Output Example

```markdown
# Tempest Test Implementation: RHEL-12345

## Implementation Details
- File: cinder_tempest_plugin/api/volume/test_volume_multiattach_rbac.py (created)
- Class: VolumeMultiAttachRbacTest
- Tests: 3 methods implemented

## Validation
- ✅ pep8: PASSED
- ✅ py3: PASSED (3/3 tests)

## Git
- Branch: tempest-coverage-rhel-12345
- Commit: Created
- Status: Ready for review

========================
FINAL RECAP
========================

### 1. Work Performed
Ticket: RHEL-12345
Service: Cinder
Implementation: 3 RBAC tests for volume multi-attach

### 2. Implementation Details

Files Created:
- Absolute: /Users/.../cinder-tempest-plugin/cinder_tempest_plugin/api/volume/test_volume_multiattach_rbac.py
- Relative: cinder_tempest_plugin/api/volume/test_volume_multiattach_rbac.py

Class: VolumeMultiAttachRbacTest (inherits BaseVolumeTest)

Methods:
1. test_volume_multiattach_admin_authorized()
2. test_volume_multiattach_member_authorized()
3. test_volume_multiattach_unauthorized_negative()

### 3. Code Location
Repository: cinder-tempest-plugin
Directory: cinder_tempest_plugin/api/volume/
File: test_volume_multiattach_rbac.py

How to run:
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
tox -e py3 -- cinder_tempest_plugin.api.volume.test_volume_multiattach_rbac

### 4. Coverage Results
Before: No RBAC tests
After: Full RBAC coverage (admin, member, reader)
Gaps remaining: None for current scope

### 5. Validation
- ✅ pep8: PASSED
- ✅ py3: PASSED
- ✅ Cleanup: Verified
- ✅ Git: Branch created, commit ready

### 6. Next Steps
1. Review: git diff main
2. Test: tox
3. Submit: git review

========================
END OF RECAP
========================
```

## Workflow

```
User provides requirements
         ↓
[Get requirements - Jira/manual/analysis]
         ↓
[Find repository]
         ↓
[Discover patterns - Explore agent]
         ↓
[Implement tests]
         ↓
[Create git branch + commit]
         ↓
[Validate with tox]
         ↓
[Mandatory final recap]
         ↓
✅ Ready for review
```

## Standards Enforced

### ✅ MUST DO:
- Use proper base classes (discovered from existing tests)
- Use Tempest clients (NO raw API calls)
- Use waiters (NO sleep!)
- Proper cleanup (addCleanup for all resources)
- Test independence (parallel-safe)
- Proper decorators (@decorators.idempotent_id, @decorators.attr)
- Validate with tox before complete

### ❌ NEVER DO:
- Invent new frameworks
- Use requests.get/post directly
- Use time.sleep()
- Skip cleanup
- Skip validation
- Push code automatically
- Modify main/master directly

## Integration with Analysis Skill

### Two-Step Workflow (Recommended)

```bash
# Morning: Analyze all tickets
/jira-coverage-analysis RHEL-12345 RHEL-12346 RHEL-12347

# Review analyses, prioritize

# Afternoon: Implement high-priority
/implement-tempest-tests RHEL-12345
```

**Benefits:**
- Fast analysis (seconds) for many tickets
- Implement only approved/prioritized tickets
- Clear separation: planning vs. implementation

### One-Step Workflow (Quick)

```bash
# Direct implementation
/implement-tempest-tests RHEL-12345
```

**Does quick analysis internally, then implements.**

## Configuration

Shares configuration with `jira-coverage-analysis` and `tempest-coverage`:
- **File:** `~/.claude/skills/tempest-coverage/config.json`
- Same Jira MCP setup
- Same repository paths
- Same service mappings
- Same templates

See main tempest-coverage documentation for configuration details.

## Output Guarantees

Every implementation provides:
- ✅ Complete test implementation
- ✅ Git branch and commit
- ✅ Validation results (pep8 + py3)
- ✅ **Mandatory final recap** with:
  - Exact file paths (absolute + relative)
  - Exact class and method names
  - Coverage before/after
  - Validation results
  - Next steps
- ✅ Ready for user review
- ✅ No auto-push (user controls submission)

## Performance

- **Single ticket:** 5-10 minutes (includes validation)
- **Multiple tickets:** Sequential, ~10 min each
- **Manual requirements:** 5-10 minutes

Slower than analysis (includes code gen + validation) but comprehensive.

## Mandatory Final Recap

**Every execution includes precise recap:**

```markdown
========================
FINAL RECAP
========================

1. Work Performed (what was done)
2. Implementation Details (exact paths, classes, methods)
3. Code Location (how to find and run)
4. Coverage Results (before/after, gaps)
5. Validation (pep8, py3, cleanup)
6. Assumptions & Risks (what was assumed, potential issues)
7. Next Steps (concrete actions for user)

========================
```

**Never vague** - always exact file paths, method names, and details.

## Use Cases

### After Sprint Planning

```bash
# QE lead analyzed tickets
# Assigned RHEL-12345 to you

# Implement it
/implement-tempest-tests RHEL-12345
```

### Direct Implementation

```bash
# You know what's needed
/implement-tempest-tests

Requirements: Cinder volume RBAC tests
```

### From Design Doc

```bash
# Have design doc with requirements
/implement-tempest-tests

[Paste requirements from design doc]
```

## See Also

- **jira-coverage-analysis** - Analyze first (recommended)
- **tempest-coverage** - Original combined skill (deprecated)

## Documentation

- **skill.md** - Complete workflow (skill definition)
- **Shared config:** See tempest-coverage/config.json
- **Shared templates:** See tempest-coverage/templates/

---

**Pattern-based, validated, production-ready test implementation! 🔧**
