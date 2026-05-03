# OpenStack Tempest Coverage Automation

This repository provides Claude Code skills for automating OpenStack Tempest test coverage analysis and implementation following upstream standards.

## Purpose

When working in this repository, you are helping users:
1. Analyze Jira tickets for test coverage gaps
2. Implement Tempest tests following OpenStack standards
3. Validate tests meet upstream quality requirements
4. Maintain consistency with Tempest HACKING guidelines

**Target users:** OpenStack QE engineers automating test coverage for Tempest plugins (Cinder, Manila, Glance, etc.)

---

## Project Structure

```
openstack-tempest-coverage-automation/
├── skills/
│   ├── jira-coverage-analysis/     # Analysis-only skill (fast, read-only)
│   ├── implement-tempest-tests/    # Implementation skill (with validation)
│   └── shared/                     # Shared configuration and templates
├── docs/                           # Extended documentation
├── examples/                       # Configuration templates
└── scripts/                        # Setup and utility scripts
```

---

## Skills Available

### /jira-coverage-analysis

**Purpose:** Analyze Jira tickets for test coverage gaps (NO implementation)

**When to use:**
- Sprint planning and effort estimation
- Identifying gaps before implementation
- Auditing existing coverage
- Batch analysis of multiple tickets

**Characteristics:**
- Fast execution (< 5 minutes)
- Read-only operations
- Spawns Explore agent for thorough pattern discovery
- Generates structured analysis reports

**Workflow:**
1. Fetch Jira ticket (or accept manual requirements)
2. Locate Tempest repositories
3. Discover existing test coverage (Explore agent)
4. Identify gaps with priority (HIGH/MEDIUM/LOW)
5. Estimate effort (hours per gap)
6. Provide implementation recommendations
7. Generate structured markdown report

### /implement-tempest-tests

**Purpose:** Implement Tempest tests from requirements with validation

**When to use:**
- After coverage analysis approval
- Implementing tests from Jira tickets
- Creating RBAC, negative, or scenario tests
- Following up on approved test plans

**Characteristics:**
- Full implementation workflow (5-10 minutes)
- Creates git branch and commits
- Runs tox validation (pep8 + py3)
- Spawns Explore agent for pattern discovery
- Generates final recap with exact file paths

**Workflow:**
1. Get requirements (from analysis, Jira, or manual)
2. Locate Tempest plugin repository
3. Discover implementation patterns (Explore agent)
4. Plan if complex (enter plan mode)
5. Implement tests following strict standards
6. Create git branch and commit
7. Run tox validation
8. Generate mandatory final recap

---

## OpenStack Tempest Standards (CRITICAL)

When implementing or reviewing Tempest tests, **STRICTLY enforce** these upstream standards:

### ✅ REQUIRED Patterns

#### 1. Base Classes
**MUST** inherit from proper Tempest base classes. **NEVER** create custom base classes.

**Service-specific base classes:**
- **Cinder:** `BaseVolumeTest`, `BaseVolumeAdminTest`, `BaseBackupsTest`, `BaseSnapshotsTest`
- **Manila:** `BaseSharesTest`, `BaseSharesAdminTest`, `BaseSharesRbacTest`
- **Glance:** `BaseImageTest`, `BaseImageAdminTest`
- **Nova:** `BaseV2ComputeTest`, `BaseV2ComputeAdminTest`
- **Neutron:** `BaseNetworkTest`, `BaseAdminNetworkTest`

**Generic base classes:**
- `base.BaseTestCase` (low-level)
- `test.BaseTestCase` (API tests)
- `scenario.ScenarioTest` (scenario tests)

**Example:**
```python
# ✅ CORRECT
from cinder_tempest_plugin.api import base
class VolumeMultiAttachTest(base.BaseVolumeTest):
    pass

# ❌ WRONG - Custom base class
class MyCustomBaseVolumeTest(unittest.TestCase):
    pass
```

#### 2. Clients
**MUST** use Tempest service clients. **NEVER** use raw HTTP libraries (requests, urllib).

**Service clients:**
- **Cinder:** `self.volumes_client`, `self.volumes_v3_client`, `self.backups_client`, `self.snapshots_client`
- **Manila:** `self.shares_client`, `self.shares_v2_client`
- **Glance:** `self.image_client`, `self.image_client_v2`
- **Nova:** `self.servers_client`, `self.os_compute_api`

**Example:**
```python
# ✅ CORRECT
volume = self.volumes_client.create_volume(size=1)

# ❌ WRONG - Raw HTTP
import requests
response = requests.post(url, json={'size': 1})
```

**Why:** Tempest clients handle authentication, retries, API versioning, and response parsing automatically.

#### 3. Waiters
**MUST** use Tempest waiters. **NEVER** use `time.sleep()` or manual polling loops.

**Common waiters:**
- `waiters.wait_for_volume_resource_status(client, volume_id, 'available')`
- `waiters.wait_for_volume_deletion(client, volume_id)`
- `waiters.wait_for_share_status(client, share_id, 'available')`
- `waiters.wait_for_server_status(client, server_id, 'ACTIVE')`
- `waiters.wait_for_image_status(client, image_id, 'active')`

**Example:**
```python
# ✅ CORRECT
from tempest.common import waiters
volume = self.create_volume()
waiters.wait_for_volume_resource_status(
    self.volumes_client, volume['id'], 'available'
)

# ❌ WRONG - Sleep
import time
volume = self.create_volume()
time.sleep(30)  # NEVER DO THIS

# ❌ WRONG - Manual polling
while self.volumes_client.show_volume(volume['id'])['status'] != 'available':
    time.sleep(1)
```

**Why:** Waiters provide proper timeout handling, exponential backoff, and descriptive errors. `time.sleep()` causes unreliable tests and wastes CI time.

#### 4. Cleanup
**MUST** use `addCleanup()` for ALL created resources. **NEVER** rely on manual cleanup in `tearDown()`.

**Example:**
```python
# ✅ CORRECT
def test_volume_creation(self):
    volume = self.create_volume()
    self.addCleanup(self.delete_volume, volume['id'])
    # Test continues...

# ❌ WRONG - No cleanup
def test_volume_creation(self):
    volume = self.create_volume()
    # Missing addCleanup - resource leaked!

# ❌ WRONG - Manual tearDown
def tearDown(self):
    self.delete_volume(self.volume_id)  # Use addCleanup instead
```

**Why:** `addCleanup()` ensures cleanup even when tests fail. It executes in reverse order (LIFO) for proper dependency handling.

#### 5. Test Independence
Tests **MUST** run in parallel without dependencies on execution order or shared state.

**Requirements:**
- Each test creates own resources
- No class-level or module-level shared state
- No assumptions about other tests running
- Tests can run in any order
- Tests can run simultaneously

**Example:**
```python
# ✅ CORRECT
def test_volume_create(self):
    # Creates own volume
    volume = self.create_volume()
    self.addCleanup(self.delete_volume, volume['id'])
    
def test_volume_delete(self):
    # Creates own volume too
    volume = self.create_volume()
    self.delete_volume(volume['id'])

# ❌ WRONG - Shared state
class VolumeTests(base.BaseVolumeTest):
    @classmethod
    def setup_class(cls):
        cls.shared_volume = cls.create_volume()  # Shared!
    
    def test_volume_snapshot(self):
        # Depends on shared_volume - breaks in parallel!
        snapshot = self.create_snapshot(self.shared_volume['id'])
```

#### 6. Decorators
ALL test methods **MUST** have proper decorators.

**Required decorators:**
```python
from tempest.lib import decorators

class MyTest(base.BaseVolumeTest):
    
    @decorators.idempotent_id('a8f4c9d2-3e1b-4f6a-9c2d-7b8e5a3f1c4e')
    @decorators.attr(type='smoke')
    def test_volume_create(self):
        pass
```

**Decorator types:**
- `@decorators.idempotent_id('uuid')` - **REQUIRED** - Generate new UUID for each test
- `@decorators.attr(type='TYPE')` - Test category:
  - `'smoke'` - Critical functionality
  - `'api'` - API tests
  - `'scenario'` - Multi-service scenarios
  - `'rbac'` - RBAC tests
  - `'negative'` - Negative tests
  - `'slow'` - Long-running tests
- `@decorators.skip_because(bug='RHEL-12345')` - Skip with bug reference
- `@decorators.related_bug('OSPRH-67890')` - Link to related bug

**Generate UUIDs:**
```python
import uuid
str(uuid.uuid4())  # Generates: 'a8f4c9d2-3e1b-4f6a-9c2d-7b8e5a3f1c4e'
```

#### 7. Naming Conventions

**Test methods:**
- Format: `test_{action}_{condition}` or `test_{feature}_{scenario}`
- Use lowercase with underscores
- Be descriptive and specific

**Examples:**
```python
# ✅ GOOD
def test_volume_multiattach_admin_authorized(self):
def test_volume_create_from_image_with_encryption(self):
def test_share_access_rule_deny_unauthorized_user(self):

# ❌ BAD - Too vague
def test_volume(self):
def test_create(self):
def test_1(self):
```

**Test classes:**
- Format: `{Feature}{TestType}Test`
- Use CamelCase
- Descriptive of what's being tested

**Examples:**
```python
# ✅ GOOD
class VolumeMultiAttachRbacTest(base.BaseVolumeTest):
class ShareAccessRulesNegativeTest(base.BaseSharesTest):
class ImageUploadScenarioTest(base.BaseImageTest):

# ❌ BAD
class Test1(base.BaseVolumeTest):
class MyTests(base.BaseVolumeTest):
```

---

### ❌ FORBIDDEN Patterns

**These patterns will FAIL code review and tox validation:**

1. **Using requests/urllib directly**
   ```python
   # ❌ FORBIDDEN
   import requests
   response = requests.post(url, json=data)
   ```

2. **Using time.sleep() for polling**
   ```python
   # ❌ FORBIDDEN
   import time
   time.sleep(10)
   ```

3. **Creating resources without cleanup**
   ```python
   # ❌ FORBIDDEN
   def test_something(self):
       volume = self.create_volume()
       # Missing: self.addCleanup(...)
   ```

4. **Tests that depend on other tests**
   ```python
   # ❌ FORBIDDEN
   def test_create_volume(self):
       self.volume_id = self.create_volume()['id']
   
   def test_delete_volume(self):
       # Depends on test_create_volume running first!
       self.delete_volume(self.volume_id)
   ```

5. **Inheriting from unittest.TestCase**
   ```python
   # ❌ FORBIDDEN
   import unittest
   class MyTest(unittest.TestCase):
       pass
   ```

6. **Custom framework patterns**
   ```python
   # ❌ FORBIDDEN - Don't reinvent Tempest
   class MyCustomWaiter:
       def wait_for_status(self, resource_id):
           while True:
               time.sleep(1)  # NO!
   ```

7. **Modifying global state**
   ```python
   # ❌ FORBIDDEN
   import os
   os.environ['DEBUG'] = 'true'  # Affects other tests!
   ```

---

## Git Workflow Rules

When skills create commits, enforce these rules:

### Branch Management
- **ALWAYS** create feature branch: `tempest-coverage-{ticket-id}` or `tempest-coverage-{feature}`
- **NEVER** modify `main` or `master` directly
- **NEVER** auto-push to remote (user controls when to push)
- **NEVER** auto-submit to Gerrit (user reviews first)

### Commit Messages
```
Add Tempest coverage for volume multi-attach RBAC

Tests added:
- test_multiattach_admin_authorized
- test_multiattach_member_own_volume
- test_multiattach_reader_denied (negative)

Implements: OSPRH-22613
Change-Id: Iabc123...

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### Validation
All implemented tests are validated using tox before finalizing the commit:
- `tox -e pep8` - PEP 8 style and import checking
- `tox -e py3` - Unit test validation

This ensures all code meets OpenStack quality standards before being committed.

---

## Development Environment

Users typically have:

**Local repositories:**
- Tempest: `~/tempest-workspace/tempest` (or custom path)
- Plugins: `~/tempest-workspace/{service}-tempest-plugin`
  - Examples: `cinder-tempest-plugin`, `manila-tempest-plugin`, `glance-tempest-plugin`

**Tools installed:**
- Python 3.8+ with tox
- Git configured for Gerrit review (if contributing upstream)
- Optional: Jira MCP server for ticket fetching

**Validation commands:**
- `tox -e pep8` - PEP 8 style checking
- `tox -e py3` - Unit tests in Python 3
- `git review` - Submit to Gerrit (upstream)

---

## Subagent Usage Strategy

Both skills use subagents intelligently for specific tasks:

### Explore Agent (Pattern Discovery)

**When used:**
- **jira-coverage-analysis:** STEP 3 - Discover Existing Coverage
- **implement-tempest-tests:** STEP 3 - Discover Implementation Patterns

**Purpose:**
- Deep codebase search for existing tests
- Finding base test classes to inherit from
- Discovering service clients and their methods
- Locating waiter implementations
- Identifying cleanup patterns
- Finding reference tests as templates

**Why delegated:**
- Thorough, methodical code discovery
- Handles large codebases (100+ files) efficiently
- Saves main agent token budget for analysis/implementation
- Better pattern matching across repositories

**When skipped:**
- Patterns already in memory from recent analysis
- User provides specific file paths
- Quick re-analysis of same ticket

**Configuration:**
- Mode: "very thorough"
- Searches multiple file types and patterns
- Follows imports and inheritance chains
- Builds comprehensive pattern map

### Plan Agent (Not Currently Used)

Currently, plan mode is handled by the main agent. Plan agent may be added in future for complex multi-file features.

---

## Configuration Files

### skills/shared/config.json

Shared configuration used by both skills:

**Contains:**
- Service-to-plugin repository mapping (Cinder → cinder-tempest-plugin)
- Repository paths (default: `~/tempest-workspace/`)
- Base class patterns per service
- Client patterns per service
- Waiter patterns
- Tox environments
- Test attributes
- Jira integration settings

**Users can customize:**
- Repository paths (if different location)
- Jira MCP settings (enable/disable)
- Tox environments
- Git workflow preferences

### .env (User-specific, NOT in git)

**Contains:**
- Jira credentials (JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN)
- Optional: PROJECT_ROOT path

**CRITICAL:** This file is git-ignored and NEVER committed.

---

## References

**Upstream Documentation:**
- Tempest HACKING: https://docs.openstack.org/tempest/latest/HACKING.html
- Tempest Plugin Interface: https://docs.openstack.org/tempest/latest/plugin.html
- OpenStack API Reference: https://docs.openstack.org/api-ref/
- Tempest Configuration: https://docs.openstack.org/tempest/latest/configuration.html

**Service-specific API docs:**
- Cinder API: https://docs.openstack.org/api-ref/block-storage/
- Manila API: https://docs.openstack.org/api-ref/shared-file-system/
- Glance API: https://docs.openstack.org/api-ref/image/
- Nova API: https://docs.openstack.org/api-ref/compute/

**Jira MCP:**
- Official MCP Server: https://github.com/modelcontextprotocol/servers

---

## For Contributors

When improving these skills:

**Testing:**
- Test on real Tempest repositories
- Validate all examples work
- Run tox to verify generated tests
- Test both with and without Jira MCP

**Documentation:**
- Update templates to match current patterns
- Keep examples up-to-date
- Maintain backward compatibility
- Document breaking changes in CHANGELOG.md

**Code Quality:**
- Follow the same Tempest standards the skills enforce
- Use proper error handling
- Provide clear error messages
- Maintain skill.md documentation

**Pull Requests:**
- Reference issues or feature requests
- Include before/after examples
- Update relevant documentation
- Add to CHANGELOG.md

---

## Common Workflows

### Workflow 1: Analyze and Implement from Jira

```bash
# Step 1: Analyze ticket for coverage gaps
/jira-coverage-analysis OSPRH-22613

# Review analysis report, approve implementation

# Step 2: Implement approved tests
/implement-tempest-tests OSPRH-22613

# Review generated tests, run additional validation
cd $TEMPEST_WORKSPACE/cinder-tempest-plugin
tox -e pep8,py3

# Push to remote for review
git push origin tempest-coverage-OSPRH-22613
git review  # If using Gerrit
```

### Workflow 2: Batch Analysis for Sprint Planning

```bash
# Analyze multiple tickets at once
/jira-coverage-analysis OSPRH-22613 OSPRH-22614 OSPRH-22615

# Review effort estimates
# Plan sprint based on total hours
# Implement tickets in priority order
```

### Workflow 3: Without Jira MCP (Manual Requirements)

```bash
# Skills work without Jira integration
# Provide requirements manually when prompted

/implement-tempest-tests

# Claude will ask for:
# - Service name (e.g., Cinder)
# - Feature/API description
# - Test scenarios needed
# - Acceptance criteria
```

---

## Troubleshooting

**Skills can't find Tempest repositories:**
- Update paths in `skills/shared/config.json`
- Verify repositories exist: `ls $TEMPEST_WORKSPACE/`
- Skills will note missing repos in reports

**Jira MCP connection fails:**
- Check `.env` file has correct credentials
- Verify MCP server is configured in settings.json
- Skills fall back to manual input if MCP unavailable

**Tox validation fails:**
- Review tox output for specific errors
- Fix violations manually or ask Claude to fix
- Common issues: imports, PEP 8 style, test failures

---

## Security Notes

**Credential Management:**
- `.env` file is git-ignored
- Never commit API tokens or passwords
- Use `.env.example` as template
- Skills work without Jira (manual fallback)

**Data Privacy:**
- Analysis reports may contain ticket details
- Review before sharing publicly
- Generated tests contain only public OpenStack APIs

**Git Safety:**
- Skills never auto-push to remote
- User reviews all commits before submission
- Tox validation ensures code quality
