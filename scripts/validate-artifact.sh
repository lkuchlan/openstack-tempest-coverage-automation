#!/usr/bin/env bash
# Validate that a stage artifact file exists and contains valid JSON with required fields.
# Usage: validate-artifact.sh <ticket_id> <stage>
# Returns: exit 0 (valid) or exit 1 (missing/invalid)
# Stages: analysis, plan, implementation, verification

set -euo pipefail

TICKET_ID="${1:-}"
STAGE="${2:-}"
STATE_DIR="${HOME}/.claude/orchestrator-state"

if [[ -z "$TICKET_ID" || -z "$STAGE" ]]; then
    echo "Usage: $0 <ticket_id> <stage>" >&2
    exit 1
fi

ARTIFACT_FILE="${STATE_DIR}/${TICKET_ID}/${STAGE}.json"

# Required fields per stage (top-level only — service/coverage/branch etc. live under metadata)
declare -A REQUIRED_FIELDS
REQUIRED_FIELDS[analysis]="ticket_id status"
REQUIRED_FIELDS[plan]="ticket_id status"
REQUIRED_FIELDS[implementation]="ticket_id status"
REQUIRED_FIELDS[verification]="ticket_id verification_status"

# Check file exists
if [[ ! -f "$ARTIFACT_FILE" ]]; then
    echo "❌ Artifact missing: $ARTIFACT_FILE" >&2
    exit 1
fi

# Check valid JSON
if ! python3 -c "import json, sys; json.load(sys.stdin)" < "$ARTIFACT_FILE" 2>/dev/null; then
    echo "❌ Artifact is not valid JSON: $ARTIFACT_FILE" >&2
    exit 1
fi

# Check for ERROR status (skill reported failure)
STATUS=$(python3 -c "import json, sys; d=json.load(sys.stdin); print(d.get('status', d.get('verification_status', 'UNKNOWN')))" < "$ARTIFACT_FILE" 2>/dev/null || echo "UNKNOWN")
if [[ "$STATUS" == "ERROR" ]]; then
    echo "❌ Artifact reports ERROR status for stage $STAGE" >&2
    exit 1
fi

# Check required fields exist and are non-empty
FIELDS="${REQUIRED_FIELDS[$STAGE]:-}"
for field in $FIELDS; do
    VALUE=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
# Support nested via dot notation
val = d
for k in '$field'.split('.'):
    val = val.get(k, None) if isinstance(val, dict) else None
print('present' if val is not None else 'missing')
" < "$ARTIFACT_FILE" 2>/dev/null || echo "missing")
    if [[ "$VALUE" == "missing" ]]; then
        echo "❌ Required field '$field' missing from $ARTIFACT_FILE" >&2
        exit 1
    fi
done

echo "✅ Artifact valid: ${TICKET_ID}/${STAGE}.json (status: ${STATUS})"
exit 0
