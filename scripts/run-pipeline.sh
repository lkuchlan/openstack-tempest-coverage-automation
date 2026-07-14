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

mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$STATE_FILE")"

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
git -C "$REPO_DIR" pull --ff-only origin main 2>&1 | tee -a "$LOG_FILE" || {
    log "WARNING: git pull failed (local changes?), continuing"
}

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
        2>&1 | tee -a "$LOG_FILE"; then
        advance_ticket "$ticket" "ANALYZED"
    else
        log "WARNING: Analysis failed for $ticket, leaving at DISCOVERED"
    fi
done <<< "$(tickets_at_stage DISCOVERED)"

# ── STAGE 3: ANALYZED → AWAITING_APPROVAL ────────────────────────────────────
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Posting test plan for: $ticket"
    if claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /post-test-plan $ticket" \
        2>&1 | tee -a "$LOG_FILE"; then
        advance_ticket "$ticket" "AWAITING_APPROVAL"
    else
        log "WARNING: Plan posting failed for $ticket, leaving at ANALYZED"
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
        2>&1 | tee -a "$LOG_FILE"; then
        advance_ticket "$ticket" "IMPLEMENTING"
    else
        log "WARNING: Implementation failed for $ticket"
    fi
done <<< "$(tickets_at_stage APPROVED)"

# ── STAGE 5.6: IMPLEMENTING → VERIFYING (automated code review) ──────────────
# A Claude agent reads each generated test file and checks Tempest standard
# compliance beyond pep8/py3: base classes, waiters, cleanup, service clients,
# test independence, decorators.
# Pass → VERIFYING   Fail → CODE_REVIEW_FAILED (terminal)
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Code-reviewing tests for: $ticket"
    REVIEW_OUTPUT=$(claude --permission-mode bypassPermissions -p "
You are reviewing Tempest test code for standards compliance.

Read ~/.claude/orchestrator-state/pipeline-state.json.
Get the test file(s) from .tickets[\"$ticket\"].implementation_details.test_files.
Read each test file and check for ALL of the following violations:
1. Class does NOT inherit from a proper Tempest base class (BaseVolumeTest, BaseSharesTest, etc.)
2. time.sleep() is used instead of waiters.wait_for_*
3. Resources created without addCleanup() or a helper that handles cleanup
4. Raw HTTP (requests / urllib) used instead of service clients (self.*_client)
5. Shared state between test methods (class-level mutable resources)
6. Missing @decorators.idempotent_id or @decorators.attr decorators

If ALL checks pass output exactly: CODE_REVIEW_PASSED
If any violation found output: CODE_REVIEW_FAILED: <brief list of violations>
Output nothing else." 2>&1 | tee -a "$LOG_FILE")
    if echo "$REVIEW_OUTPUT" | grep -q "CODE_REVIEW_PASSED"; then
        advance_ticket "$ticket" "VERIFYING"
    else
        log "WARNING: Code review failed for $ticket"
        advance_ticket "$ticket" "CODE_REVIEW_FAILED"
    fi
done <<< "$(tickets_at_stage IMPLEMENTING)"

# ── STAGE 5.7: VERIFYING → VERIFIED (DevStack verification) ──────────────────
# Runs the generated tests against a real OpenStack deployment on DevStack.
# Pass → VERIFIED (triggers Stage 6 fork push)
# Fail → stays VERIFYING so the next run retries
while IFS= read -r ticket; do
    [ -z "$ticket" ] && continue
    log "Verifying tests on DevStack for: $ticket"
    if claude --permission-mode bypassPermissions \
        -p "This is an automated pipeline run. Proceed autonomously — do NOT ask for confirmation. /verify-tempest-devstack $ticket" \
        2>&1 | tee -a "$LOG_FILE"; then
        advance_ticket "$ticket" "VERIFIED"
    else
        log "WARNING: DevStack verification failed for $ticket — will retry next run"
    fi
done <<< "$(tickets_at_stage VERIFYING)"

update_last_run

# ── STAGE 5.5: Sync GitHub forks with upstream ───────────────────────────────
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

# ── STAGE 6: Push VERIFIED branches to GitHub fork ───────────────────────────
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
    PLUGIN_NAME="${PLUGIN%-tempest-plugin}"
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
done <<< "$(tickets_at_stage VERIFIED)"

log "=== Pipeline run complete ==="

# ── Auto git-review if enabled ────────────────────────────────────────────────
if [ "${AUTO_GIT_REVIEW:-false}" = "true" ]; then
    log "AUTO_GIT_REVIEW enabled — checking for VERIFIED tickets..."
    for ticket in $(tickets_at_stage VERIFIED); do
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
