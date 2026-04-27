# Tempest Coverage Skill

An intelligent skill for analyzing Jira tickets and implementing Tempest test coverage following OpenStack upstream standards.

## Overview

This skill automates the workflow of:
1. Analyzing Jira tickets for OpenStack features/bugs
2. Discovering existing test coverage in Tempest and plugins
3. Identifying gaps in test coverage
4. Implementing missing tests following upstream best practices
5. Validating tests with tox
6. Creating proper git commits

## Features

- **Jira Integration**: Optional MCP server integration for automatic ticket fetching
- **Intelligent Code Discovery**: Uses Claude's explore agent to find existing patterns
- **Pattern Reuse**: Learns and reuses base classes, clients, and cleanup patterns
- **Upstream Standards**: Strictly follows Tempest HACKING guidelines
- **Validation**: Automatically runs pep8 and unit tests
- **Memory**: Remembers common patterns across sessions
- **Git Workflow**: Creates proper branches and commits

## Installation

### Option 1: Local Installation (Current)

The skill is already installed at:
```
~/.claude/skills/tempest-coverage/
```

### Option 2: Clone from Repository (Future)

```bash
git clone https://github.com/your-org/claude-tempest-coverage-skill.git \
  ~/.claude/skills/tempest-coverage
```

## Configuration

### 1. Configure Repository Paths

Edit `~/.claude/skills/tempest-coverage/config.json` to set your local Tempest repository paths:

```json
{
  "default_repo_paths": {
    "tempest": [
      "~/automation_projects/tempest"
    ],
    "plugins": {
      "cinder-tempest-plugin": [
        "~/automation_projects/cinder-tempest-plugin"
      ]
    }
  }
}
```

### 2. Optional: Configure Settings

You can customize:
- Tox environments to run
- Git commit message format
- Validation settings
- Service-to-plugin mappings

### 3. Optional: Jira MCP Integration

For automatic Jira ticket fetching, set up Jira MCP server:

**Quick Setup:**
```bash
# Add to .claude/settings.json:
{
  "mcpServers": {
    "jira": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-jira"],
      "env": {
        "JIRA_URL": "https://issues.redhat.com",
        "JIRA_USERNAME": "your-email@redhat.com",
        "JIRA_API_TOKEN": "your-api-token"
      }
    }
  }
}
```

**With MCP enabled:**
```
/tempest-coverage RHEL-12345
```
→ Automatically fetches ticket, extracts requirements, implements tests!

**Without MCP:**
Still works! Just provide ticket details manually.

**Complete setup guide:** See [JIRA_MCP_SETUP.md](JIRA_MCP_SETUP.md)

## Usage

### Basic Invocation

```bash
# In Claude Code, use the skill command
/tempest-coverage JIRA-12345
```

Or use natural language:
```
Please analyze test coverage for Jira ticket RHEL-54321
```

### With Jira Ticket File

If you have the Jira ticket details in a file:
```
Analyze tempest coverage for the requirements in jira-ticket.txt
```

### Direct Requirements

You can also provide requirements directly:
```
I need Tempest test coverage for Cinder volume multi-attach RBAC. 
The feature should test admin, member, and reader roles.
```

## Workflow

The skill executes these steps automatically:

### Step 1: Ticket Analysis
- Parses Jira ticket or requirements
- Identifies service, API, and feature
- Creates tracking tasks

### Step 2: Repository Discovery
- Locates local Tempest repositories
- Determines correct project (core vs plugin)

### Step 3: Code Discovery
- Spawns explore agent to search for:
  - Existing test coverage
  - Base test classes
  - Service clients
  - Cleanup patterns
  - Similar tests to use as templates

### Step 4: Gap Analysis
- Compares existing coverage vs requirements
- Identifies what's missing
- Asks clarifying questions if needed

### Step 5: Implementation Planning
- For complex changes: enters plan mode for approval
- For simple changes: proceeds directly

### Step 6: Test Implementation
- Implements tests following discovered patterns
- Uses proper base classes, clients, waiters
- Ensures proper cleanup and parallel safety

### Step 7: Git Workflow
- Creates feature branch
- Commits with proper message format
- References Jira ticket

### Step 8: Validation
- Runs tox -e pep8
- Runs tox -e py3
- Verifies tests pass

### Step 9: Report
- Provides structured output
- Shows coverage analysis
- Lists implemented tests
- Shows validation results

## Output Example

```markdown
# Tempest Coverage Analysis: RHEL-54321

## Summary
- **Service:** Cinder
- **Feature:** Volume multi-attach RBAC
- **Coverage Status:** ❌ Missing

## Existing Coverage
- **File:** cinder_tempest_plugin/api/volume/test_volumes.py
- **Class:** VolumesTest
- **Methods:**
  - test_create_volume()
  - test_delete_volume()

## Coverage Gaps Identified
1. ❌ Missing: RBAC test for multi-attach with admin role
2. ❌ Missing: RBAC test for multi-attach with non-admin role

## Implementation Details
- **Files Created:** cinder_tempest_plugin/api/volume/test_volume_multiattach_rbac.py
- **Tests Implemented:** 3

### Test Methods
1. test_volume_multiattach_admin_authorized()
2. test_volume_multiattach_member_authorized()
3. test_volume_multiattach_unauthorized_negative()

## Validation Results
- ✅ pep8: PASSED
- ✅ py3: PASSED

## Git Branch
- Branch: tempest-coverage-rhel-54321
- Status: Ready for review
```

## Memory & Learning

The skill automatically saves patterns to memory:

### Reference Memory
- Service → Plugin mappings
- Repository locations
- Common base classes

### Feedback Memory
- Patterns that worked well
- Approaches validated by user
- Common pitfalls to avoid

### Project Memory
- Ongoing test coverage initiatives
- Feature-specific requirements

## Templates

The skill includes templates for:

### API Tests (`templates/api_test_template.py`)
- Basic API testing patterns
- Positive and negative tests
- RBAC tests
- Admin tests

### Scenario Tests (`templates/scenario_test_template.py`)
- End-to-end workflow testing
- Multi-step operations
- Error handling scenarios

## Best Practices Enforced

The skill strictly enforces:

### ✅ DO:
- Use Tempest base classes
- Use Tempest clients (no raw requests)
- Use waiters (no sleep!)
- Proper resource cleanup with addCleanup
- Test independence (parallel-safe)
- Follow naming conventions
- Add proper decorators (idempotent_id, attr)

### ❌ DON'T:
- Invent new frameworks
- Use time.sleep()
- Skip cleanup
- Make tests dependent on each other
- Modify main/master directly
- Submit/push patches automatically

## Troubleshooting

### Repository Not Found

If a repository isn't found locally:
```
The skill will explicitly state which repo is missing and either:
1. Ask you for the path
2. Implement based on upstream structure
```

### Tests Fail Validation

If tox validation fails:
```
The skill will:
1. Show exact errors
2. Propose fixes
3. Re-run validation
```

### Unclear Requirements

If the Jira ticket is ambiguous:
```
The skill will ask clarifying questions before implementing
```

## Advanced Usage

### Custom Configuration Per Project

Create `.claude/settings.json` in your Tempest repo:

```json
{
  "skills": {
    "tempest-coverage": {
      "default_base_class": "CustomBaseTest",
      "skip_validation": false
    }
  }
}
```

### Integration with Hooks

Add hooks for automation (in `~/.claude/settings.json`):

```json
{
  "hooks": {
    "afterToolCall": {
      "tool": "Bash",
      "pattern": "git commit",
      "command": "cd {{cwd}} && git log -1 --pretty=format:'Commit created: %h - %s'"
    }
  }
}
```

## Contributing

To improve this skill:

1. **Test it**: Use it on real Jira tickets
2. **Provide feedback**: Tell Claude what worked/didn't work
3. **Refine patterns**: Let the skill save successful patterns to memory
4. **Share improvements**: Update the skill.md with better workflows

## Examples

### Example 1: Simple API Test

```
User: /tempest-coverage RHEL-12345
      Feature: Add volume backup test

Claude:
✓ Found existing base class: BaseBackupsTest
✓ Implemented: test_create_backup_from_volume()
✓ Validation: PASSED
✓ Branch: tempest-coverage-rhel-12345
```

### Example 2: RBAC Testing

```
User: I need RBAC coverage for Manila share revert to snapshot

Claude:
✓ Discovered: manila-tempest-plugin/api/base.py (BaseSharesRbacTest)
✓ Gap: RBAC tests missing for revert operation
✓ Implemented 3 tests:
  - test_revert_to_snapshot_admin()
  - test_revert_to_snapshot_member()
  - test_revert_to_snapshot_reader_negative()
✓ Validation: PASSED
```

### Example 3: Complex Scenario

```
User: Implement Cinder volume migration scenario test

Claude:
🔍 Entering plan mode...
📋 Plan:
  1. Inherit from ScenarioBaseClass
  2. Create volume with data
  3. Perform migration
  4. Verify data integrity
  5. Test rollback scenario

User: Approved

Claude:
✓ Implemented scenario test in:
  cinder_tempest_plugin/scenario/test_volume_migration.py
✓ Validation: PASSED (slow tests take ~5min)
```

## Version History

- **v1.0** (2026-04-26): Initial release
  - Core workflow implementation
  - Pattern discovery
  - Memory integration
  - Git workflow
  - Validation

## Support

For issues or questions:
1. Check this README
2. Review the skill.md for detailed workflow
3. Examine config.json for configuration options
4. Ask Claude for help: "How does the tempest-coverage skill work?"

## License

Apache 2.0 (same as OpenStack Tempest)

## Credits

Built with Claude Code (claude.ai/code)
Designed for OpenStack QE engineers
