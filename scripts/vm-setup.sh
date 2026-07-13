#!/bin/bash
# One-time setup for the qe-agent VM (Ubuntu 22.04) that runs the tempest coverage pipeline.
# Run as the automation user (ubuntu), not root.
set -euo pipefail

REPO_URL="${TEMPEST_PIPELINE_REPO:-https://github.com/lkuchlan/openstack-tempest-coverage-automation.git}"
REPO_DIR="$HOME/openstack-tempest-coverage-automation"
WORKSPACE="$HOME/tempest-workspace"
CONFIG_DIR="$HOME/.config/tempest-pipeline"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

echo "=== qe-agent: Tempest Coverage Pipeline Setup ==="
echo ""

# ── 1. System packages ─────────────────────────────────────────────────────────
echo "[1/7] Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y \
    git \
    python3 \
    python3-pip \
    openssh-client \
    curl \
    jq \
    ca-certificates \
    gnupg

pip3 install --quiet tox uv

# ── 2. Node.js + Claude Code CLI ──────────────────────────────────────────────
echo "[2/7] Installing Node.js 20 and Claude Code CLI..."
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
echo "  Node.js: $(node --version)"

if ! command -v claude &>/dev/null; then
    sudo npm install -g @anthropic-ai/claude-code
else
    echo "  Claude Code already installed."
fi
echo "  Claude Code: $(claude --version 2>/dev/null || echo 'installed')"

# ── 3. Clone / update the automation repo ─────────────────────────────────────
echo "[3/7] Setting up automation repo..."
if [ -d "$REPO_DIR/.git" ]; then
    echo "  Repo exists — pulling latest..."
    git -C "$REPO_DIR" pull --ff-only origin main
else
    echo "  Cloning $REPO_URL..."
    git clone "$REPO_URL" "$REPO_DIR"
fi
chmod +x "$REPO_DIR/scripts/"*.sh

# ── 4. Clone tempest plugin repos ─────────────────────────────────────────────
echo "[4/7] Cloning tempest plugin repos into $WORKSPACE..."
mkdir -p "$WORKSPACE"

declare -A REPOS=(
    ["tempest"]="https://opendev.org/openstack/tempest.git"
    ["cinder-tempest-plugin"]="https://opendev.org/openstack/cinder-tempest-plugin.git"
    ["manila-tempest-plugin"]="https://opendev.org/openstack/manila-tempest-plugin.git"
    ["glance-tempest-plugin"]="https://opendev.org/openstack/glance-tempest-plugin.git"
    ["barbican-tempest-plugin"]="https://opendev.org/openstack/barbican-tempest-plugin.git"
)

for name in "${!REPOS[@]}"; do
    target="$WORKSPACE/$name"
    if [ -d "$target/.git" ]; then
        echo "  $name: pulling..."
        git -C "$target" pull --ff-only 2>/dev/null || echo "  $name: skipped (local changes)"
    else
        echo "  Cloning $name..."
        git clone "${REPOS[$name]}" "$target" --depth=1 || echo "  WARNING: failed to clone $name"
    fi
done

# ── 5. Create config + .env template ──────────────────────────────────────────
echo "[5/7] Creating config..."
mkdir -p "$CONFIG_DIR"

ENV_FILE="$CONFIG_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << 'EOF'
# Jira credentials
JIRA_URL=https://your-org.atlassian.net
JIRA_USERNAME=your-email@example.com
JIRA_API_TOKEN=your-jira-api-token

# JQL filter — tickets the pipeline will process
PIPELINE_JQL='project = YOURPROJECT AND labels = "agentic-tempest-coverage" AND status != Done'

# DevStack VM (for verify-tempest-devstack skill)
DEVSTACK_HOST=
DEVSTACK_USER=ubuntu
DEVSTACK_SSH_KEY=$HOME/.ssh/devstack_key
DEVSTACK_ADMIN_PASSWORD=
DEVSTACK_DB_PASSWORD=
DEVSTACK_RABBIT_PASSWORD=
DEVSTACK_SERVICE_PASSWORD=

# Claude Code authentication — Google Vertex AI:
CLAUDE_CODE_USE_VERTEX=1
ANTHROPIC_VERTEX_PROJECT_ID=your-gcp-project-id
GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/gcloud/application_default_credentials.json
# (copy your GCP application_default_credentials.json from your Mac to the path above)
#
# Alternative — Direct Anthropic API key:
# Unset the three vars above and instead set:
# ANTHROPIC_API_KEY=sk-ant-...

# Set to 'true' to automatically run 'git review' after a ticket is VERIFIED
AUTO_GIT_REVIEW=false
EOF
    echo "  Created $ENV_FILE"
    echo "  *** EDIT THIS FILE with your credentials before starting the timer ***"
else
    echo "  $ENV_FILE already exists — skipping."
fi

# ── 6. Register Claude Code skills ────────────────────────────────────────────
echo "[6/9] Registering Claude Code skills..."
mkdir -p "$HOME/.claude/skills"
for skill in orchestrator jira-coverage-analysis post-test-plan implement-tempest-tests verify-tempest-devstack; do
    ln -sfn "$REPO_DIR/skills/$skill" "$HOME/.claude/skills/$skill"
    echo "  Linked: $skill"
done

# ── 7. Install systemd user timer ─────────────────────────────────────────────
echo "[7/9] Installing systemd user timer..."
mkdir -p "$SYSTEMD_USER_DIR"

cp "$REPO_DIR/systemd/tempest-pipeline.service" "$SYSTEMD_USER_DIR/"
cp "$REPO_DIR/systemd/tempest-pipeline.timer"   "$SYSTEMD_USER_DIR/"

# Enable lingering so user services start at boot (without login)
loginctl enable-linger "$USER" 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user enable tempest-pipeline.timer
echo "  Timer installed and enabled."

# ── 7. Create log directory ────────────────────────────────────────────────────
echo "[8/9] Creating log directory..."
mkdir -p "$HOME/.claude/orchestrator-state/logs"

# ── 9. GitHub fork push key ───────────────────────────────────────────────────
echo "[9/9] Setting up GitHub fork push SSH key..."
FORK_KEY="$HOME/.ssh/github_fork_push"

if [ ! -f "$FORK_KEY" ]; then
    ssh-keygen -t ed25519 -f "$FORK_KEY" -C "agentic-pipeline-fork-push" -N ""
    echo ""
    echo "  === GitHub fork push key generated ==="
    echo "  Add the following public key to each GitHub fork with WRITE access:"
    echo "  (fork Settings → Deploy keys → Add deploy key → check 'Allow write access')"
    echo ""
    cat "$FORK_KEY.pub"
    echo ""
else
    echo "  Fork push key already exists: $FORK_KEY"
fi

if ! grep -q "github_fork_push" "$HOME/.ssh/config" 2>/dev/null; then
    mkdir -p "$HOME/.ssh"
    cat >> "$HOME/.ssh/config" << 'EOF'

Host github-fork
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_fork_push
  IdentitiesOnly yes
EOF
    echo "  Added github-fork host to ~/.ssh/config"
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Fill in credentials + Claude auth:"
echo "       nano $ENV_FILE"
echo "     Uncomment ANTHROPIC_API_KEY or GOOGLE_APPLICATION_CREDENTIALS"
echo "     (see comments in the file for which to use)"
echo ""
echo "  2. Add the fork push public key ($FORK_KEY.pub) to each GitHub fork"
echo "     with WRITE access (Settings → Deploy keys)."
echo "     Forks needed: cinder-tempest-plugin, manila-tempest-plugin,"
echo "     glance-tempest-plugin, barbican-tempest-plugin"
echo ""
echo "  3. Start the pipeline timer:"
echo "       systemctl --user start tempest-pipeline.timer"
echo ""
echo "  4. Test manually:"
echo "       bash $REPO_DIR/scripts/run-pipeline.sh"
echo ""
echo "  5. Check timer status:"
echo "       systemctl --user status tempest-pipeline.timer"
