# Configuration Reference

Complete reference for all configuration options in the Tempest Coverage Automation system.

---

## Overview

The automation skills use a centralized configuration system with two main files:

1. **`skills/shared/config.json`** - Shared configuration for all skills (repository paths, service mappings, validation rules)
2. **`.env`** - User-specific credentials (git-ignored, NOT committed)

---

## skills/shared/config.json

### File Location

```
~/.claude/skills/tempest-coverage/config.json
```

This is a symlink created by `setup.sh` pointing to the repository's `skills/shared/config.json`.

### Schema

The configuration file follows JSON Schema draft-2020-12.

---

### Repository Paths

**Purpose:** Tell skills where to find Tempest repositories on your system.

**Default:**
```json
{
  "default_repo_paths": {
    "tempest": [
      "~/tempest-workspace/tempest"
    ],
    "plugins": {
      "cinder-tempest-plugin": [
        "~/tempest-workspace/cinder-tempest-plugin"
      ],
      "manila-tempest-plugin": [
        "~/tempest-workspace/manila-tempest-plugin"
      ],
      "glance-tempest-plugin": [
        "~/tempest-workspace/glance-tempest-plugin"
      ]
    }
  }
}
```

**Customization:**
- Change `~/tempest-workspace/` to your actual path
- Supports multiple paths per plugin (searches in order)
- Skills fall back gracefully if repositories not found

---

### Service to Plugin Mapping

**Purpose:** Map OpenStack service names to their Tempest plugin repositories.

**Default:**
```json
{
  "service_to_plugin_mapping": {
    "cinder": "cinder-tempest-plugin",
    "manila": "manila-tempest-plugin",
    "glance": "glance-tempest-plugin",
    "barbican": "barbican-tempest-plugin",
    "keystone": "keystone-tempest-plugin",
    "nova": "tempest",
    "neutron": "neutron-tempest-plugin",
    "swift": "tempest"
  }
}
```

**Usage:**
- Skills use this to locate the correct plugin for a service
- Core services (nova, swift) use base Tempest repository

---

### Tox Environments

**Purpose:** Define tox environments used for validation.

**Default:**
```json
{
  "tox_environments": {
    "lint": "pep8",
    "unit_tests": "py3",
    "integration": "tempest",
    "coverage": "cover",
    "compliance": "compliance"
  }
}
```

**Usage:**
- `implement-tempest-tests` runs `tox -e pep8,py3` before commit
- Customize if your environment uses different tox names

---

### Test Attributes

**Purpose:** Define valid Tempest test attribute types.

**Default:**
```json
{
  "test_attributes": {
    "types": [
      "smoke",
      "slow",
      "api",
      "scenario",
      "rbac",
      "negative",
      "gate"
    ]
  }
}
```

**Usage:**
- Skills use these for `@decorators.attr(type='...')` decorators
- See [TEMPEST_STANDARDS.md](TEMPEST_STANDARDS.md) for decorator details

---

### External Resources

**Purpose:** Reference URLs for documentation and issue tracking.

**Default:**
```json
{
  "external_resources": {
    "tempest_hacking_guide": "https://docs.openstack.org/tempest/latest/HACKING.html",
    "tempest_docs": "https://docs.openstack.org/tempest/latest/",
    "openstack_specs": "https://specs.openstack.org/",
    "jira_url": "https://issues.redhat.com"
  }
}
```

---

### Jira Integration

**Purpose:** Configure Jira MCP server integration and ticket validation.

**Main Settings:**
```json
{
  "jira_integration": {
    "enabled": true,
    "use_mcp_if_available": true,
    "default_jira_url": "https://issues.redhat.com",
    "ticket_id_patterns": [
      "RHEL-\\d+",
      "OSPRH-\\d+",
      "OSASINFRA-\\d+",
      "[A-Z]+-\\d+"
    ],
    "fields_to_extract": [
      "summary",
      "description",
      "acceptance_criteria",
      "components",
      "labels",
      "status",
      "assignee",
      "comments"
    ],
    "search_related_tickets": true,
    "max_related_tickets": 5
  }
}
```

**Options:**
- `enabled` - Enable/disable Jira integration
- `use_mcp_if_available` - Fall back to manual input if MCP unavailable
- `ticket_id_patterns` - Regex patterns for ticket ID validation
- `fields_to_extract` - Fields to fetch from Jira API

---

#### Ticket Validation

**Purpose:** Validate tickets before analysis to ensure they're ready for coverage work.

**Status Validation:**
```json
{
  "ticket_validation": {
    "enabled": true,
    "allow_force_bypass": true,
    "status_validation": {
      "enabled": true,
      "invalid_statuses": [
        "Closed",
        "Done",
        "Resolved",
        "Won't Fix",
        "Won't Do",
        "Rejected",
        "Obsolete",
        "Cancelled"
      ],
      "case_insensitive": true
    }
  }
}
```

**Options:**
- `enabled` - Enable status validation
- `invalid_statuses` - List of statuses that indicate ticket is complete
- `case_insensitive` - Match statuses regardless of case
- `allow_force_bypass` - Allow `--force` flag to override

**Automation Relevance Validation:**
```json
{
  "automation_relevance": {
    "enabled": true,
    "validation_method": "any_match",
    "required_labels": [
      "automation",
      "test-automation",
      "tempest",
      "qa-automation",
      "test-coverage"
    ],
    "required_issue_types": [
      "Test",
      "Testing",
      "Test Coverage",
      "QE Task"
    ],
    "required_keywords": [
      "tempest",
      "test coverage",
      "test automation",
      "rbac test",
      "scenario test",
      "api test"
    ],
    "search_fields": ["summary", "description", "labels"],
    "case_insensitive": true
  }
}
```

**Options:**
- `validation_method: "any_match"` - Pass if ANY criterion matches
- `required_labels` - Labels indicating automation work
- `required_issue_types` - Issue types for testing work
- `required_keywords` - Keywords in summary/description
- `search_fields` - Where to look for keywords

**Bypass validation:**
```bash
/jira-coverage-analysis TICKET-123 --force
```

---

#### Post Test Plan Settings

**Purpose:** Configure test plan posting behavior and duplicate detection.

**Configuration:**
```json
{
  "post_test_plan": {
    "auto_post": false,
    "mention_assignee": true,
    "add_labels": ["automation-test-plan"],
    "format": "format1",
    "approval_keywords": ["approved", "LGTM", "looks good"],
    "read_only_fallback": true,
    "duplicate_detection": {
      "enabled": true,
      "comment_markers": [
        "🤖 Test Automation Plan",
        "Test Automation Plan",
        "h2. 🤖 Test Automation Plan"
      ],
      "comment_limit": 100,
      "on_duplicate_found": "ask_user",
      "repost_prefix": "[UPDATED]"
    }
  }
}
```

**Options:**
- `auto_post` - Automatically post without prompting
- `mention_assignee` - @mention ticket assignee in plan
- `add_labels` - Labels to add to ticket when posting plan
- `approval_keywords` - Keywords that indicate approval
- `read_only_fallback` - Show formatted plan if write fails

**Duplicate Detection Options:**
- `enabled` - Enable duplicate plan detection
- `comment_markers` - Strings that identify test plan comments
- `comment_limit` - How many comments to check (max 100)
- `on_duplicate_found` - Behavior when duplicate found:
  - `ask_user` - Prompt user (skip/repost/view)
  - `auto_skip` - Automatically skip posting
  - `auto_repost` - Automatically post with [UPDATED] prefix
- `repost_prefix` - Prefix for updated plans

**Bypass duplicate check:**
```bash
/post-test-plan TICKET-123 --skip-duplicate-check
```

---

### Git Workflow

**Purpose:** Configure git branch and commit behavior.

**Default:**
```json
{
  "git_workflow": {
    "branch_prefix": "tempest-coverage-",
    "commit_message_format": "Add Tempest coverage for {feature}\n\nImplements test coverage for {ticket_id}\n{test_list}\n\nCloses-Bug: #{ticket_id}\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>",
    "default_base_branch": "main",
    "no_push": true,
    "no_submit": true
  }
}
```

**Options:**
- `branch_prefix` - Prefix for feature branches
- `default_base_branch` - Base branch for new branches
- `no_push` - Never auto-push to remote
- `no_submit` - Never auto-submit to Gerrit

---

### Validation Settings

**Purpose:** Configure test validation behavior.

**Default:**
```json
{
  "validation_settings": {
    "run_pep8": true,
    "run_unit_tests": true,
    "check_resource_cleanup": true,
    "verify_parallel_safe": true,
    "timeout_seconds": 300
  }
}
```

**Options:**
- `run_pep8` - Run `tox -e pep8` before commit
- `run_unit_tests` - Run `tox -e py3` before commit
- `timeout_seconds` - Max time for validation (default 5 minutes)

---

### Base Class Patterns

**Purpose:** Define common base class patterns per service.

**Default:**
```json
{
  "base_class_patterns": {
    "cinder": [
      "BaseVolumeTest",
      "BaseVolumeAdminTest",
      "BaseBackupsTest",
      "BaseSnapshotsTest"
    ],
    "manila": [
      "BaseSharesTest",
      "BaseSharesAdminTest",
      "BaseSharesRbacTest"
    ]
  }
}
```

**Usage:**
- Skills use these patterns when discovering existing tests
- Referenced in [TEMPEST_STANDARDS.md](TEMPEST_STANDARDS.md)

---

### Client Patterns

**Purpose:** Define common client naming patterns per service.

**Default:**
```json
{
  "client_patterns": {
    "cinder": [
      "volumes_client",
      "volumes_v3_client",
      "backups_client",
      "snapshots_client"
    ],
    "manila": [
      "shares_client",
      "shares_v2_client"
    ]
  }
}
```

---

### Waiter Patterns

**Purpose:** Common waiter method patterns for reference.

**Default:**
```json
{
  "waiter_patterns": {
    "examples": [
      "waiters.wait_for_volume_resource_status",
      "waiters.wait_for_volume_deletion",
      "waiters.wait_for_share_status",
      "waiters.wait_for_image_status"
    ]
  }
}
```

---

## .env File

### Purpose

Store user-specific credentials that should NEVER be committed to git.

### Location

```
/path/to/openstack-tempest-coverage-automation/.env
```

### Template

```bash
# Jira Credentials (for MCP integration)
JIRA_URL="https://issues.redhat.com"
JIRA_USERNAME="your-email@redhat.com"
JIRA_API_TOKEN="your-api-token-here"

# Optional: Project root override
PROJECT_ROOT="/path/to/repo"
```

### Security Notes

**CRITICAL:**
- ✅ File is git-ignored by default
- ❌ NEVER commit this file
- ❌ NEVER share API tokens
- ❌ NEVER commit credentials to git

**Best practices:**
- Use API tokens, not passwords
- Rotate tokens regularly
- Limit token permissions
- Store securely (use password manager)

### Getting Jira API Token

1. Visit: https://id.atlassian.com/manage-profile/security/api-tokens
2. Create new API token
3. Copy to `.env` file
4. Never share or commit

---

## Customization Examples

### Custom Repository Paths

**Scenario:** Tempest repos in `/opt/tempest/`

```json
{
  "default_repo_paths": {
    "tempest": ["/opt/tempest/tempest"],
    "plugins": {
      "cinder-tempest-plugin": ["/opt/tempest/plugins/cinder-tempest-plugin"]
    }
  }
}
```

### Disable Validation

**Scenario:** Skip validation for testing

```json
{
  "jira_integration": {
    "ticket_validation": {
      "enabled": false
    }
  },
  "validation_settings": {
    "run_pep8": false,
    "run_unit_tests": false
  }
}
```

### Strict Duplicate Prevention

**Scenario:** Never allow duplicate test plans

```json
{
  "post_test_plan": {
    "duplicate_detection": {
      "enabled": true,
      "on_duplicate_found": "auto_skip"
    }
  }
}
```

---

## Validation

### Verify JSON Syntax

```bash
python3 -m json.tool < skills/shared/config.json
```

### Check Configuration

```bash
# In Claude Code
claude
> /jira-coverage-analysis --help
# Should load without errors
```

### Test Jira Credentials

```bash
# Test MCP connection
# Should fetch ticket details
/jira-coverage-analysis TICKET-123
```

---

## Troubleshooting

**Config not found:**
- Check `~/.claude/skills/tempest-coverage/` exists
- Re-run `./scripts/setup.sh`

**Jira credentials fail:**
- Verify `.env` file has correct values
- Check API token is valid
- Verify MCP server configured

**Validation always skipped:**
- Check `ticket_validation.enabled: true`
- Verify MCP server available
- Try with `--force` flag

---

## See Also

- [Tempest Standards](TEMPEST_STANDARDS.md) - Coding standards reference
- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md) - Common issues
- [Jira Setup](../docs/JIRA_SETUP.md) - MCP server configuration

---

**Last updated:** 2026-05-03  
**Maintained by:** OpenStack Tempest Coverage Automation project
