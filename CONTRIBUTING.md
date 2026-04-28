# Contributing to OpenStack Tempest Coverage Automation

Thank you for your interest in contributing! This guide will help you get started.

## Ways to Contribute

### Report Issues
- **Bugs:** Found a bug? [Open an issue](https://github.com/lkuchlan/openstack-tempest-coverage-automation/issues)
- **Feature requests:** Have an idea? Share it in [Discussions](https://github.com/lkuchlan/openstack-tempest-coverage-automation/discussions)
- **Documentation:** Spot a typo or unclear section? PRs welcome!

### Improve Skills
- **Add test templates** - More patterns = better test generation
- **Enhance pattern detection** - Improve code discovery
- **Support new services** - Neutron, Barbican, Heat, etc.
- **Add validation checks** - More pre-commit hooks

### Enhance Documentation
- **Add examples** - Real-world workflows
- **Improve guides** - Clearer instructions
- **Create tutorials** - Video walkthroughs
- **Translate** - Make it accessible

---

## Development Setup

### Prerequisites

- Claude Code installed
- Python 3.8+
- tox (for testing hooks)
- git
- Real Tempest repositories for testing

### Quick Setup

```bash
# 1. Fork and clone
git clone https://github.com/your-username/openstack-tempest-coverage-automation.git
cd openstack-tempest-coverage-automation

# 2. Install for development
./scripts/setup.sh

# 3. Make changes to skills/ or hooks/

# 4. Test your changes
claude
> /jira-coverage-analysis TEST-123
> /implement-tempest-tests TEST-123
```

---

## Making Changes

### For Skill Improvements

**1. Test on real Tempest repositories**

```bash
# Test analysis skill
claude
> /jira-coverage-analysis OSPRH-22613

# Test implementation skill
> /implement-tempest-tests OSPRH-22613
```

**2. Update configuration if needed**

```bash
vi .claude/skills/tempest-coverage/config.json
```

**3. Update templates**

```bash
vi .claude/skills/tempest-coverage/templates/api_test_template.py
```

**4. Test validation**

```bash
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
# Ensure generated tests pass
tox -e pep8,py3
```

### For Pre-commit Hook Changes

**1. Edit hook scripts**

```bash
vi hooks/checks/check-waiters.py
```

**2. Test hooks locally**

```bash
# Create test file with violations
cat > test_example.py << 'EOF'
import time

class TestExample:
    def test_something(self):
        time.sleep(10)  # Should be caught
EOF

# Test hook
python3 hooks/checks/check-waiters.py test_example.py
# Should fail with clear error message
```

**3. Test in real repository**

```bash
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin

# Install hooks
/path/to/openstack-tempest-coverage-automation/hooks/install-hooks.sh

# Test by committing a file with violations
git add test_example.py
git commit -m "Test hooks"
# Should block commit
```

### For Documentation Changes

**1. Edit documentation**

```bash
vi docs/QUICKSTART.md
```

**2. Preview locally**

```bash
# Markdown preview in your editor
# Or use grip for GitHub-flavored rendering:
pip install grip
grip README.md
```

**3. Check links**

```bash
# Ensure all links work
grep -r '\[.*\](.*\.md)' docs/
```

---

## Testing Guidelines

### Test All Changes

**Skills:**
- Test on at least 2 different services (e.g., Cinder + Manila)
- Test with and without Jira MCP
- Test error handling (invalid tickets, missing repos)
- Verify generated tests pass tox validation

**Hooks:**
- Test each check individually
- Test with valid and invalid code
- Verify error messages are clear
- Ensure hooks don't block valid code

**Documentation:**
- Follow markdown linting
- Check all code examples work
- Verify links are not broken
- Test setup instructions on clean machine

### Performance

- Skills should complete analysis in < 5 minutes
- Implementation should complete in < 10 minutes
- Hooks should complete in < 5 seconds per file
- No unnecessary API calls or file reads

---

## Code Style

### Python (Hooks)

Follow PEP 8:
```bash
# Check style
flake8 hooks/checks/

# Auto-format
black hooks/checks/
```

### Bash (Scripts)

Follow ShellCheck:
```bash
# Check style
shellcheck scripts/setup.sh
shellcheck hooks/pre-commit
```

### Markdown (Documentation)

Follow markdownlint:
```bash
# Check style
markdownlint-cli2 "**/*.md"
```

---

## Pull Request Process

### Before Submitting

1. **Test your changes** thoroughly
2. **Update documentation** if needed
3. **Add to CHANGELOG.md** under "Unreleased"
4. **Ensure all checks pass** locally

### Submitting PR

1. **Fork the repository**
2. **Create feature branch**
   ```bash
   git checkout -b feature/add-neutron-support
   ```

3. **Make changes and commit**
   ```bash
   git add .
   git commit -m "Add Neutron service support"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/add-neutron-support
   ```

5. **Open Pull Request** on GitHub

### PR Title Format

```
<type>: <description>

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code restructuring
- test: Test improvements
- chore: Maintenance
```

**Examples:**
- `feat: Add Neutron service support`
- `fix: Handle missing Jira ticket gracefully`
- `docs: Improve QUICKSTART.md clarity`

### PR Description

Include:
- **What** changed
- **Why** the change was needed
- **How** to test the change
- **Related issues** (if any)

**Template:**
```markdown
## Summary
Add support for Neutron service in test generation.

## Motivation
Many users need Neutron test coverage but skill didn't support it.

## Changes
- Added Neutron to service mapping in config.json
- Added base class patterns for network tests
- Added example Neutron test template
- Updated documentation

## Testing
Tested with Neutron tempest plugin:
- Analysis: /jira-coverage-analysis NET-123
- Implementation: /implement-tempest-tests NET-123
- Generated tests pass tox validation

## Related Issues
Closes #42
```

---

## Review Process

### What Reviewers Look For

**Functionality:**
- Does it work as intended?
- Are there edge cases not handled?
- Is error handling robust?

**Quality:**
- Is the code readable?
- Are there tests (for hooks)?
- Is it documented?

**Compatibility:**
- Does it work with existing features?
- Does it maintain backward compatibility?
- Does it follow project conventions?

**Documentation:**
- Are changes documented?
- Are examples provided?
- Is CHANGELOG updated?

### Addressing Feedback

- **Be responsive** - Reply to comments promptly
- **Be open** - Consider reviewer suggestions
- **Ask questions** - If you don't understand feedback
- **Update PR** - Push changes to same branch

---

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Example:**
```
feat(skills): Add Neutron service support

- Add Neutron to service mapping
- Add base class patterns
- Add example template

Closes #42
```

### Commit Types

- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation
- **style:** Formatting, missing semi-colons, etc.
- **refactor:** Code change that neither fixes bug nor adds feature
- **test:** Adding tests
- **chore:** Maintain

---

## Project Conventions

### File Organization

```
openstack-tempest-coverage-automation/
├── .claude/skills/           # Existing skills (to be moved to skills/)
├── skills/                   # Skills for GitHub distribution
├── hooks/                    # Pre-commit hooks
├── docs/                     # Extended documentation
├── examples/                 # Configuration templates
└── scripts/                  # Utility scripts
```

### Naming Conventions

**Files:**
- Lowercase with hyphens: `check-waiters.py`
- Descriptive names: `install-hooks.sh`

**Functions:**
- Snake case: `check_file()`, `install_hooks()`

**Variables:**
- Snake case: `repo_root`, `staged_files`

**Configuration:**
- camelCase for JSON keys: `repositoryPaths`, `baseClasses`

---

## Getting Help

**Questions:**
- Ask in [GitHub Discussions](https://github.com/lkuchlan/openstack-tempest-coverage-automation/discussions)
- Tag maintainers in issues

**Documentation:**
- Check [docs/](docs/) first
- Review [CLAUDE.md](CLAUDE.md) for standards

**Community:**
- OpenStack QE community
- Claude Code community

---

## Code of Conduct

Be respectful and constructive:
- **Respectful** - Treat others with respect
- **Constructive** - Provide helpful feedback
- **Collaborative** - Work together toward solutions
- **Inclusive** - Welcome all contributors

---

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

---

## Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Acknowledged in release notes
- Credited in commit co-authorship

Thank you for contributing to the OpenStack QE community! 🎉
