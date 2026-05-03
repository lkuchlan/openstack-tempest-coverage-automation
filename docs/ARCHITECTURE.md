# System Architecture

Overview of the OpenStack Tempest Coverage Automation system design.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User (Claude Code)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
           ┌────────────┴────────────┐
           │                         │
    ┌──────▼──────┐          ┌──────▼──────┐
    │  Analysis   │          │Implementat  │
    │   Skill     │          │ ion Skill   │
    └──────┬──────┘          └──────┬──────┘
           │                         │
           │                         │
    ┌──────▼─────────────────────────▼──────┐
    │       Shared Configuration             │
    │    (Service mappings, patterns)        │
    └──────┬─────────────────────────┬───────┘
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
4. Test with real repository

**Add new validation:**
1. Update skill validation logic
2. Test with tox on real code
3. Ensure proper error messaging

**Add new template:**
1. Create template in skills/shared/templates/
2. Reference in skill.md
3. Test generation

See [CONTRIBUTING.md](../CONTRIBUTING.md) for extension guidelines.
