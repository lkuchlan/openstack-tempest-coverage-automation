# Approval Monitor Cron Prompt

Use this file as the `prompt` parameter when calling CronCreate. Copy the full prompt text below verbatim.

---

## CronCreate Parameters

```
cron:      "17 */4 * * *"
durable:   true
recurring: true
reason:    "Polling Jira for test plan approval on pending tickets"
```

## Prompt Text (use verbatim)

```
Read ~/.claude/orchestrator-state/pipeline-state.json. Find all tickets with stage "AWAITING_APPROVAL". For each ticket: (1) If current time > approval_deadline, set stage to "TIMED_OUT" with timed_out_at timestamp. (2) Otherwise fetch Jira comments via jira_get_issue (comment_limit=50). Only consider comments posted AFTER plan_posted_at by non-automation authors (skip authors whose name contains "Automation"). (2b) Check for 👍 reaction: find the comment containing "Test Automation Plan" and get its id as plan_comment_id. Run: source ~/.config/tempest-pipeline/.env && REACTION_RESULT=$(curl -s -u "${JIRA_USERNAME}:${JIRA_API_TOKEN}" "${JIRA_URL}/rest/api/3/issue/${ticket}/comment/${plan_comment_id}" | python3 -c "import json,sys; data=json.load(sys.stdin); approved=any(r.get('emoji')=='👍' and r.get('count',0)>0 for r in data.get('reactions',{}).get('reactionSummary',[])) or data.get('likes',{}).get('count',0)>0; print('approved' if approved else 'none')") — if REACTION_RESULT is "approved", set stage to APPROVED with approved_by="👍 reaction on plan comment" and skip steps (3)-(4). (3) If any comment contains rejection keywords ("rejected", "not approved", "decline") — set stage to "REJECTED", record rejected_by (author displayName) and rejection_comment (first 200 chars). (4) Else if any comment contains approval keywords ("approved", "Approved", "LGTM", "looks good") — set stage to "APPROVED", record approved_by (author displayName) and approved_at. (5) Else if any human comment exists that matches neither keyword set — keep stage "AWAITING_APPROVAL" but set discussion_flagged: {comment_by, comment_at, comment_preview (first 150 chars)}. (6) Otherwise increment approval_checks and update last_check. Write the full updated state back to pipeline-state.json. Then print a visible summary: "=== Approval Monitor ===" followed by one line per ticket showing its outcome (APPROVED/REJECTED/TIMED_OUT/NEEDS DISCUSSION/still pending with check count and deadline).
```

---

## Logic Summary (for reference — do not use as the prompt)

The cron job does, for each AWAITING_APPROVAL ticket:

1. Check deadline → TIMED_OUT if expired
2. Fetch Jira comments (limit 50), skip automation authors
3. Check 👍 reaction on plan comment via Jira REST API (credentials from `~/.config/tempest-pipeline/.env`)
4. Check rejection keywords: "rejected", "not approved", "decline" → REJECTED
5. Check approval keywords: "approved", "Approved", "LGTM", "looks good" → APPROVED
6. Neutral human comment → stay AWAITING_APPROVAL, set `discussion_flagged`
7. No decision → increment `approval_checks`, update `last_check`

Writes full state back to `pipeline-state.json` after every ticket.
