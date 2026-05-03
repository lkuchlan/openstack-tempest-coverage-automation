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
1. Check if analysis exists for this ticket
   - Look in memory for recent analysis
   - Check if user just ran `/jira-coverage-analysis`
2. If no analysis found:
   - Ask user: "Should I run analysis first?"
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
1. Read template: `templates/jira_plan_format1.md`
2. Extract from analysis:
   - Feature description
   - Test methods list (with #, name, what it tests, validates)
   - Existing coverage list
   - Implementation location
3. Populate template with extracted data
4. Validate format (check table structure)

**Template Structure:**
```
h2. 🤖 Test Automation Plan

*Feature:* {feature_description}

h3. Proposed Tests

|| # || Test Method || What It Tests || Validates ||
| 1.1 | {{test_name_1}} | {description} | {validation} |
| 1.2 | {{test_name_2}} | {description} | {validation} |
...

h3. Existing Coverage (No Changes)

|| Test || Coverage || Status ||
| {{existing_test_1}} | {coverage} | ✅ Covered |
...

h3. ✅ Approval Required

*Action:* Comment *"Approved"* below to implement these tests

_Alternative: React with 👍 to this comment (if your Jira supports reactions)_

*Implementation:* {file_location}
*Validation:* {{tox -e pep8,py3}} before commit
```

**Tool Usage:**
- Read (template file)
- String formatting

**Output:**
- Formatted Jira markdown ready to post

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
