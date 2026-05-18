# System Architecture

Overview of the OpenStack Tempest Coverage Automation system design.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User (Claude Code)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
           ┌────────────┼────────────────────┐
           │            │                    │
    ┌──────▼──────┐ ┌──▼───────────┐ ┌──────▼──────┐
    │  Analysis   │ │Implementat   │ │  DevStack   │
    │   Skill     │ │ ion Skill    │ │ Verify Skill│
    └──────┬──────┘ └──────┬───────┘ └──────┬──────┘
           │               │                 │
           │               │           ┌─────▼─────┐
           │               │           │ SSH to VM  │
           │               │           │ (DevStack) │
           │               │           └─────┬──────┘
    ┌──────▼───────────────▼─────────────────▼──────┐
    │       Shared Configuration                     │
    │    (Service mappings, patterns, DevStack)      │
    └──────┬─────────────────────────┬───────────────┘
           │                         │
    ┌──────▼──────┐          ┌──────▼──────┐
    │   Explore   │          │   Tempest   │
    │   Agent     │          │  Repos      │
    └─────────────┘          └─────────────┘
```

## Components

### Skills

**jira-coverage-analysis:**
- Purpose: Identify test coverage gaps
- Input: Jira ticket ID or manual requirements
- Process: Fetch → Explore → Analyze → Report
- Output: Structured markdown report
- Speed: < 5 minutes

**implement-tempest-tests:**
- Purpose: Generate production-ready tests
- Input: Requirements (from analysis or manual)
- Process: Explore → Plan → Implement → Validate → Commit
- Output: Validated code + git commit + recap
- Speed: 5-10 minutes

**verify-tempest-devstack:**
- Purpose: Verify tests against real OpenStack APIs
- Input: Ticket ID, test files from implementation
- Process: Parse tests → Deploy DevStack → Install Tempest → Run tests → Collect results
- Output: Verification report + structured feedback (on failure)
- Speed: 35-90 minutes (includes DevStack deployment)

### Shared Configuration

**config.json:**
- Service-to-plugin mapping
- Base class patterns per service
- Client patterns
- Waiter patterns
- Tox environments
- Test attributes

**Templates:**
- API test template
- Scenario test template

### Validation with Tox

**Quality enforcement:**
- Runs after implementation (before commit finalization)
- Validates Tempest standards via tox
- Catches PEP 8 violations, test failures
- Execution time: 30-90 seconds

**Tox environments:**
- `tox -e pep8` - Style and import checking
- `tox -e py3` - Unit test validation

### Explore Agent

**Pattern Discovery:**
- Spawned by both skills (Step 3)
- Searches large codebases efficiently
- Finds base classes, clients, waiters
- Locates similar tests as templates
- Mode: Very thorough
- Overhead: 30-60 seconds

## Data Flow

### Analysis Workflow

```
Jira Ticket
    ↓ (Fetch via MCP or manual input)
Requirements Extracted
    ↓ (Service, API, scenarios)
Repository Located
    ↓ (Find plugin in local paths)
Explore Agent Spawned
    ↓ (Search for existing tests)
Pattern Analysis
    ↓ (Compare requirements vs coverage)
Gap Identification
    ↓ (Prioritize HIGH/MEDIUM/LOW)
Effort Estimation
    ↓ (Calculate hours per gap)
Report Generation
    ↓ (Structured markdown)
User Reviews
```

### Implementation Workflow

```
Requirements (from analysis or manual)
    ↓
Repository Located
    ↓
Explore Agent Spawned
    ↓ (Find patterns: base classes, clients, waiters)
Plan Mode (if complex)
    ↓ (Design multi-file approach)
Test Generation
    ↓ (Follow strict Tempest standards)
Git Workflow
    ↓ (Create branch, stage files)
Tox Validation
    ↓ (Run pep8 + py3)
Git Commit
    ↓ (Proper message format)
Final Recap
    ↓ (Exact paths, methods, validation results)
Ready for Review
```

### Verification Workflow

```
Implementation Output (test files on branch)
    ↓
[Parse test code for required services/extensions]
    ↓ (local grep/read)
[SSH to VM → Clean previous → Clone DevStack]
    ↓
[Generate local.conf with required services]
    ↓
[Run stack.sh (30-60 min, background + poll)]
    ↓
[Verify deployment → Install Tempest + plugin]
    ↓
[SCP test files to VM]
    ↓
[tempest run --regex '{module}']
    ↓
[Collect results + service logs]
    ↓
[Measure coverage delta]
    ↓
    +──── PASSED → VERIFIED (update Jira) → git review (manual)
    |
    +──── FAILED → Structured feedback
                        ↓
               [implement-tempest-tests --fix-context]
                        ↓
               [Re-verify with --skip-deploy (once)]
                        ↓
                   PASSED → VERIFIED (update Jira) → git review (manual)
                   FAILED → VERIFICATION_FAILED
```

## Configuration Hierarchy

```
1. ~/.claude/skills/tempest-coverage/config.json (shared defaults)
2. Project-specific overrides (if needed)
3. User-specific config.local.json (git-ignored)
```

Settings merge in order: defaults → project → local

## Memory Integration

Skills use Claude Code memory for:
- **User type:** Track patterns per service
- **Feedback type:** Learn from corrections
- **Project type:** Remember ongoing work
- **Reference type:** Jira patterns, repository locations

## Security Model

**Credential protection:**
1. .gitignore blocks all credential files
2. .env.example provides template
3. Environment variables as alternative
4. MCP handles authentication securely

**No credentials in code or git history**

## Extension Points

**Add new service:**
1. Update config.json service mapping
2. Add base class patterns
3. Add client patterns
4. Add DevStack service mapping in verify-tempest-devstack/config.json
5. Test with real repository

**Add new validation:**
1. Update skill validation logic
2. Test with tox on real code
3. Ensure proper error messaging

**Add new template:**
1. Create template in skills/shared/templates/
2. Reference in skill.md
3. Test generation

**Configure DevStack verification:**
1. Update skills/verify-tempest-devstack/config.json with VM SSH details
2. Ensure VM has sufficient resources (8GB RAM, 60GB disk, 4 vCPUs)
3. Test SSH connectivity: `ssh -i {key} {user}@{host} "echo ok"`

See [CONTRIBUTING.md](../CONTRIBUTING.md) for extension guidelines.
