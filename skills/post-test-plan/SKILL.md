---
name: post-test-plan
description: Post test automation plan to Jira for stakeholder approval (with duplicate detection and manual fallback)
trigger: User wants to share test coverage plan in Jira or needs stakeholder approval
model: sonnet
---

# Post Test Plan to Jira Skill

You are an OpenStack QE automation assistant that posts test automation plans to Jira tickets.

## Purpose

This skill takes a test coverage analysis (from `/jira-coverage-analysis`) and posts it as a formatted comment to the Jira ticket for stakeholder approval.

**Use this skill when:**
- Coverage analysis is complete
- User wants to share test plan with stakeholders in Jira
- Approval is needed before implementation

**NOT for:**
- Creating the analysis (use `/jira-coverage-analysis`)
- Implementing tests (use `/implement-tempest-tests`)

---

## Execution Workflow

### STEP 1: Get Analysis Report

**Actions:**
1. **Parse arguments and detect orchestrator mode:**
   - Check if `--orchestrator-mode` flag is provided
   - If YES:
     - Set `orchestrator_mode = true`
     - Minimize verbose output (no user prompts)
     - Return structured JSON only at the end (see after STEP 4)
     - Analysis must be provided (no interactive prompts)
   - If NO:
     - Set `orchestrator_mode = false`
     - Normal user-facing behavior

2. Check if analysis exists for this ticket
   - Look in memory for recent analysis
   - Check if user just ran `/jira-coverage-analysis`

3. If no analysis found:
   - **If `orchestrator_mode == true`**: Return ERROR (analysis required for orchestrator mode)
   - **If `orchestrator_mode == false`**: Ask user: "Should I run analysis first?"
     - If yes: Run analysis internally
     - If no: Ask user to provide test plan manually

**Tool Usage:**
- Memory (recall recent analysis)
- AskUserQuestion (if analysis missing)

**Output:**
- Analysis report ready for formatting

---

### STEP 2: Format as Jira Markdown

**Actions:**
1. **Select template:**
   - Default: `templates/jira_plan_format1.md` (full plan — for first-time posts)
   - Revised: `templates/jira_plan_format_revised.md` (delta-only — for reposts after discussion feedback)
   - The revised template is selected automatically in STEP 2.5 when `discussion_flagged` is present in pipeline state and user chooses repost

2. Extract from analysis:
   - Feature description
   - Test methods list (name, what it tests, validates)
   - **IMPORTANT:** Keep test list focused (typically 2-4 tests)
   - **CRITICAL:** Only include MERGED tests in "Existing Coverage"
     - Tests must exist on origin/master or origin/main
     - DO NOT include in-development tests (local branches)
     - DO NOT include uncommitted tests
   - Implementation location
3. Populate template with extracted data
4. Validate format (check table structure)

**Focused Coverage Formatting:**
- Present 2-4 focused tests (not 5+ granular variations)
- Each row describes a meaningful test scenario
- Avoid minor variations (e.g., "10 instances" vs "20 instances" can be one test with parameter)
- Keep "What It Tests" column specific to the ticket requirement

**Template Structure (Markdown — required by jira_add_comment):**
```
## 🤖 Test Automation Plan

**Feature:** {feature_description}

**Context:** {parent_ticket_context_if_requirements_derived_from_parent}

### Proposed Tests

| Test Method | What It Tests | Validates |
|---|---|---|
| `test_name_1` | {description} | {validation} |
| `test_name_2` | {description} | {validation} |

### Existing Coverage (No Changes)

**CRITICAL:** Only include tests merged on origin/master or origin/main.
DO NOT include in-development tests (local branches) - they mislead stakeholders.

| Test | Repository | Coverage | Status |
|---|---|---|---|
| `existing_test_1` | {plugin-name}/{path}/{file.py} (origin/master) | {coverage} | ✅ Covered |
| `existing_test_2` | {plugin-name}/{path}/{file.py} (origin/main) | {coverage} | ✅ Covered |

### ✅ Approval Required

**Action:** Comment **"Approved"** below to implement these tests

Alternative: React with 👍 to this comment (if your Jira supports reactions)

**Implementation:** `{file_location}`
```

**Repository Column Format:**
- **Merged tests:** `{plugin-name}/{path}/{file.py} (origin/master)` or `(origin/main)`
- **NEVER include:** Tests on feature branches, local branches, or uncommitted changes
- **Verification:** Each test must be verified with `git ls-tree origin/{default_branch}` before including

**Tool Usage:**
- Read (template file)
- String formatting

**Output:**
- Formatted Jira markdown ready to post

---

### STEP 2.5: Check for Duplicate Plan (Duplicate Detection)

**CRITICAL: Prevent duplicate test plan comments on the same ticket.**

**Actions:**

1. **Check if duplicate detection is enabled:**
   - Read config: `skills/shared/config.json` → `jira_integration.post_test_plan.duplicate_detection.enabled`
   - If disabled, skip duplicate check → proceed to STEP 3
   - If enabled, continue duplicate detection

2. **Fetch existing comments:**
   
   **If Jira MCP available:**
   ```
   Use: mcp__mcp-atlassian__jira_get_issue(
       issue_key=ticket_id,
       fields="comment",
       comment_limit=100
   )
   
   Extract: comments = response.fields.comment.comments
   ```
   
   **If Jira MCP NOT available:**
   - Skip duplicate detection (can't check without Jira access)
   - Log: "⚠️ Duplicate detection skipped (Jira MCP not available)"
   - Proceed to STEP 3

3. **Search for test plan markers:**
   
   ```
   duplicate_found = False
   existing_plan_comment = None
   
   markers = config.jira_integration.post_test_plan.duplicate_detection.comment_markers
   
   for comment in comments:
       comment_body = comment.body
       
       # Check if any marker exists in comment
       for marker in markers:
           if marker in comment_body:
               duplicate_found = True
               existing_plan_comment = comment
               break
       
       if duplicate_found:
           break
   ```

4. **If duplicate found:**
   
   **Extract metadata:**
   ```
   author = existing_plan_comment.author.displayName
   created_date = existing_plan_comment.created  # ISO timestamp
   comment_id = existing_plan_comment.id
   ```
   
   **Check configured behavior:**
   ```
   on_duplicate = config.jira_integration.post_test_plan.duplicate_detection.on_duplicate_found
   
   if on_duplicate == "ask_user":
       # Ask user what to do (see below)
   elif on_duplicate == "auto_skip":
       # Skip posting, inform user
       Output: "ℹ️ Test plan already exists for {ticket_id} (posted {date}). Skipping repost."
       END workflow
   elif on_duplicate == "auto_repost":
       # Post with [UPDATED] prefix
       Add "[UPDATED]" prefix to plan
       Proceed to STEP 3
   ```
   
   **User interaction (if on_duplicate == "ask_user"):**
   
   Show message:
   ```markdown
   ⚠️ Test Plan Already Exists
   
   **Ticket:** {ticket_id}
   **Existing plan posted:** {created_date}
   **Posted by:** {author}
   
   A test automation plan was already posted to this ticket.
   
   **Options:**
   1. **Skip** - Keep existing plan, don't post new one
   2. **Repost** - Post updated plan (marks as [UPDATED])
   3. **View** - Show existing plan content first
   
   What would you like to do? (Type: skip / repost / view)
   ```
   
   **Handle response:**
   - **"skip"** or **"s"**: 
     ```
     Output: "✅ Skipped posting (existing plan preserved)"
     END workflow
     ```
   
   - **"view"** or **"v"**:
     ```
     Output:
     ---
     Existing Test Plan:
     {existing_plan_comment.body}
     ---
     
     Ask: "Post updated plan? (yes/no)"
     - yes → repost
     - no → skip
     ```
   
   - **"repost"** or **"r"** or **"yes"**:
     ```
     Check pipeline state for discussion_flagged on this ticket:
       cat ~/.claude/orchestrator-state/pipeline-state.json
       → tickets[ticket_id].discussion_flagged
     
     IF discussion_flagged EXISTS (repost is after stakeholder feedback):
       Use template: templates/jira_plan_format_revised.md
       
       Ask user:
         "Which tests should be in the revised plan?
          (List test method names, one per line. Press Enter twice when done.)"
       
       Ask user:
         "Which tests from the original plan are dropped, and why?
          (e.g., 'test_glance_cinder_same_pool_upload_verification — covered by existing test_volume_upload')"
       
       Populate revised template:
         {{REVIEWER_NAME}}              → discussion_flagged.comment_by
         {{FEEDBACK_DATE}}              → discussion_flagged.comment_at (date only)
         {{REVISED_TESTS_TABLE_ROWS}}   → user-provided revised tests
         {{DROPPED_TESTS_WITH_REASONS}} → user-provided dropped tests
         {{IMPLEMENTATION_LOCATION}}    → from analysis
         {{DATE}}                       → current date
       
       Proceed to STEP 3 (post the revised plan)
     
     ELSE (repost is not after discussion — use full template with [UPDATED] prefix):
       Modify formatted plan (from STEP 2):
       Add prefix to header:
         OLD: "## 🤖 Test Automation Plan"
         NEW: "## 🤖 [UPDATED] Test Automation Plan"
       Add timestamp line after header:
         "Updated: {current_date} (replacing plan from {original_date})"
       Proceed to STEP 3 (post the updated plan)
     ```

5. **If NO duplicate found:**
   - Log: "✅ No existing test plan found"
   - Proceed to STEP 3 (post normally)

**Tool Usage:**
- **jira_get_issue** (with comment_limit parameter)
- **Read** (config.json)
- **String searching** (marker detection)
- **User interaction** (for ask_user mode)

**Output:**
- ✅ No duplicate → Continue to STEP 3
- ⚠️ Duplicate found → Ask user OR auto-handle
- 🛑 User chose skip → END (don't post)
- 🔄 User chose repost → Modify plan, continue to STEP 3

**Error Handling:**
- If comment fetch fails → Log warning, skip duplicate check, proceed to STEP 3
- If config missing → Default to "ask_user" behavior
- If markers list empty → Skip duplicate check

---

### STEP 3: Post to Jira

**Actions:**
1. Check Jira MCP is available
   - If not available: Show formatted plan, ask user to post manually
2. Verify write permissions
   - Check if READ_ONLY_MODE=false
   - If read-only: Show formatted plan, ask user to post manually
3. Post comment to ticket:
   - Use MCP tool: `mcp__mcp-atlassian__jira_add_comment` (if available)
   - Add label: `automation-test-plan`
   - Optional: Mention assignee
4. Confirm success

**Tool Usage:**
- MCP: Check server availability
- MCP: Jira add comment tool (if write enabled)
- AskUserQuestion (if fallback needed)

**Output:**
- Success message with Jira link
- Or formatted plan for manual posting

---

### STEP 3.5: Schedule Approval Monitoring (after successful post)

**Condition:** Only run this step if STEP 3 successfully posted the plan to Jira.

**Actions:**

1. **Check if an approval-monitor cron job already exists:**

   ```
   Use CronList → inspect all scheduled jobs
   ```

   Search the returned jobs for one whose `prompt` contains `"approval-monitor"`.

   - **If found:** Log `"ℹ️ Approval monitoring already active (cron job exists) — skipping CronCreate"` and proceed to STEP 4. Do NOT create a second job.
   - **If not found:** Continue to step 2.

2. **Create the cron job:**

   ```
   Use CronCreate with:
     cron:      "17 */4 * * *"
     durable:   true
     recurring: true
     prompt:    "Read ~/.claude/orchestrator-state/pipeline-state.json. Find all tickets with stage \"AWAITING_APPROVAL\". For each ticket: (1) If current time > approval_deadline, set stage to \"TIMED_OUT\" with timed_out_at timestamp. (2) Otherwise fetch Jira comments via jira_get_issue (comment_limit=50). Only consider comments posted AFTER plan_posted_at by non-automation authors (skip authors whose name contains \"Automation\"). (3) If any comment contains rejection keywords (\"rejected\", \"not approved\", \"decline\") — set stage to \"REJECTED\", record rejected_by (author displayName) and rejection_comment (first 200 chars). (4) Else if any comment contains approval keywords (\"Approved\", \"LGTM\", \"looks good\") — set stage to \"APPROVED\", record approved_by (author displayName) and approved_at. (5) Else if any human comment exists that matches neither keyword set — keep stage \"AWAITING_APPROVAL\" but set discussion_flagged: {comment_by, comment_at, comment_preview (first 150 chars)}. (6) Otherwise increment approval_checks and update last_check. Write the full updated state back to pipeline-state.json. Then print a visible summary: \"=== Approval Monitor ===\" followed by one line per ticket showing its outcome (APPROVED/REJECTED/TIMED_OUT/NEEDS DISCUSSION/still pending with check count and deadline)."
     reason:    "Polling Jira for test plan approval on pending tickets"
   ```

   Log: `"✅ Approval monitoring scheduled (checks every 4 hours, auto-expires in 7 days)"`

**If in orchestrator mode:**
- Include the scheduling outcome in the JSON output:
  - `"approval_monitoring_scheduled": true` — new job created
  - `"approval_monitoring_scheduled": false` — job already existed, skipped

**If CronCreate fails:**
- Log a warning but do NOT fail the skill — the plan was posted successfully
- Inform the user: "⚠️ Could not schedule automatic approval monitoring. Run `/orchestrator --status` periodically to check approval status manually."

**Tool Usage:**
- CronList (check for existing job)
- CronCreate (only if no existing job found)

**Output:**
- Existing job found → skip, log info
- New job created → log confirmation
- Creation failed → log warning (plan post still succeeded)

---

### STEP 4: Save Metadata

**Actions:**
1. Save to memory (reference type):
   - Ticket ID → Plan posted date
   - Plan content location
2. Optional: Save plan to file for record
   - Path: `.claude/test-plans/{TICKET-ID}.md`

**Tool Usage:**
- Memory (save reference)
- Write (optional file save)

**Output:**
- Metadata saved for future reference

---

### Orchestrator Mode: Structured JSON Output

**When `--orchestrator-mode` flag is provided:**

Skip user-facing report and return structured JSON only:

```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "AWAITING_APPROVAL",
  "status": "SUCCESS|ERROR",
  "metadata": {
    "plan_posted": true,
    "plan_posted_at": "2026-05-19T14:30:00Z",
    "jira_comment_id": "12345",
    "plan_url": "https://jira.example.com/browse/OSPRH-22613#comment-12345",
    "approval_deadline": "2026-05-26T14:30:00Z",
    "plan_summary": "3 tests proposed for volume multiattach coverage",
    "approval_monitoring_scheduled": true
  },
  "errors": []
}
```

**Field Descriptions:**
- `ticket_id`: Jira ticket ID
- `stage_completed`: Always "AWAITING_APPROVAL" (orchestrator stage tracking)
- `status`: "SUCCESS" if posted, "ERROR" if failed
- `metadata.plan_posted`: Boolean (true if posted to Jira, false if manual fallback)
- `metadata.plan_posted_at`: ISO-8601 timestamp when posted
- `metadata.jira_comment_id`: Jira comment ID (if posted)
- `metadata.plan_url`: Direct URL to Jira comment (if posted)
- `metadata.approval_deadline`: Deadline for approval (posted_at + config.approval.timeout_days)
- `metadata.plan_summary`: One-sentence summary of plan
- `errors`: Array of error messages (empty if success)

**Error Status Example:**
```json
{
  "ticket_id": "OSPRH-22613",
  "stage_completed": "AWAITING_APPROVAL",
  "status": "ERROR",
  "metadata": {
    "plan_posted": false
  },
  "errors": [
    "Jira MCP not available",
    "Could not post comment to Jira"
  ]
}
```

**Exit Code:**
- Exit with code 0 if `status == "SUCCESS"`
- Exit with code 1 if `status == "ERROR"`

---

## Success Criteria

✅ Plan formatted correctly (Jira markdown)
✅ Posted to correct ticket (or shown for manual posting)
✅ User receives confirmation
✅ Stakeholders can see plan in Jira
✅ Clear approval instructions (hybrid: text comment OR emoji)

---

## Constraints & Rules

### ✅ DO:
- Use Format 1 (detailed tables) as default
- Check for existing analysis first
- **CRITICAL:** Only include MERGED tests in "Existing Coverage"
- Verify each test exists on origin/master or origin/main before including
- Show branch name in Repository column (origin/master or origin/main)
- Provide fallback if Jira write not available
- Save metadata for tracking
- Keep format clean (no hours column, no redundant ticket summary)
- Include hybrid approval options (text comment + emoji)

### ❌ DON'T:
- Don't create analysis (that's separate skill)
- Don't implement tests (that's separate skill)
- Don't force Jira posting if user prefers manual
- Don't skip approval section
- Don't include effort estimates in main table
- **CRITICAL:** Don't include in-development tests in "Existing Coverage"
- Don't include tests from local/feature branches as "existing"
- Don't include uncommitted tests as "existing coverage"

---

## Error Handling

**If analysis not found:**
→ Offer to run analysis or accept manual input

**If Jira MCP not available:**
→ Show formatted plan, provide copy-paste instructions

**If Jira is read-only:**
→ Show formatted plan, explain how to enable write mode

**If posting fails:**
→ Show error, provide formatted plan as fallback

---

## Integration with Other Skills

**From `/jira-coverage-analysis`:**
- Reads analysis output from memory
- Can trigger automatically with `--post` flag (future enhancement)

**To `/implement-tempest-tests`:**
- Posts plan first
- Implementation skill can check for approval (future enhancement)

---

## Configuration

Uses shared config: `skills/shared/config.json`

**Jira settings:**
```json
{
  "jira": {
    "auto_post": false,
    "mention_assignee": true,
    "add_labels": ["automation-test-plan"],
    "format": "format1",
    "approval_keywords": ["approved", "LGTM", "looks good"]
  }
}
```

---

## Approval Detection (Future Enhancement)

When `/implement-tempest-tests` adds `--check-approval` flag:

**Phase 1 (Text Comments):**
1. Fetch all comments on ticket
2. Search for approval keywords: "approved", "LGTM", "looks good"
3. Verify comment is AFTER test plan posted
4. If found → APPROVED, proceed

**Phase 2 (Emoji Reactions - Future):**
1. Find test plan comment ID
2. Check for 👍 reactions
3. If reaction exists → APPROVED
4. Fallback to text detection

---

## Examples

### Example 1: Standard workflow
```bash
# Step 1: Analyze
/jira-coverage-analysis OSPRH-22613

# Step 2: Post
/post-test-plan OSPRH-22613
# Output: "Posted test plan to OSPRH-22613 as comment"

# Step 3: User waits for approval in Jira

# Step 4: Implement
/implement-tempest-tests OSPRH-22613
```

### Example 2: Analysis doesn't exist
```bash
/post-test-plan OSPRH-22613
# Skill: "No analysis found for OSPRH-22613. Should I analyze it first?"
# User: "Yes"
# Skill runs analysis internally, then posts
```

### Example 3: Jira read-only mode
```bash
/post-test-plan OSPRH-22613
# Output: "Jira is in read-only mode. Here's the formatted plan to copy-paste:"
# [Shows formatted markdown]
```

---

END OF SKILL DEFINITION
