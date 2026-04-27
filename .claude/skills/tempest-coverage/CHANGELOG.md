# Changelog

All notable changes to the Tempest Coverage Skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Jira MCP Server Integration**: Automatic Jira ticket fetching via MCP
  - Auto-detect Jira MCP tools (jira_get_issue, jira_search)
  - Extract ticket requirements, description, acceptance criteria
  - Search for related tickets
  - Support multiple ticket ID patterns (RHEL-, OSPRH-, OSASINFRA-, etc.)
  - Graceful fallback when MCP not available
- Comprehensive Jira MCP setup guide (JIRA_MCP_SETUP.md)
- Jira integration configuration in config.json

### Planned
- Support for Nova tempest plugin
- Support for Neutron tempest plugin
- Interactive mode for gap analysis
- CI/CD integration examples
- Performance optimizations for large repos
- Multi-repo coordination (e.g., lib-common changes)
- Jira comment updates with test coverage results
- Batch processing of multiple Jira tickets

## [1.0.0] - 2026-04-26

### Added
- Initial release of Tempest Coverage Skill
- Core workflow implementation:
  - Jira ticket analysis
  - Repository discovery
  - Code pattern discovery using Explore agent
  - Gap analysis
  - Test implementation
  - Git workflow automation
  - Automatic validation with tox
- Support for OpenStack services:
  - Cinder (cinder-tempest-plugin)
  - Manila (manila-tempest-plugin)
  - Glance (glance-tempest-plugin)
  - Barbican (barbican-tempest-plugin)
  - Keystone (keystone-tempest-plugin)
  - Tempest core (Nova, Swift, etc.)
- Memory integration for pattern learning:
  - Base class patterns
  - Client patterns
  - Cleanup patterns
  - Service-to-plugin mappings
- Templates:
  - API test template
  - Scenario test template
- Documentation:
  - README.md - Complete documentation
  - QUICKSTART.md - Quick start guide
  - EXAMPLES.md - Real-world examples
  - DISTRIBUTION.md - Distribution guide
- Configuration system:
  - config.json with defaults
  - Support for user overrides (config.local.json)
  - Service mappings
  - Base class patterns
- Strict adherence to upstream standards:
  - Tempest HACKING guide compliance
  - Proper base class inheritance
  - Tempest client usage
  - Waiter usage (no sleep!)
  - Resource cleanup with addCleanup
  - Test independence for parallel execution
- Git workflow:
  - Automatic branch creation
  - Proper commit messages
  - Jira ticket referencing
  - No automatic push/submit
- Validation:
  - Automatic tox -e pep8
  - Automatic tox -e py3
  - Resource cleanup verification
  - Parallel execution safety checks

### Features
- **Intelligent Discovery**: Uses Explore agent for deep codebase search
- **Pattern Reuse**: Automatically discovers and reuses existing patterns
- **Memory Learning**: Learns patterns across sessions
- **User Control**: Never pushes or submits code automatically
- **Comprehensive Output**: Structured reports with coverage analysis
- **Template-Based**: Provides templates for common test types
- **Multi-Service**: Supports multiple OpenStack services and plugins
- **Graceful Degradation**: Works even when repos are missing
- **Configurable**: User-specific configuration support

### Constraints Enforced
- ✅ Follow Tempest HACKING guidelines
- ✅ Use existing base classes
- ✅ Use Tempest clients (no raw API calls)
- ✅ Use waiters (no sleep)
- ✅ Proper cleanup with addCleanup
- ✅ Test independence
- ✅ Proper decorators (idempotent_id, attr)
- ❌ Never invent new abstractions
- ❌ Never push/submit automatically
- ❌ Never modify main/master directly

### Documentation
- Complete README with usage examples
- Quick start guide for new users
- Real-world examples for common scenarios
- Distribution guide for sharing
- Inline documentation in templates
- Configuration reference

### Technical Details
- **Model**: Claude Sonnet 4.5 optimized
- **Tools Used**: 
  - Agent (Explore) for code discovery
  - TaskCreate/Update for workflow tracking
  - Bash for git and tox operations
  - Read/Edit/Write for code manipulation
  - Memory for pattern persistence
- **Validation**: Automated tox-based testing
- **Git**: Automated branch and commit workflow

### Known Limitations
- Requires local repository access
- Cannot push or submit patches
- Requires tox for validation
- Limited to OpenStack services currently supported
- No automatic Jira ticket fetching (manual copy/paste)

### Dependencies
- Claude Code (4.5+)
- Local Tempest repositories
- tox (for validation)
- git (for workflow)

## Version History

### Version Numbering
- **1.x.x** - Initial stable release series
- **2.x.x** - (Future) Major workflow changes or breaking changes
- **x.Y.x** - New features, new service support
- **x.x.Z** - Bug fixes, documentation updates

## Migration Guides

### From Manual Workflow to Skill v1.0
No migration needed - this is the initial release.

## Acknowledgments

- OpenStack Tempest team for the HACKING guide
- Claude Code team for the platform
- OpenStack QE community for testing workflows

---

For upgrade instructions, see DISTRIBUTION.md
For usage examples, see EXAMPLES.md
For quick start, see QUICKSTART.md
