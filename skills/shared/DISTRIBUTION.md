# Distribution Guide - Tempest Coverage Skill

How to package, share, and distribute the Tempest Coverage skill as a plugin.

## Overview

This skill can be distributed as:
1. **Git Repository** - Clone and install
2. **Claude Code Plugin** - (Future: When plugin registry is available)
3. **Team Package** - Internal company distribution

## Option 1: Git Repository Distribution

### Step 1: Create a Git Repository

```bash
cd ~/.claude/skills/tempest-coverage

# Initialize git
git init

# Create .gitignore
cat > .gitignore <<EOF
# User-specific config
config.local.json
*.local.json

# System files
.DS_Store
__pycache__/
*.pyc

# IDE
.idea/
.vscode/
EOF

# Initial commit
git add .
git commit -m "Initial release of Tempest Coverage skill v1.0

Features:
- Automated Jira ticket analysis
- Intelligent code discovery
- Pattern-based test implementation
- Upstream standards compliance
- Automatic validation with tox
- Git workflow automation
- Memory-based learning
"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/your-org/claude-tempest-coverage-skill.git

# Push
git push -u origin main
```

### Step 2: Add Installation Instructions

Create `INSTALL.md`:

```markdown
# Installation

## Prerequisites
- Claude Code installed
- Local Tempest repositories

## Install from Git

\`\`\`bash
# Clone into Claude skills directory
git clone https://github.com/your-org/claude-tempest-coverage-skill.git \\
  ~/.claude/skills/tempest-coverage

# Configure your repository paths
cp ~/.claude/skills/tempest-coverage/config.json \\
   ~/.claude/skills/tempest-coverage/config.local.json

# Edit config.local.json with your paths
vi ~/.claude/skills/tempest-coverage/config.local.json
\`\`\`

## Verify Installation

\`\`\`bash
# List skills
ls ~/.claude/skills/

# Should show: tempest-coverage/
\`\`\`

## Test

Start Claude Code and run:
\`\`\`
/tempest-coverage --help
\`\`\`

## See QUICKSTART.md for usage examples
```

### Step 3: Create Release

```bash
# Tag version
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"

# Push tags
git push origin v1.0.0

# Create GitHub release
gh release create v1.0.0 \\
  --title "Tempest Coverage Skill v1.0.0" \\
  --notes "First stable release with core features"
```

### Step 4: Share with Users

Users install with:
```bash
git clone https://github.com/your-org/claude-tempest-coverage-skill.git \\
  ~/.claude/skills/tempest-coverage
```

---

## Option 2: Claude Code Plugin (Future)

When Claude Code supports a plugin registry:

### Create plugin.json

```json
{
  "name": "tempest-coverage",
  "version": "1.0.0",
  "description": "Automated Tempest test coverage analysis and implementation",
  "author": "Your Name <email@example.com>",
  "license": "Apache-2.0",
  "homepage": "https://github.com/your-org/claude-tempest-coverage-skill",
  "repository": {
    "type": "git",
    "url": "https://github.com/your-org/claude-tempest-coverage-skill.git"
  },
  "keywords": [
    "openstack",
    "tempest",
    "testing",
    "qe",
    "automation"
  ],
  "claude": {
    "min_version": "4.5.0"
  },
  "skills": [
    {
      "name": "tempest-coverage",
      "file": "skill.md",
      "config": "config.json"
    }
  ],
  "dependencies": {},
  "files": [
    "skill.md",
    "config.json",
    "README.md",
    "templates/"
  ]
}
```

### Publish to Registry

```bash
# Future command (when available)
claude plugin publish
```

Users install with:
```bash
# Future command
claude plugin install tempest-coverage
```

---

## Option 3: Internal Team Distribution

### Create Team Package

```bash
# Create distributable archive
cd ~/.claude/skills/
tar -czf tempest-coverage-v1.0.0.tar.gz tempest-coverage/

# Or create zip
zip -r tempest-coverage-v1.0.0.zip tempest-coverage/
```

### Share Internally

**Via Internal Git Server:**
```bash
# Push to internal GitLab/GitHub
git remote add internal https://git.company.com/tools/claude-tempest-coverage.git
git push internal main
```

**Via Network Share:**
```bash
# Copy to shared drive
cp tempest-coverage-v1.0.0.tar.gz /mnt/shared/claude-skills/
```

### Team Installation

```bash
# From internal Git
git clone https://git.company.com/tools/claude-tempest-coverage.git \\
  ~/.claude/skills/tempest-coverage

# From archive
cd ~/.claude/skills/
tar -xzf /mnt/shared/claude-skills/tempest-coverage-v1.0.0.tar.gz
```

---

## Customization for Distribution

### Allow User Configuration

Support user-specific config without modifying the main config:

```bash
# In skill.md, add logic to load config.local.json if it exists
# config.local.json overrides config.json
```

Example structure:
```
~/.claude/skills/tempest-coverage/
├── skill.md              # Main skill (tracked in git)
├── config.json           # Default config (tracked in git)
├── config.local.json     # User overrides (gitignored)
├── README.md             # Documentation
└── templates/            # Templates
```

### Support Multiple Environments

Create environment-specific configs:

```bash
~/.claude/skills/tempest-coverage/configs/
├── development.json      # Dev environment paths
├── staging.json          # Staging environment
└── production.json       # Production environment
```

Users can symlink:
```bash
ln -s configs/development.json config.local.json
```

---

## Versioning Strategy

### Semantic Versioning

Follow semver: MAJOR.MINOR.PATCH

- **MAJOR**: Breaking changes (e.g., skill.md structure changes)
- **MINOR**: New features (e.g., support for new services)
- **PATCH**: Bug fixes (e.g., template corrections)

Examples:
- `v1.0.0` - Initial stable release
- `v1.1.0` - Added Neutron support
- `v1.1.1` - Fixed template bug
- `v2.0.0` - Restructured skill workflow (breaking change)

### Changelog

Maintain `CHANGELOG.md`:

```markdown
# Changelog

## [1.1.0] - 2026-04-27
### Added
- Support for Neutron tempest plugin
- New scenario test template
- Memory optimization for large repos

### Changed
- Improved pattern discovery performance
- Updated validation timeout to 5min

### Fixed
- Fixed git branch naming with special characters

## [1.0.0] - 2026-04-26
### Added
- Initial release
- Core workflow implementation
- Support for Cinder, Manila, Glance, Barbican
- Automatic validation
- Git workflow automation
```

---

## Documentation Package

Include these files for complete distribution:

```
tempest-coverage/
├── skill.md              # Core skill definition
├── config.json           # Default configuration
├── README.md             # Main documentation
├── QUICKSTART.md         # Quick start guide
├── EXAMPLES.md           # Real-world examples
├── DISTRIBUTION.md       # This file
├── INSTALL.md            # Installation instructions
├── CHANGELOG.md          # Version history
├── LICENSE               # Apache 2.0 license
├── templates/
│   ├── api_test_template.py
│   └── scenario_test_template.py
└── .gitignore
```

---

## Testing Before Distribution

### Validation Checklist

Before releasing, test:

- [ ] Fresh installation in clean environment
- [ ] Config.json defaults work
- [ ] Templates are valid Python
- [ ] README examples are accurate
- [ ] Skill invocation works: `/tempest-coverage`
- [ ] Git workflow creates proper branches
- [ ] Validation (tox) runs successfully
- [ ] Memory integration works
- [ ] Works with missing repos (graceful degradation)

### Test Script

```bash
#!/bin/bash
# test-skill.sh - Validate skill before distribution

set -e

echo "Testing Tempest Coverage Skill..."

# 1. Check structure
echo "✓ Checking file structure..."
test -f ~/.claude/skills/tempest-coverage/skill.md
test -f ~/.claude/skills/tempest-coverage/config.json
test -f ~/.claude/skills/tempest-coverage/README.md

# 2. Validate JSON
echo "✓ Validating JSON config..."
jq empty ~/.claude/skills/tempest-coverage/config.json

# 3. Check templates
echo "✓ Checking templates..."
python -m py_compile ~/.claude/skills/tempest-coverage/templates/*.py

# 4. Test with Claude (manual)
echo "✓ Manual test required: Run /tempest-coverage in Claude Code"

echo "All automated checks passed! ✅"
```

---

## Marketing & Outreach

### Announce to Community

**Mailing List:**
```
Subject: [ANNOUNCEMENT] Claude Code Skill for Tempest Test Coverage

Hi OpenStack QE community,

I'm excited to share a new Claude Code skill that automates Tempest 
test coverage analysis and implementation.

Features:
- Automated Jira ticket analysis
- Intelligent discovery of existing patterns
- Test implementation following upstream standards
- Automatic validation with tox
- Git workflow automation

GitHub: https://github.com/your-org/claude-tempest-coverage-skill
Documentation: See README.md

Feedback welcome!
```

**Blog Post:**
Title: "Automating Tempest Test Coverage with Claude Code"

### Documentation Site

Create GitHub Pages site:

```bash
# Enable GitHub Pages
# Settings -> Pages -> Source: main branch / docs/

# Create docs/
mkdir docs/
cp README.md docs/index.md
cp QUICKSTART.md docs/quickstart.md
cp EXAMPLES.md docs/examples.md

# Add Jekyll config
cat > docs/_config.yml <<EOF
title: Tempest Coverage Skill
description: Automated test coverage for OpenStack Tempest
theme: jekyll-theme-cayman
EOF
```

Site will be available at:
`https://your-org.github.io/claude-tempest-coverage-skill/`

---

## Support & Maintenance

### Issue Tracking

Use GitHub Issues with labels:
- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Documentation improvements
- `question` - User questions
- `good-first-issue` - Good for newcomers

### Support Channels

1. **GitHub Issues** - Bug reports and features
2. **GitHub Discussions** - Q&A and community
3. **README.md** - Primary documentation
4. **EXAMPLES.md** - Usage examples

### Update Process

```bash
# Pull latest
cd ~/.claude/skills/tempest-coverage
git pull

# Review changes
git log

# Test updates
# Run validation tests

# If issues, rollback
git checkout v1.0.0
```

---

## License

Include `LICENSE` file:

```
Apache License 2.0

Copyright 2026 Your Name/Organization

Licensed under the Apache License, Version 2.0...
[Full Apache 2.0 license text]
```

Choose license that matches:
- **Apache 2.0** - Industry standard for OpenStack
- **MIT** - Permissive, simple
- **GPL-3.0** - Copyleft, ensures derivatives stay open

---

## Metrics & Analytics (Optional)

Track adoption:

```json
{
  "skill_metadata": {
    "name": "tempest-coverage",
    "version": "1.0.0",
    "telemetry": {
      "enabled": false,
      "endpoint": "https://analytics.example.com/skill-usage"
    }
  }
}
```

**Privacy**: Be transparent about any data collection!

---

## Contribution Guidelines

Create `CONTRIBUTING.md`:

```markdown
# Contributing

## How to Contribute

1. Fork the repository
2. Create feature branch: `git checkout -b feature/my-feature`
3. Make changes
4. Test thoroughly
5. Commit: `git commit -m "Add feature X"`
6. Push: `git push origin feature/my-feature`
7. Create Pull Request

## Development Setup

\`\`\`bash
git clone <your-fork>
cd claude-tempest-coverage-skill

# Make changes to skill.md or templates/

# Test locally
# (see TESTING.md)
\`\`\`

## Code Style

- Follow existing patterns in skill.md
- Keep templates PEP8 compliant
- Update EXAMPLES.md with new patterns
- Add tests for new features

## Questions?

Open an issue or discussion!
```

---

## Summary

**Distribution Checklist:**

- [ ] Create Git repository
- [ ] Add comprehensive documentation
- [ ] Version with semantic versioning
- [ ] Test in clean environment
- [ ] Add LICENSE file
- [ ] Create CONTRIBUTING.md
- [ ] Set up issue tracking
- [ ] Announce to community
- [ ] Provide support channels
- [ ] Maintain changelog

**Quick Distribution:**
```bash
git clone <source> ~/.claude/skills/tempest-coverage
```

**Professional Distribution:**
- Git repository with releases
- Documentation site
- Issue tracking
- Community support
- Regular updates

Choose the distribution method that fits your use case! 🚀
