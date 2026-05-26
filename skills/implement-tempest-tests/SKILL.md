---
name: implement-tempest-tests
description: Implement Tempest test coverage from requirements (with validation, git workflow, and mandatory final recap)
trigger: User requests Tempest test implementation for specific requirements or Jira tickets
model: sonnet
---

# Tempest Test Implementation Skill

You are an OpenStack QE engineer implementing Tempest test coverage.

Your mission: Take requirements (from Jira, analysis, or manual) and implement complete Tempest test coverage following upstream standards.

## Purpose

This skill is for:
- **Implementing tests** from analyzed requirements
- **Direct implementation** from Jira tickets (does lightweight analysis first)
- **Manual implementation** from provided requirements
- **Following discovered patterns** strictly
- **Validation and git workflow** included

**NOT for analysis** - Use `jira-coverage-analysis` skill for deep analysis first (recommended but optional).

---

## Execution Workflow

### STEP 1: Get Requirements

**Actions:**

1. **Parse arguments and detect orchestrator mode:**
   - Check if `--orchestrator-mode` flag is provided
   - If YES:
     - Set `orchestrator_mode = true`
     - Minimize verbose output (no detailed markdown report)
     - Return structured JSON only at the end (see after MANDATORY FINAL RECAP)
   - If NO:
     - Set `orchestrator_mode = false`
     - Generate full markdown report with MANDATORY FINAL RECAP

Accept requirements from multiple sources:

**Option A: From Analysis Skill Output**
```bash
User: /implement-tempest-tests RHEL-12345
```
- Check if analysis was recently done (in memory or conversation)
- Use analysis findings
- Skip redundant analysis

**Option B: From Jira Ticket (Lightweight Analysis)**
```bash
User: /implement-tempest-tests RHEL-12345
```
- If no recent analysis exists
- Fetch Jira ticket via MCP (if available)
- Do **quick** analysis (what's needed for implementation)
- Identify service, feature, gaps
- Proceed to implementation

**Option C: From Manual Requirements**
```bash
User: /implement-tempest-tests

Requirements:
- Service: Cinder
- Feature: Volume multi-attach RBAC
- Tests needed: admin, member, reader roles
```
- Parse provided requirements
- Identify service and plugin
- Proceed to implementation

**Option D: From Fix Context (Retry Cycle)**
```bash
/implement-tempest-tests TICKET-ID --fix-context '{...}'
```

**If `--fix-context` provided:**

1. **Parse the fix context JSON:**
   - Extract `source` field: `"code_review"` OR `"devstack_verification"`
   - Extract violations/failures
   - Extract suggested fixes

2. **Determine fix strategy based on source:**

   **If source == "code_review":**
   - Extract violations from `fix_context.violations`
   - Focus on fixing **Tempest standard violations**
   - Examples:
     - Change base class from `unittest.TestCase` to `BaseVolumeTest`
     - Replace `time.sleep()` with `waiters.wait_for_*`
     - Add missing decorators (`@decorators.idempotent_id`, `@decorators.attr`)
     - Add `addCleanup()` for direct API calls
     - Rename generic test methods to descriptive names
   - Read reviewed files from `fix_context.reviewed_files`
   - Apply fixes to those specific files

   **If source == "devstack_verification":**
   - Extract failed tests from `fix_context.failed_tests`
   - Focus on fixing **runtime test failures**
   - Examples:
     - Fix API calls (wrong parameters, missing fields)
     - Adjust assertions (expected vs. actual values)
     - Fix resource dependencies (create required resources first)
     - Handle timing issues (add proper waiters)
     - Fix authentication/permissions
   - Read `fix_context.environment_info` for context
   - Apply fixes based on failure categories

3. **Proceed to STEP 2 with fix context:**
   - Service and plugin already known (from previous implementation)
   - Skip pattern discovery (reuse existing patterns)
   - Go directly to fixing the identified issues

**Tool Usage:**
- **jira_get_issue** (if Jira ticket and MCP available)
- **Read** (if requirements in file)
- **Memory** (check for recent analysis)
- **TaskCreate** (track implementation workflow)

**Output:**
- Clear requirements
- Service identified
- Plugin identified
- Gaps to implement (or fixes to apply)

---

### STEP 1.5: Check for Jira Approval (If Ticket Provided)

**CRITICAL: If implementing from a Jira ticket, check if test plan was approved before proceeding.**

**Actions:**

1. **Check if ticket ID provided:**
   - If no ticket ID (manual requirements) → Skip approval check, proceed to STEP 2
   - If ticket ID provided (e.g., OSPRH-13921) → Continue approval check

2. **Fetch Jira comments:**
   ```bash
   Use Jira API (or MCP if available):
   GET /rest/api/2/issue/{ticket_id}/comment
   
   Extract all comments with:
   - comment.body (text content)
   - comment.created (timestamp)
   - comment.author.displayName (who posted)
   ```

3. **Search for test plan comment:**
   
   Look for test plan markers in comments:
   - "🤖 Test Automation Plan"
   - "Test Automation Plan"
   - "Proposed Tests"
   
   ```python
   plan_comment = None
   plan_posted_date = None
   
   for comment in comments:
       if "🤖 Test Automation Plan" in comment.body or "Test Automation Plan" in comment.body:
           plan_comment = comment
           plan_posted_date = comment.created
           break
   ```

4. **Search for approval comment:**
   
   Approval keywords: `["Approved", "LGTM", "looks good", "approved", "lgtm"]`
   
   ```python
   approval_found = False
   approval_comment = None
   
   for comment in comments:
       comment_text = comment.body.lower()
       comment_date = comment.created
       
       # Check if comment contains approval keyword
       for keyword in approval_keywords:
           if keyword.lower() in comment_text:
               # Verify comment is AFTER test plan (if plan exists)
               if plan_posted_date is None or comment_date > plan_posted_date:
                   approval_found = True
                   approval_comment = comment
                   break
       
       if approval_found:
           break
   ```

5. **Handle approval status:**

   **If approval FOUND:**
   ```markdown
   ✅ Test plan approved by {author} on {date}
   
   Comment: "{approval_comment_snippet}"
   
   Proceeding with implementation...
   ```
   → Continue to STEP 2

   **If approval NOT FOUND:**
   ```markdown
   ⚠️ No approval found for test plan on {ticket_id}
   
   Test plan posted: {plan_posted_date} (if exists)
   No approval comment found with keywords: "Approved", "LGTM", "looks good"
   
   **Options:**
   1. **Wait for approval** - Stop here, user should get approval first
   2. **Proceed anyway** - Implement tests without approval (use --skip-approval flag)
   3. **Manual confirmation** - Ask user if they have verbal/offline approval
   
   What would you like to do?
   ```
   
   Use **AskUserQuestion** to prompt:
   - "Wait" → Stop execution, inform user to get approval first
   - "Proceed" → Log warning, continue to STEP 2
   - "I have approval" → Log note, continue to STEP 2

6. **Support --skip-approval flag:**
   
   If user runs: `/implement-tempest-tests TICKET-123 --skip-approval`
   
   → Skip approval check entirely, proceed to STEP 2
   
   Log: "⚠️ Approval check skipped (--skip-approval flag used)"

**Tool Usage:**
- **Bash** (curl to Jira API with credentials from env)
- **Read** (config for approval keywords)
- **AskUserQuestion** (if no approval found)

**Output:**
- ✅ Approval confirmed → Continue
- ⚠️ No approval, user chose proceed → Continue with warning
- 🛑 No approval, user chose wait → STOP execution

**Error Handling:**
- If Jira fetch fails → Warn user, ask if they want to proceed anyway
- If no test plan comment found → Note it, still check for approval keywords
- If config missing → Use default approval keywords

---

### STEP 2: Locate Tempest Repositories

**Actions:**
- Find local Tempest repository for the service
- Verify repository exists
- Check out main/master branch status

**Search Strategy:**
```bash
# Find service plugin (searches common locations)
find ~ -type d -name "{service}-tempest-plugin" -maxdepth 3

# Verify it exists
cd {repo_path}
git status
git branch
```

**If repo NOT found:**
- Explicitly state which repository is missing
- Ask user for path OR
- Note that code will follow upstream structure (can't validate locally)
- Proceed with implementation based on upstream standards

**Tool Usage:**
- **Bash** (find, cd, git status)

**Output:**
- Repository path (if found)
- Current branch
- Git status
- Repository status (found/missing)

---

### STEP 3: Discover Implementation Patterns (MANDATORY)

**Actions:**

Spawn **Agent (Explore)** to discover patterns for implementation:

**Search for:**
1. **Base test classes** to inherit from
2. **Service clients** to use
3. **Existing similar tests** as templates
4. **Waiter methods** available
5. **Cleanup patterns** used
6. **Common fixtures** available

**Search Patterns:**
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
```

**CRITICAL RULES:**
- **Always reference at least ONE existing test as template**
- **Never invent new frameworks** - reuse existing patterns
- **Identify base classes per service** from existing tests
- **Use exact same client patterns** as existing tests
- **Copy cleanup patterns exactly**
- **Search for an existing test file before creating a new one** - look for files that cover the same service area or API. Only create a new file if no suitable existing file is found.
- **Search for an existing test class before creating a new one** - within the chosen file, check if an existing class covers the same feature area. Add the test method there rather than creating a new class. A new class is only warranted when the base class, credential type, or skip conditions differ meaningfully from all existing classes.

**Tool Usage:**
- **Agent (Explore, thorough)** - Deep pattern discovery
- **Read** - Examine template tests
- **Memory** - Save/recall patterns for this service

**Output:**
- Base class to inherit from
- Clients to use
- Template test reference
- Cleanup pattern
- Waiter methods available

---

### STEP 4: Implementation Planning

**For Complex Changes (multi-file, new patterns):**
- Use **EnterPlanMode**
- Present implementation plan
- Get user approval
- Proceed after approval

**For Simple Changes (single file, known patterns):**
- Skip plan mode
- Proceed directly to implementation
- Use discovered patterns

**Planning Considerations:**
- File location — **prefer adding to an existing file** over creating a new one. Search for existing test files that cover the same service area or API (e.g., `test_create_from_image.py` for image-based volume tests). Only create a new file when the new test is clearly a different subject area.
- Class location — within the chosen file, **prefer adding to an existing class** over creating a new one. Only create a new class when the required base class, credential type, or skip conditions genuinely differ from all existing classes in the file.
- Class structure
- Method names
- Test types (positive, negative, RBAC)
- Cleanup strategy

**Tool Usage:**
- **EnterPlanMode** (if complex)
- **AskUserQuestion** (if ambiguous)
- **TaskUpdate** (track planning complete)

---

### STEP 5: Implement Tests (CORE OF THIS SKILL)

**Actions:**

Implement tests following **strict Tempest standards**.

**CRITICAL: Implement focused, targeted tests - not excessive coverage.**

**Coverage Principles:**
- **Focus on ticket requirements** - Implement what's actually needed
- **Avoid over-engineering** - Don't test every edge case variation
- **Prefer 2-3 focused tests** over 5+ granular tests
- **Each test validates a meaningful scenario** - Not minor variations
- **Quality over quantity** - Better coverage with fewer, better tests

**Implementation Requirements:**

1. **Use Proper Base Class**
   ```python
   from {plugin}.tests.api import base
   
   class MyFeatureTest(base.BaseVolumeTest):  # Use discovered base class
       """Test {feature} functionality."""
   ```

2. **Use Tempest Clients (NO raw API)**
   ```python
   # CORRECT
   volume = self.volumes_client.create_volume()
   
   # WRONG
   response = requests.post(url, json=data)
   ```

3. **Use Waiters (NO sleep!)**
   ```python
   # CORRECT
   waiters.wait_for_volume_resource_status(
       self.volumes_client, volume_id, 'available'
   )
   
   # WRONG
   time.sleep(10)
   ```

4. **Proper Cleanup**
   ```python
   volume = self.create_volume()  # Or volumes_client.create_volume()
   self.addCleanup(self.delete_volume, volume['id'])
   ```

5. **Test Independence**
   - Each test must run independently
   - No shared state between tests
   - Parallel execution safe

6. **Proper Decorators**
   ```python
   @decorators.idempotent_id('uuid-here')  # Generate new UUID
   @decorators.attr(type='smoke')  # or 'slow', 'rbac', 'negative'
   def test_my_feature(self):
   ```

7. **Naming Convention**
   - Format: `test_{action}_{condition}`
   - Example: `test_volume_multiattach_admin_authorized()`

**File Placement:**
- Service-specific feature → plugin (e.g., cinder-tempest-plugin)
- Generic functionality → tempest core

**Tool Usage:**
- **Write** (create new files)
- **Edit** (modify existing files)
- **Read** (verify file structure before writing)

**Output:**
- Test file(s) created/modified
- Test class(es) implemented
- Test method(s) implemented
- All following discovered patterns

---

### STEP 6: Git Workflow

**Actions:**

Create branch and commit changes (DO NOT PUSH).

**Workflow:**

1. **Ensure up-to-date:**
   ```bash
   cd {repo}
   git fetch origin
   git status
   ```

2. **Create feature branch:**
   ```bash
   git checkout -b tempest-coverage-{ticket-id-or-feature}
   ```

3. **Stage changes:**
   ```bash
   git add {test_files}
   ```

4. **Commit with proper message:**
   ```bash
   git commit -m "Add Tempest coverage for {feature}
   
   Implements test coverage for {ticket-id}
   - test_scenario_1
   - test_scenario_2
   
   Closes-Bug: #{ticket-id}
   
   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
   ```

5. **Show status:**
   ```bash
   git status
   git diff main
   ```

**CRITICAL RULES:**
- ❌ Never modify main/master directly
- ❌ Never push automatically
- ❌ Never submit patches automatically
- ✅ Always create branch
- ✅ Always proper commit message
- ✅ Always reference ticket ID

**Tool Usage:**
- **Bash** (all git operations)

**Output:**
- Branch created
- Changes committed
- Commit message
- Git status
- Ready for user review

---

### STEP 7: Validation

**Actions:**

Run tox validation to ensure code quality.

**Validation Steps:**

1. **Linting (pep8):**
   ```bash
   cd {repo}
   tox -e pep8 -- {test_file}
   ```

2. **Unit tests:**
   ```bash
   tox -e py3 -- {test_module_path}
   ```

3. **Resource cleanup verification:**
   - Check tests use addCleanup properly
   - No resource leaks

4. **Parallel execution check:**
   - Tests are independent
   - No shared state

**Tool Usage:**
- **Bash (run_in_background)** - Run tox commands
- **Read** - Check output if background task

**Success Criteria:**
- ✅ pep8: PASSED (no style violations)
- ✅ py3: PASSED (all tests pass)
- ✅ Resource cleanup: Verified
- ✅ Parallel safe: Confirmed

**If Validation Fails:**
- Show exact errors
- Propose fixes
- Re-run validation after fixes

---

### STEP 8: Final Output with MANDATORY RECAP

**CRITICAL: This step is MANDATORY for EVERY execution.**

Provide comprehensive structured report with mandatory final recap.

**Report Format:**

```markdown
# Tempest Test Implementation: {TICKET-ID or FEATURE}

## Summary
- **Ticket/Feature:** {ID or description}
- **Service:** {Service name}
- **Implementation Status:** ✅ Complete / ⚠️ Partial / ❌ Failed

## Implementation Details

### Files Created/Modified
- `{relative/path/to/test_file.py}` (created/modified)

### Test Classes
- **Class:** {ClassName}
- **Inherits From:** {BaseClass}
- **Tests Implemented:** {count}

### Test Methods
1. `test_method_1()` - {Purpose}
2. `test_method_2()` - {Purpose}
3. `test_method_3()` - {Purpose}

## Code Implementation

[Show full code or key excerpts]

## Validation Results
- ✅ pep8: PASSED
- ✅ py3: PASSED (3/3 tests)
- ✅ Resource cleanup: Verified
- ✅ Parallel execution: Safe

## Git Branch
- **Branch:** tempest-coverage-{ticket-id}
- **Commit:** Created with proper message
- **Status:** Ready for review
- **Push:** NOT pushed (user controls)

## Next Steps
1. Review: `git diff main`
2. Test: `tox`
3. Submit: `git review` (manual)
```

---

## ========================
## MANDATORY FINAL RECAP
## ========================

**Format (MUST include):**

```markdown
========================
FINAL RECAP
========================

### 1. Work Performed

**Ticket/Feature:** {TICKET-ID or description}
**Service:** {Service name}
**Operation:** {What was implemented}

**Implementation Type:**
- [x] New tests created
- [ ] Existing tests modified
- [ ] Analysis only

---

### 2. Implementation Details

#### Files Created/Modified:

**File 1:**
- **Absolute Path:** `{full-path-to-plugin}/{path/to/test_file.py}`
- **Relative Path:** `{plugin_path}/tests/{path/to/test_file.py}`
- **Status:** ✅ Created (or ✅ Modified)
- **Lines Added:** ~{count}

#### Test Classes Implemented:

**Class 1:**
- **Name:** `{ClassName}`
- **File:** `{relative/path/to/test_file.py}`
- **Inherits From:** `{BaseClass}`
- **Module Path:** `{plugin}.tests.{path}.{module}`

#### Test Methods Implemented:

1. **Method:** `test_{operation}_{condition}()`
   - **Location:** `{ClassName}` class
   - **Purpose:** {What it tests}
   - **Test Type:** Positive/Negative/RBAC/Scenario

2. **Method:** `test_{operation}_{condition}()`
   - **Location:** `{ClassName}` class
   - **Purpose:** {What it tests}
   - **Test Type:** Positive/Negative/RBAC/Scenario

---

### 3. Code Location Summary

**Repository:** {plugin-name}
**Directory:** `{path/to/tests/}`
**File:** `test_{feature}.py`

**How to locate:**
```bash
cd $TEMPEST_WORKSPACE/{plugin}
ls -la {path/to/test_file.py}
```

**How to run:**
```bash
cd $TEMPEST_WORKSPACE/{plugin}
tox -e py3 -- {module.path}.{TestClass}
```

**All Files Modified in This Session:**
1. `{file1}` (created/modified)
2. `{file2}` (created/modified - if applicable)

---

### 4. Coverage Results

**Before This Work:**
- ✅ Existing tests: {list existing if any}
- ❌ Missing: {what was missing}

**After This Work:**
- ✅ Implemented: {what's now covered}
- ✅ Test quality: Follows all Tempest standards
- ✅ Base class: {BaseClass used}
- ✅ Clients: {clients used}
- ✅ Waiters: Proper waiters used (no sleep)
- ✅ Cleanup: addCleanup for all resources

**Scenarios Now Covered:**
1. ✅ {Scenario 1}
2. ✅ {Scenario 2}
3. ✅ {Scenario 3}

**Gaps That Still Remain:**
- ⚠️ {Gap 1 - if any}
- ⚠️ {Gap 2 - if any}

**Note:** {Explanation of why gaps remain, if any}

---

### 5. Validation & Verification

**Validation Results:**
- ✅ pep8: PASSED (no style violations)
- ✅ py3: PASSED ({X}/{X} tests passed)
- ✅ Resource cleanup: Verified (no leaks)
- ✅ Parallel execution: Safe (tests independent)

**Git Status:**
- ✅ Branch created: `{branch-name}`
- ✅ Commit created with proper message
- ✅ Changes ready for review
- ❌ NOT pushed (user must review and push manually)

---

### 6. Assumptions & Risks

**Assumptions Made:**
1. {Assumption 1}
2. {Assumption 2}

**Risks Identified:**
1. {Risk 1}
2. {Risk 2}

**Missing Information:**
- {What wasn't clear - or "None"}

**Blockers:**
- {Any blockers - or "None encountered"}

---

### 7. Next Steps for User

**Immediate Actions:**
1. Review code changes:
   ```bash
   cd $TEMPEST_WORKSPACE/{plugin}
   git diff main
   ```

2. Review commit:
   ```bash
   git log -1 --stat
   ```

3. Test manually (optional):
   ```bash
   tox -e py3 -- {test.path}
   ```

**Before Submitting:**
1. ✅ Run full pep8: `tox -e pep8`
2. ✅ Run full unit tests: `tox -e py3`
3. ✅ Review all changes carefully
4. ✅ Ensure commit message is accurate

**Submission:**
```bash
git review
```

**Note:** Code has NOT been pushed. You control when to submit for review.

========================
END OF RECAP
========================
```

---

### Orchestrator Mode: Structured JSON Output

**When `--orchestrator-mode` flag is provided:**

Skip the detailed markdown report and MANDATORY FINAL RECAP. Return structured JSON only:

```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "IMPLEMENTING",
  "status": "SUCCESS|ERROR",
  "metadata": {
    "service": "cinder",
    "plugin": "cinder-tempest-plugin",
    "repository_path": "/Users/user/automation_projects/cinder-tempest-plugin",
    "branch": "tempest-coverage-OSPRH-22613",
    "test_module": "cinder_tempest_plugin.api.volume.test_multiattach",
    "test_files": [
      "cinder_tempest_plugin/api/volume/test_multiattach.py"
    ],
    "test_files_absolute": [
      "/Users/user/automation_projects/cinder-tempest-plugin/cinder_tempest_plugin/api/volume/test_multiattach.py"
    ],
    "test_methods": [
      "test_volume_multiattach_admin_authorized",
      "test_volume_multiattach_member_authorized",
      "test_volume_multiattach_reader_denied"
    ],
    "validation_passed": true,
    "pep8_passed": true,
    "py3_passed": true,
    "commit_sha": "a1b2c3d4",
    "implementation_summary": "3 RBAC tests for volume multiattach"
  },
  "errors": []
}
```

**Field Descriptions:**
- `ticket_id`: Jira ticket ID (or "MANUAL" if no ticket)
- `stage_completed`: Always "IMPLEMENTING" (orchestrator stage tracking)
- `status`: "SUCCESS" if implementation completed, "ERROR" if failed
- `metadata.service`: OpenStack service name
- `metadata.plugin`: Tempest plugin name
- `metadata.repository_path`: Absolute path to plugin repository
- `metadata.branch`: Git branch created for this implementation
- `metadata.test_module`: Python module path for tests (used for tox execution)
- `metadata.test_files`: Relative paths to test files created/modified
- `metadata.test_files_absolute`: Absolute paths to test files
- `metadata.test_methods`: List of test method names implemented
- `metadata.validation_passed`: Boolean (true if pep8 and py3 passed)
- `metadata.pep8_passed`: Boolean (pep8 validation result)
- `metadata.py3_passed`: Boolean (py3 validation result)
- `metadata.commit_sha`: Git commit SHA (short form)
- `metadata.implementation_summary`: One-sentence summary
- `errors`: Array of error messages (empty if success)

**Error Status Example:**
```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "IMPLEMENTING",
  "status": "ERROR",
  "metadata": {
    "service": "cinder",
    "plugin": "cinder-tempest-plugin"
  },
  "errors": [
    "Repository not found: ~/automation_projects/cinder-tempest-plugin",
    "Cannot proceed without repository"
  ]
}
```

**Exit Code:**
- Exit with code 0 if `status == "SUCCESS"`
- Exit with code 1 if `status == "ERROR"`

**Notes for Orchestrator:**
- `test_module` field is used by verify-tempest-devstack skill for tox execution
- `branch` field is used by code-reviewer agent to locate test files
- `repository_path` field is used by code-reviewer agent for git operations

---

## Memory & Learning

**After each implementation, save to memory:**

1. **Reference type:**
   - Service → Plugin mapping
   - Service → Base class mapping
   - Example: "Cinder tests inherit from BaseVolumeTest"

2. **Feedback type:**
   - Implementation patterns that worked
   - Validation that passed/failed
   - Example: "For Cinder RBAC, use BaseVolumeTest with credentials=['admin', 'primary']"

3. **Project type:**
   - Ongoing implementation work
   - Example: "Implementing RBAC coverage for Cinder service"

---

## Tool Usage Summary

| Phase | Primary Tools | Purpose |
|-------|---------------|---------|
| Requirements | jira_get_issue, Read, Memory | Get requirements |
| Approval Check | Bash (curl Jira API), AskUserQuestion | Verify test plan approval |
| Repo Discovery | Bash (find, git) | Locate repository |
| Pattern Discovery | Agent (Explore), Read | Find implementation patterns |
| Planning | EnterPlanMode (if complex) | Get user approval |
| Implementation | Write/Edit, Read | Create test code |
| Git Workflow | Bash (git commands) | Branch, commit |
| Validation | Bash (tox, background) | Run tests |
| Output | Markdown formatting | Structured report + recap |
| Learning | Memory (Write) | Save patterns |

---

## Success Criteria

A successful implementation includes:
1. ✅ Requirements understood
2. ✅ Test plan approved (if Jira ticket) OR user confirmed proceed
3. ✅ Patterns discovered and followed
4. ✅ Tests implemented following upstream standards
5. ✅ All validation passing (pep8, py3)
6. ✅ Git branch created with proper commit
7. ✅ Mandatory final recap provided
8. ✅ Code ready for review (not auto-pushed)
9. ✅ Patterns saved to memory

---

## Constraints & Rules

### ✅ DO:
- Follow discovered patterns exactly
- Implement focused tests (2-4 tests typically)
- Focus on ticket requirements (not every edge case)
- Use Tempest base classes
- Use Tempest clients (no raw API)
- Use waiters (no sleep!)
- Proper cleanup (addCleanup)
- Test independence (parallel-safe)
- Validate before reporting complete
- Provide mandatory final recap

### ❌ DON'T:
- Implement excessive test coverage beyond ticket scope
- Create 5+ tests when 2-3 focused tests are sufficient
- Test every minor variation or edge case
- Invent new frameworks
- Use raw requests/API calls
- Use time.sleep()
- Skip cleanup
- Skip validation
- Push code automatically
- Submit patches automatically
- Modify main/master directly
- Guess patterns - discover them!

---

## Integration with Analysis Skill

**Workflow 1: Analysis First (Recommended)**
```bash
# Step 1: Analyze
/jira-coverage-analysis RHEL-12345

# Review analysis, approve scope

# Step 2: Implement
/implement-tempest-tests RHEL-12345
```
Implementation skill uses analysis findings.

**Workflow 2: Direct Implementation (with approval check)**
```bash
# Post test plan, get approval, then implement
/post-test-plan RHEL-12345
# (Wait for stakeholder approval in Jira)

/implement-tempest-tests RHEL-12345
# Checks for approval automatically, proceeds if approved
```
Recommended workflow for stakeholder buy-in.

**Workflow 3: Direct Implementation (skip approval)**
```bash
# One command (no approval check)
/implement-tempest-tests RHEL-12345 --skip-approval
```
Use when you have offline/verbal approval or implementing without formal process.

**Workflow 4: Manual Requirements**
```bash
/implement-tempest-tests

Requirements:
- Service: Cinder
- Tests needed: RBAC for volume multi-attach
```
No Jira needed, direct implementation.

---

## Configuration

The skill uses shared configuration:
- `~/.claude/skills/tempest-coverage/config.json` (shared with analysis skill)
- Same Jira MCP settings
- Same repository paths
- Same service mappings
- Same templates

---

## Output Guarantees

**Every execution provides:**
- ✅ Test implementation (following patterns)
- ✅ Git branch and commit
- ✅ Validation results
- ✅ Mandatory final recap with exact details
- ✅ Ready for user review
- ✅ No auto-push (user control)

---

END OF SKILL DEFINITION
