#!/bin/bash
# Called by the systemd timer every 4 hours.
# Pulls the latest skills and runs the pipeline.
#
# Stage machine (bash-level, not AI-level):
#   Discovery → DISCOVERED → ANALYZED → AWAITING_APPROVAL → (approved) → IMPLEMENTING → …
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

update_last_run
log "=== Pipeline run complete ==="

# ── Auto git-review if enabled ────────────────────────────────────────────────
if [ "${AUTO_GIT_REVIEW:-false}" = "true" ]; then
    log "AUTO_GIT_REVIEW enabled — checking for VERIFIED tickets..."
    VERIFIED=$(tickets_at_stage VERIFIED)
    for ticket in $VERIFIED; do
        log "Auto-submitting $ticket via git review..."
        BRANCH="tempest-coverage-${ticket,,}"
        PLUGIN_DIR=$(jq -r --arg t "$ticket" '.tickets[$t].metadata.plugin_repo // empty' "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR" ]; then
            git -C "$PLUGIN_DIR" checkout "$BRANCH" 2>/dev/null && \
            git -C "$PLUGIN_DIR" review && \
            claude -p "/tempest-coverage-orchestrator $ticket --submitted <gerrit-url>" 2>&1 | tee -a "$LOG_FILE" || \
            log "WARNING: git review failed for $ticket"
        fi
    done
fi
