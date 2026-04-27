#!/bin/bash
#
# Find Tempest Repositories Script
#
# Searches common locations for Tempest repositories
#

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "Searching for Tempest repositories..."
echo ""

# Search paths
SEARCH_PATHS=(
    "$HOME/automation_projects"
    "$HOME/PycharmProjects"
    "$HOME/repos"
    "$HOME/work"
    "$HOME/projects"
    "$HOME/src"
)

FOUND_TEMPEST=()
FOUND_PLUGINS=()

# Search for repositories
for search_path in "${SEARCH_PATHS[@]}"; do
    if [ ! -d "$search_path" ]; then
        continue
    fi

    echo "Searching in: $search_path"

    # Find tempest core
    if [ -d "$search_path/tempest" ]; then
        if [ -f "$search_path/tempest/tox.ini" ] || [ -f "$search_path/tempest/setup.cfg" ]; then
            FOUND_TEMPEST+=("$search_path/tempest")
        fi
    fi

    # Find plugins
    while IFS= read -r -d '' repo; do
        if [ -f "$repo/tox.ini" ] || [ -f "$repo/setup.cfg" ]; then
            REPO_NAME=$(basename "$repo")
            if [[ "$REPO_NAME" == *"-tempest-plugin" ]]; then
                FOUND_PLUGINS+=("$repo")
            fi
        fi
    done < <(find "$search_path" -maxdepth 1 -type d -name "*-tempest-plugin" -print0 2>/dev/null)
done

# Display results
echo ""
echo "================================================"
echo "Search Results"
echo "================================================"
echo ""

if [ ${#FOUND_TEMPEST[@]} -gt 0 ]; then
    echo -e "${GREEN}Tempest Core:${NC}"
    for repo in "${FOUND_TEMPEST[@]}"; do
        echo "  ✓ $repo"
    done
    echo ""
else
    echo -e "${YELLOW}Tempest Core: Not found${NC}"
    echo ""
fi

if [ ${#FOUND_PLUGINS[@]} -gt 0 ]; then
    echo -e "${GREEN}Tempest Plugins:${NC}"
    for repo in "${FOUND_PLUGINS[@]}"; do
        PLUGIN_NAME=$(basename "$repo")
        echo "  ✓ $repo"
    done
    echo ""
else
    echo -e "${YELLOW}Tempest Plugins: None found${NC}"
    echo ""
fi

# Summary
echo "================================================"
echo "Summary"
echo "================================================"
echo ""
echo "Total found:"
echo "  - Tempest core: ${#FOUND_TEMPEST[@]}"
echo "  - Plugins: ${#FOUND_PLUGINS[@]}"
echo ""

if [ ${#FOUND_TEMPEST[@]} -eq 0 ] && [ ${#FOUND_PLUGINS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No Tempest repositories found${NC}"
    echo ""
    echo "If you have Tempest repositories in other locations,"
    echo "please configure them manually:"
    echo ""
    echo "  bash scripts/setup/configure-repos.sh"
    echo ""
    echo "Or edit directly:"
    echo "  vi .claude/skills/tempest-coverage/config.json"
else
    echo -e "${GREEN}To configure these paths, run:${NC}"
    echo "  bash scripts/setup/configure-repos.sh"
fi
echo ""
