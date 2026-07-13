# Post Test Plan to Jira

Post test automation plans to Jira tickets for stakeholder approval.

## Purpose

This skill formats and posts test coverage analysis as a structured comment in Jira tickets, making it easy for stakeholders to review and approve test plans before implementation begins.

## Usage

```bash
/post-test-plan <TICKET-ID>
```

## Prerequisites

1. **Analysis completed** - Run `/jira-coverage-analysis` first
2. **Jira MCP server configured** (optional - fallback available)
3. **Write permissions enabled** (optional - can copy-paste)

## Workflow

### Standard Workflow (Recommended)

```bash
# Step 1: Analyze ticket for coverage gaps
/jira-coverage-analysis OSPRH-22613

# Step 2: Post test plan to Jira
/post-test-plan OSPRH-22613

# Step 3: Wait for stakeholder approval in Jira
# Stakeholders review and comment "Approved" or react with 👍

# Step 4: Implement after approval
/implement-tempest-tests OSPRH-22613
```

### If Jira Write Not Available

```bash
/post-test-plan OSPRH-22613
# Skill will show formatted plan for manual copy-paste
# Copy the markdown and paste into Jira ticket as comment
```

## What Gets Posted

The skill posts a structured comment containing:

### 1. Feature Description
Brief description of what's being tested

### 2. Proposed Tests Table
| # | Test Method | What It Tests | Validates |
|---|-------------|---------------|-----------|
| 1.1 | `test_concurrent_boot_10_instances` | Create 10 instances in parallel | All reach ACTIVE, no errors |
| ... | ... | ... | ... |

### 3. Existing Coverage
Shows what tests already exist (no changes needed)

### 4. Implementation Details
- Repository and file location
- Validation commands
- Approval instructions

### 5. Approval Section (Hybrid)
Stakeholders can approve via:
- **Option 1:** Comment "Approved" (recommended)
- **Option 2:** React with 👍 to the plan comment

## Duplicate Detection

Prevents posting multiple test plans to the same ticket, avoiding noise and confusion.

**How it works:**
- Checks existing comments for test plan markers ("🤖 Test Automation Plan")
- If duplicate found, asks user what to do: skip, repost, or view
- Marks updated plans with [UPDATED] prefix

**User options when duplicate detected:**

1. **Skip** - Keep existing plan, don't post new one
2. **Repost** - Post updated plan (marks as [UPDATED])
3. **View** - Show existing plan content first, then decide

**Bypass duplicate check:**
```bash
/post-test-plan RHEL-12345 --skip-duplicate-check
```

**Configuration:**
Edit `skills/shared/config.json` → `jira_integration.post_test_plan.duplicate_detection`:

```json
{
  "duplicate_detection": {
    "enabled": true,
    "on_duplicate_found": "ask_user"
  }
}
```

**Behavior modes:**
- `ask_user` - Show options, let user decide (default)
- `auto_skip` - Automatically skip if duplicate exists
- `auto_repost` - Automatically post with [UPDATED] prefix

**Why this matters:**
- Prevents duplicate comments cluttering the ticket
- Preserves existing approvals
- Makes updates explicit with [UPDATED] marker
- Gives control over when to replace plans

## Examples

### Example 1: Complete Workflow
```bash
# Analyze
/jira-coverage-analysis OSPRH-22613

# Review analysis output
# Looks good? Post to Jira

/post-test-plan OSPRH-22613
# → "✅ Posted test plan to OSPRH-22613"
# → "View: https://redhat.atlassian.net/browse/OSPRH-22613"

# Check Jira, stakeholder comments "Approved"

# Implement
/implement-tempest-tests OSPRH-22613
```

### Example 2: Manual Posting (Jira Read-Only)
```bash
/post-test-plan OSPRH-22613

# Output:
# "Jira is in read-only mode. Here's the formatted plan to copy-paste:"
# 
# [Formatted Jira markdown displayed]
#
# → Copy and paste into OSPRH-22613 as comment
```

### Example 3: Analysis Not Done Yet
```bash
/post-test-plan OSPRH-22613

# Skill asks: "No analysis found for OSPRH-22613. Should I analyze it first?"
# You respond: "Yes"

# Skill runs analysis internally, then posts the plan
```

## Configuration

### Enable Jira Write Mode

To enable automatic posting (not just copy-paste):

1. Update your Jira MCP server configuration
2. Set `READ_ONLY_MODE="false"`
3. Ensure credentials have write permissions

**MCP Configuration Example:**
```bash
# In your shell profile or environment
export JIRA_URL="https://redhat.atlassian.net"
export JIRA_USERNAME="your-email@redhat.com"
export JIRA_API_TOKEN="your-api-token"
export READ_ONLY_MODE="false"  # Enable write mode
```

### Skill Configuration

Edit `skills/shared/config.json`:

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

## Approval Workflow

### How Stakeholders Approve

**Method 1: Text Comment (Recommended)**
```
Stakeholder comments on test plan:
"Approved"
or
"LGTM"
or
"Looks good, approved"
```

**Method 2: Emoji Reaction (If Available)**
```
Stakeholder reacts to test plan comment with 👍
```

### Handling Stakeholder Discussion

When a stakeholder leaves a comment that is neither an approval nor a rejection (a question, concern, or feedback requesting changes), the `approval-monitor` agent sets `discussion_flagged = true` on the ticket state and prints a **NEEDS DISCUSSION** summary at its next run.

**What happens:**
- Ticket stays at `AWAITING_APPROVAL` — not rejected, not approved
- User is notified to address the feedback
- Re-running `/post-test-plan TICKET-ID` automatically uses the **revised template** (`jira_plan_format_revised.md`), which includes a "Changes Made" section and a list of dropped tests

**Revised template is used when:**
- Pipeline state has `discussion_flagged: true` for the ticket
- User re-runs `/post-test-plan TICKET-ID` after addressing feedback

### Checking for Approval

*Future enhancement for `/implement-tempest-tests`:*
```bash
/implement-tempest-tests OSPRH-22613 --check-approval

# Will check Jira for:
# - Comments containing "approved", "LGTM", etc.
# - 👍 reactions (supported)
# 
# If approved → Proceed with implementation
# If not approved → Show message: "Waiting for approval in Jira"
```

## Format Details

The skill uses **Format 1: Detailed Tables** by default.

**Key features:**
- ✅ Clean table structure (easy to scan)
- ✅ Specific test method names
- ✅ Clear validation criteria
- ✅ Existing coverage comparison
- ✅ No hours column (keeps focus on tests, not estimates)
- ✅ No redundant ticket summary (already in ticket)
- ✅ Hybrid approval options (text + emoji)

## Troubleshooting

### "Jira MCP server not found"
→ Skill will show formatted plan for manual copy-paste
→ Or configure Jira MCP server (see main project README)

### "Jira is in read-only mode"
→ Set `READ_ONLY_MODE="false"` in MCP configuration
→ Or use copy-paste workflow

### "No analysis found for ticket"
→ Run `/jira-coverage-analysis TICKET-ID` first
→ Or let skill run analysis automatically when prompted

### "Posted but stakeholders can't see it"
→ Check ticket comments section
→ Check if label `automation-test-plan` was added
→ Verify comment permissions in Jira

## Integration with Other Skills

**From `/jira-coverage-analysis`:**
- Reads analysis output from memory
- Uses same test gap identification
- Future: Add `--post` flag to analyze and post in one command

**To `/implement-tempest-tests`:**
- Test plan approval workflow
- Future: Add `--check-approval` flag to verify before implementing

## Tips

**Best Practices:**
- ✅ Always run analysis first (`/jira-coverage-analysis`)
- ✅ Review analysis before posting
- ✅ Post to Jira when plan is ready for review
- ✅ Wait for explicit approval before implementing
- ✅ Keep stakeholders in the loop

**Workflow Optimization:**
- 📋 Analyze multiple tickets in batch
- 📤 Post plans to all tickets
- ⏳ Wait for approvals to accumulate
- 🚀 Implement approved tickets in priority order

## Future Enhancements

**Planned features:**
- [x] Emoji reaction detection for approval
- [ ] Auto-post flag in `/jira-coverage-analysis --post`
- [ ] Approval checking in `/implement-tempest-tests --check-approval`
- [ ] Custom approval workflows
- [ ] Bulk posting for multiple tickets
- [ ] Approval notifications (email, Slack)

## Support

**For issues:**
- Check Jira MCP server configuration
- Verify write permissions
- Use fallback (copy-paste) if needed

**For questions:**
- See main project README
- Check CLAUDE.md for workflow guidance
- Review skill.md for technical details
