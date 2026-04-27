#!/bin/bash
#
# Interactive Repository Configuration Script
#
# Helps configure Tempest repository paths in config.json
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.claude/skills/tempest-coverage/config.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "================================================"
echo "Tempest Repository Configuration"
echo "================================================"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed${NC}"
    echo "This script requires jq for JSON manipulation"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    echo ""
    echo "Alternatively, manually edit:"
    echo "$CONFIG_FILE"
    exit 1
fi

# Backup config
BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backed up config to: $BACKUP_FILE${NC}"
echo ""

# Find Tempest repositories
echo "Searching for Tempest repositories..."
FOUND_REPOS=()

# Common locations to search
SEARCH_PATHS=(
    "$HOME/automation_projects"
    "$HOME/PycharmProjects"
    "$HOME/repos"
    "$HOME/work"
    "$HOME/projects"
)

for search_path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$search_path" ]; then
        while IFS= read -r -d '' repo; do
            if [ -f "$repo/tox.ini" ] || [ -f "$repo/setup.cfg" ]; then
                FOUND_REPOS+=("$repo")
            fi
        done < <(find "$search_path" -maxdepth 2 -type d -name "*tempest*" -print0 2>/dev/null)
    fi
done

if [ ${#FOUND_REPOS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No Tempest repositories found automatically${NC}"
    echo ""
    echo "Please provide paths manually."
    echo ""
else
    echo -e "${GREEN}Found ${#FOUND_REPOS[@]} Tempest repositories:${NC}"
    for i in "${!FOUND_REPOS[@]}"; do
        echo "  $((i+1)). ${FOUND_REPOS[$i]}"
    done
    echo ""
fi

# Interactive configuration
echo "Let's configure your repository paths..."
echo ""

# Tempest core
echo -e "${BLUE}Tempest Core Repository:${NC}"
read -p "Path to tempest core repo (or press Enter to skip): " TEMPEST_CORE
if [ -n "$TEMPEST_CORE" ]; then
    # Expand ~ to home directory
    TEMPEST_CORE="${TEMPEST_CORE/#\~/$HOME}"
    if [ -d "$TEMPEST_CORE" ]; then
        echo -e "${GREEN}✓ Path exists: $TEMPEST_CORE${NC}"
        # Update config
        jq --arg path "$TEMPEST_CORE" '.default_repo_paths.tempest = [$path]' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        echo -e "${YELLOW}! Path does not exist: $TEMPEST_CORE${NC}"
    fi
fi
echo ""

# Service plugins
SERVICES=("cinder" "manila" "glance" "barbican" "keystone")

for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}${service^}-tempest-plugin:${NC}"
    read -p "Path to ${service}-tempest-plugin (or press Enter to skip): " SERVICE_PATH

    if [ -n "$SERVICE_PATH" ]; then
        SERVICE_PATH="${SERVICE_PATH/#\~/$HOME}"
        if [ -d "$SERVICE_PATH" ]; then
            echo -e "${GREEN}✓ Path exists: $SERVICE_PATH${NC}"
            # Update config
            jq --arg service "$service" --arg path "$SERVICE_PATH" \
                '.default_repo_paths.plugins[$service + "-tempest-plugin"] = [$path]' \
                "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        else
            echo -e "${YELLOW}! Path does not exist: $SERVICE_PATH${NC}"
        fi
    fi
    echo ""
done

# Verify configuration
echo "================================================"
echo "Configuration Updated"
echo "================================================"
echo ""
echo "Current repository paths in config:"
jq '.default_repo_paths' "$CONFIG_FILE"
echo ""

echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"
echo -e "${GREEN}✓ Backup available at: $BACKUP_FILE${NC}"
echo ""

echo "You can now test the skills with:"
echo "  cd $PROJECT_ROOT"
echo "  claude"
echo "  /jira-coverage-analysis <ticket>"
