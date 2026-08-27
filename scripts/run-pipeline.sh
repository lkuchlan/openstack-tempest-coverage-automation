#!/bin/bash
# Called by the systemd timer every 4 hours.
# Pulls the latest skills and runs the pipeline.
#
# Stage machine (bash-level, not AI-level):
#   Discovery → DISCOVERED → ANALYZED → AWAITING_APPROVAL → APPROVED → IMPLEMENTING → VERIFYING → VERIFIED → (fork push) → (manual git review)
#
# Each stage calls one claude skill session. Bash manages state transitions.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${HOME}/.config/tempest-pipeline/.env"
LOG_DIR="${HOME}/.claude/orchestrator-state/logs"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m-%d).log"
STATE_FILE="${HOME}/.claude/orchestrator-state/pipeline-state.json"

VALIDATE_SCRIPT="${REPO_DIR}/scripts/validate-artifact.sh"

mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$STATE_FILE")"

# Validate a stage artifact file. Returns 0 if valid, 1 if missing/invalid.
validate_artifact() {
    local ticket="$1" stage="$2"
    if [ -x "$VALIDATE_SCRIPT" ]; then
        "$VALIDATE_SCRIPT" "$ticket" "$stage" 2>&1 | tee -a "$LOG_FILE" || return 1
    fi
    return 0
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# ── State helpers ─────────────────────────────────────────────────────────────

state_init() {
    if [ ! -f "$STATE_FILE" ] || ! jq -e . "$STATE_FILE" >/dev/null 2>&1; then
        echo '{"version":1,"last_run":null,"tickets":{},"parallel_execution_batch":null,"discovery":{}}' > "$STATE_FILE"
    fi
}

tickets_at_stage() {
    local stage="$1"
    jq -r --arg s "$stage" '.tickets | to_entries[] | select(.value.stage == $s) | .key' "$STATE_FILE" 2>/dev/null || true
}

advance_ticket() {
    local ticket="$1" new_stage="$2"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg t "$ticket" --arg s "$new_stage" --arg ts "$ts" \
        '.tickets[$t].stage = $s
       | .tickets[$t].entered_stage_at = $ts
       | .tickets[$t].history += [{"stage": $s, "at": $ts}]' \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    log "$ticket: → $new_stage"
}

add_discovered_ticket() {
    local ticket="$1"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Only add if not already tracked
    if ! jq -e --arg t "$ticket" '.tickets[$t]' "$STATE_FILE" >/dev/null 2>&1; then
        jq --arg t "$ticket" --arg ts "$ts" \
            '.tickets[$t] = {"ticket_id": $t, "stage": "DISCOVERED", "entered_stage_at": $ts,
                             "history": [{"stage": "DISCOVERED", "at": $ts}]}' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        log "Discovered: $ticket"
    fi
}

update_last_run() {
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq --arg ts "$ts" '.last_run = $ts' "$STATE_FILE" > "${STATE_FILE}.tmp" \
        && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# ── Load config ───────────────────────────────────────────────────────────────

log "=== Pipeline run starting ==="

if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    set -a; source "$CONFIG_FILE"; set +a
else
    log "ERROR: Config file not found: $CONFIG_FILE"
    log "Run scripts/vm-setup.sh first."
    exit 1
fi

export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export GOOGLE_APPLICATION_CREDENTIALS="${GOOGLE_APPLICATION_CREDENTIALS:-}"

for var in JIRA_URL JIRA_USERNAME JIRA_API_TOKEN PIPELINE_JQL; do
    if [ -z "${!var:-}" ]; then
        log "ERROR: $var is not set in $CONFIG_FILE"
        exit 1
    fi
done

# ── Update Claude Code ────────────────────────────────────────────────────────

log "Updating Claude Code..."
sudo npm update -g @anthropic-ai/claude-code 2>&1 | tee -a "$LOG_FILE" || {
    log "WARNING: Claude Code update failed, continuing with current version"
}
log "Claude Code version: $(claude --version 2>/dev/null || echo 'unknown')"

# ── Pull latest skills ────────────────────────────────────────────────────────

log "Pulling latest skills from origin/main..."
PULL_BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)
git -C "$REPO_DIR" pull --ff-only origin main 2>&1 | tee -a "$LOG_FILE" || {
    log "WARNING: git pull failed (local changes?), continuing"
}
PULL_AFTER=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)
# Re-exec with the new script if pull changed it — avoids bash running a stale
# in-memory buffer of the old version for the remainder of the run.
if [ -n "$PULL_BEFORE" ] && [ "$PULL_BEFORE" != "$PULL_AFTER" ]; then
    log "Script updated (${PULL_BEFORE:0:8} → ${PULL_AFTER:0:8}) — re-executing..."
    exec bash --login "$0" "$@"
fi

cd "$REPO_DIR"
state_init

# ── STAGE 1: Discovery ────────────────────────────────────────────────────────
# Ask Claude to query Jira and output ticket IDs, one per line.
log "Discovering tickets via JQL: ${PIPELINE_JQL}"

DISCOVERY_OUTPUT=$(claude --permission-mode bypassPermissions \
    -p "Query Jira for tickets matching this JQL: ${PIPELINE_JQL}
Use the mcp__mcp-atlassian__jira_search tool.
Output ONLY the ticket keys, one per line, nothing else. Example:
OSPRH-12345
OSPRH-67890" 2>&1 | tee -a "$LOG_FILE") || true

# Add any newly discovered tickets to state
while IFS= read -r line; do
    if [[ "$line" =~ ^[A-Z][A-Z0-9_]+-[0-9]+$ ]]; then
        add_discovered_ticket "$line"
    fi
done <<< "$DISCOVERY_OUTPUT"

# ── STAGE 2: DISCOVERED → ANALYZED ───────────────────────────────────────────
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Analyzing: $ticket"
    if claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /jira-coverage-analysis $ticket" \
        2>&1 | tee -a "$LOG_FILE" && validate_artifact "$ticket" "analysis"; then
        advance_ticket "$ticket" "ANALYZED"
    else
        log "WARNING: Analysis failed for $ticket (or artifact missing), leaving at DISCOVERED"
    fi
done <<< "$(tickets_at_stage DISCOVERED)"

# ── STAGE 3: ANALYZED → AWAITING_APPROVAL ────────────────────────────────────
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Posting test plan for: $ticket"
    if claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /post-test-plan $ticket" \
        2>&1 | tee -a "$LOG_FILE" && validate_artifact "$ticket" "plan"; then
        advance_ticket "$ticket" "AWAITING_APPROVAL"
    else
        log "WARNING: Plan posting failed for $ticket (or artifact missing), leaving at ANALYZED"
    fi
done <<< "$(tickets_at_stage ANALYZED)"

# ── STAGE 4: AWAITING_APPROVAL (check for approval) ──────────────────────────
# Use the orchestrator to check approval status for each waiting ticket.
# The orchestrator's approval-monitor handles comments and transitions to APPROVED.
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Checking approval for: $ticket"
    claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously. /tempest-coverage-orchestrator $ticket" \
        2>&1 | tee -a "$LOG_FILE" || log "WARNING: approval check failed for $ticket"
done <<< "$(tickets_at_stage AWAITING_APPROVAL)"

# ── STAGE 5: APPROVED → IMPLEMENTING ─────────────────────────────────────────
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Implementing tests for: $ticket"
    if claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /implement-tempest-tests $ticket" \
        2>&1 | tee -a "$LOG_FILE" && validate_artifact "$ticket" "implementation"; then
        advance_ticket "$ticket" "IMPLEMENTING"
    else
        log "WARNING: Implementation failed for $ticket (or artifact missing)"
    fi
done <<< "$(tickets_at_stage APPROVED)"

# ── STAGE 5.6: IMPLEMENTING → VERIFYING (automated code review) ──────────────
# A Claude agent reads each generated test file and checks Tempest standard
# compliance beyond pep8/py3: base classes, waiters, cleanup, service clients,
# test independence, decorators.
# Pass → VERIFYING   Fail → CODE_REVIEW_FAILED (terminal)
PLUGINS_WORKSPACE="${HOME}/tempest-workspace"
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Code-reviewing tests for: $ticket"

    # Resolve repo path and branch — prefer state, fall back to convention
    IMPL_REPO=$(jq -r --arg t "$ticket" \
        '.tickets[$t].implementation_details.repository_path // empty' "$STATE_FILE" 2>/dev/null || true)
    IMPL_BRANCH=$(jq -r --arg t "$ticket" \
        '.tickets[$t].implementation_details.branch // empty' "$STATE_FILE" 2>/dev/null || true)
    [ -z "$IMPL_BRANCH" ] && IMPL_BRANCH="tempest-coverage-$ticket"

    if [ -z "$IMPL_REPO" ]; then
        IMPL_REPO=$(find "$PLUGINS_WORKSPACE" -maxdepth 2 -name .git | while IFS= read -r dotgit; do
            r=$(dirname "$dotgit")
            git -C "$r" branch 2>/dev/null | grep -q "$IMPL_BRANCH" && echo "$r" && break
        done || true)
    fi

    if [ -z "$IMPL_REPO" ] || [ ! -d "$IMPL_REPO" ]; then
        log "WARNING: $ticket — cannot locate implementation repo, advancing to VERIFYING"
        advance_ticket "$ticket" "VERIFYING"
        continue
    fi

    TEST_FILES=$(git -C "$IMPL_REPO" diff "origin/master...$IMPL_BRANCH" --name-only 2>/dev/null \
        | grep '\.py$' || true)

    if [ -z "$TEST_FILES" ]; then
        log "WARNING: $ticket — no Python files found in $IMPL_BRANCH, advancing to VERIFYING"
        advance_ticket "$ticket" "VERIFYING"
        continue
    fi

    # Build full paths for Claude
    FULL_PATHS=$(echo "$TEST_FILES" | sed "s|^|$IMPL_REPO/|")

    REVIEW_OUTPUT=$(claude --permission-mode bypassPermissions -p "
You are reviewing Tempest test code for standards compliance.

Repository: $IMPL_REPO
Branch: $IMPL_BRANCH
Files to review (one per line):
$FULL_PATHS

Read each file listed above and check for ALL of the following violations:
1. Class does NOT inherit from a proper Tempest base class (BaseVolumeTest, BaseSharesTest, etc.)
2. time.sleep() is used instead of waiters.wait_for_*
3. Resources created without addCleanup() or a helper that handles cleanup
4. Raw HTTP (requests / urllib) used instead of service clients (self.*_client)
5. Shared state between test methods (class-level mutable resources)
6. Missing @decorators.idempotent_id or @decorators.attr decorators

If ALL checks pass output exactly: CODE_REVIEW_PASSED
If any violation found output: CODE_REVIEW_FAILED: <brief list of violations>
Output nothing else." 2>&1 | tee -a "$LOG_FILE") || true

    if echo "$REVIEW_OUTPUT" | grep -q "CODE_REVIEW_PASSED"; then
        advance_ticket "$ticket" "VERIFYING"
    else
        log "WARNING: Code review failed for $ticket"
        advance_ticket "$ticket" "CODE_REVIEW_FAILED"
    fi
done <<< "$(tickets_at_stage IMPLEMENTING)"

# ── STAGE 5.7: VERIFYING → VERIFIED / VERIFICATION_SKIPPED ───────────────────
# Runs the generated tests against a real OpenStack deployment on DevStack.
# Pass → VERIFIED (skill posts ✅ Jira comment with git review instructions)
# Fail → VERIFICATION_SKIPPED (posts ⚠️ + 🚀 Jira comment; manual verify needed)
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Verifying tests on DevStack for: $ticket"
    VERIFY_OUTPUT=$(claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /verify-tempest-devstack $ticket" \
        2>&1 | tee -a "$LOG_FILE") || true
    # Prefer artifact file over stdout parsing for verification status
    ARTIFACT_STATUS=""
    ARTIFACT_FILE="${HOME}/.claude/orchestrator-state/${ticket}/verification.json"
    if [ -f "$ARTIFACT_FILE" ]; then
        ARTIFACT_STATUS=$(python3 -c "import json,sys; d=json.load(open('$ARTIFACT_FILE')); print(d.get('verification_status',''))" 2>/dev/null || true)
    fi
    if [ "$ARTIFACT_STATUS" = "PASSED" ] || echo "$VERIFY_OUTPUT" | grep -q "Overall Status: PASSED"; then
        jq --arg t "$ticket" '.tickets[$t].devstack_verification_result = "passed"' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        advance_ticket "$ticket" "VERIFIED"
    else
        log "WARNING: DevStack verification did not pass for $ticket — advancing to VERIFICATION_SKIPPED"
        jq --arg t "$ticket" '.tickets[$t].devstack_verification_result = "skipped"' \
            "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        # Read implementation details for Gerrit submission instructions
        SKIP_BRANCH=$(jq -r --arg t "$ticket" '.tickets[$t].implementation_details.branch // empty' "$STATE_FILE" 2>/dev/null || true)
        SKIP_REPO=$(jq -r --arg t "$ticket" '.tickets[$t].implementation_details.repository_path // empty' "$STATE_FILE" 2>/dev/null || true)
        SKIP_FILE=$(jq -r --arg t "$ticket" '.tickets[$t].implementation_details.test_files[0] // empty' "$STATE_FILE" 2>/dev/null || true)
        SKIP_PLUGIN=$(basename "${SKIP_REPO:-}" 2>/dev/null || true)
        [ -z "$SKIP_BRANCH" ] && SKIP_BRANCH="tempest-coverage-$ticket"
        claude --permission-mode bypassPermissions -p \
"Post a comment to Jira ticket $ticket using mcp__mcp-atlassian__jira_add_comment. Use this exact Markdown:

⚠️ **DevStack Verification Skipped**

The automated DevStack environment could not complete verification for this ticket. The implementation passed automated code review for Tempest standards compliance.

**Recommended:** Run manual verification against a live OpenStack environment before merging.

---

🚀 **Submit to Gerrit**

The implementation branch has been pushed to GitHub. Run the following inside your \`$SKIP_PLUGIN\` clone:

\`\`\`
git fetch ssh://git@github.com/lkuchlan/$SKIP_PLUGIN $SKIP_BRANCH
git checkout $SKIP_BRANCH
git review
\`\`\`

**Branch:** \`$SKIP_BRANCH\`
**Fork:** github.com/lkuchlan/$SKIP_PLUGIN
**File:** \`$SKIP_FILE\`

After your patch is merged to Gerrit, the branch can be deleted from the fork.

Output only the tool call result." \
            2>&1 | tee -a "$LOG_FILE" || log "WARNING: could not post DevStack warning to Jira for $ticket"
        advance_ticket "$ticket" "VERIFICATION_SKIPPED"
    fi
done <<< "$(tickets_at_stage VERIFYING)"

# ── STAGE 5.8: Sync GitHub forks with upstream ───────────────────────────────
# Keep fork master branches current so feature branches are based on recent code.
log "Syncing GitHub forks with upstream..."
FORK_CONFIG="$REPO_DIR/skills/orchestrator/config.json"
SSH_KEY="${HOME}/.ssh/github_fork_push"
PLUGINS_WORKSPACE="${HOME}/tempest-workspace"

python3 -c "
import json, sys
cfg = json.load(open('$FORK_CONFIG'))
for plugin, url in cfg.get('verification', {}).get('github_forks', {}).items():
    print(f'{plugin} {url}')
" 2>/dev/null | while IFS=' ' read -r plugin fork_url; do
    repo_path="$PLUGINS_WORKSPACE/$plugin"
    [ -d "$repo_path/.git" ] || continue

    git -C "$repo_path" fetch origin --quiet 2>&1 | tee -a "$LOG_FILE" || true

    GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
        git -C "$repo_path" remote set-url fork-push "$fork_url" 2>/dev/null \
        || GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
           git -C "$repo_path" remote add fork-push "$fork_url"

    if GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
        git -C "$repo_path" push fork-push "origin/HEAD:refs/heads/master" \
        --force-with-lease 2>&1 | tee -a "$LOG_FILE"; then
        log "$plugin fork synced with upstream"
    else
        log "WARNING: $plugin fork sync failed (continuing)"
    fi
done

# ── STAGE 6: Push VERIFIED / VERIFICATION_SKIPPED branches to GitHub fork ────
# Deterministic bash-level push — more reliable than asking Claude to run git.
# Reads implementation_details from pipeline-state.json and pushes each branch.
FORK_CONFIG="$REPO_DIR/skills/orchestrator/config.json"
SSH_KEY="${HOME}/.ssh/github_fork_push"

while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue

    REPO_PATH=$(jq -r --arg t "$ticket" \
        '.tickets[$t].implementation_details.repository_path // empty' "$STATE_FILE" 2>/dev/null || true)
    BRANCH=$(jq -r --arg t "$ticket" \
        '.tickets[$t].implementation_details.branch // empty' "$STATE_FILE" 2>/dev/null || true)

    if [ -z "$REPO_PATH" ] || [ -z "$BRANCH" ]; then
        log "WARNING: $ticket — no implementation_details, skipping fork push"
        continue
    fi

    PLUGIN=$(basename "$REPO_PATH")
    FORK_URL=$(python3 -c "
import json, sys
cfg = json.load(open('$FORK_CONFIG'))
forks = cfg.get('verification', {}).get('github_forks', {})
print(forks.get('$PLUGIN', ''))
" 2>/dev/null)

    if [ -z "$FORK_URL" ]; then
        log "WARNING: $ticket — no fork configured for $PLUGIN, skipping push"
        continue
    fi

    if [ ! -d "$REPO_PATH" ]; then
        log "WARNING: $ticket — repo not found at $REPO_PATH, skipping push"
        continue
    fi

    # Check if branch already pushed (avoid redundant pushes)
    if GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
        git -C "$REPO_PATH" ls-remote --exit-code fork-push "$BRANCH" >/dev/null 2>&1; then
        log "$ticket: branch $BRANCH already in fork, skipping"
        continue
    fi

    log "$ticket: pushing $BRANCH to $FORK_URL..."
    GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
        git -C "$REPO_PATH" remote set-url fork-push "$FORK_URL" 2>/dev/null \
        || GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
           git -C "$REPO_PATH" remote add fork-push "$FORK_URL"

    if GIT_SSH_COMMAND="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
        git -C "$REPO_PATH" push fork-push "$BRANCH" 2>&1 | tee -a "$LOG_FILE"; then
        log "$ticket: ✅ pushed to github.com/lkuchlan/$PLUGIN"
    else
        log "WARNING: $ticket — fork push failed for $BRANCH"
    fi
done <<< "$(tickets_at_stage VERIFIED; tickets_at_stage VERIFICATION_SKIPPED)"

update_last_run
log "=== Pipeline run complete ==="

# ── Auto git-review if enabled ────────────────────────────────────────────────
if [ "${AUTO_GIT_REVIEW:-false}" = "true" ]; then
    log "AUTO_GIT_REVIEW enabled — checking for VERIFIED / VERIFICATION_SKIPPED tickets..."
    for ticket in $(tickets_at_stage VERIFIED; tickets_at_stage VERIFICATION_SKIPPED); do
        log "Auto-submitting $ticket via git review..."
        PLUGIN_DIR=$(jq -r --arg t "$ticket" \
            '.tickets[$t].implementation_details.repository_path // empty' "$STATE_FILE" 2>/dev/null || true)
        BRANCH=$(jq -r --arg t "$ticket" \
            '.tickets[$t].implementation_details.branch // empty' "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ] && [ -n "$BRANCH" ]; then
            git -C "$PLUGIN_DIR" checkout "$BRANCH" 2>/dev/null && \
            git -C "$PLUGIN_DIR" review && \
            claude -p "/tempest-coverage-orchestrator $ticket --submitted <gerrit-url>" \
                2>&1 | tee -a "$LOG_FILE" || \
            log "WARNING: git review failed for $ticket"
        fi
    done
fi
