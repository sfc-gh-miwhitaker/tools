# Snowflake Tools Collection - AI Agent Instructions

## Core Principles (Non-Negotiable)

### User Experience Principle
**Ask:** "How do I get to what I want in the most obvious, quickest, least friction way possible?"
- One command/script to deploy (not 10 manual steps)
- Copy/paste into Snowsight and Run All
- Clear numbered sequence - works out-of-the-box
- Fails with helpful errors, not cryptic stack traces
- **If a user has to think, read, or guess - you've failed.**

### Lazy Execution Principle
Generate artifacts on-demand from patterns, never maintain pre-built templates.
- Generate SQL/YAML from parameterized patterns (not static template files)
- Templates requiring manual updates are technical debt
- Document "how to generate", not "what was generated"

### Zero-Compromise Security
**NEVER commit:** `.cursor/`, `.cortex/`, credentials, API tokens, `.env`, private keys, account names
- Use environment variables for secrets
- NEVER commit `.gitignore` (reveals AI tooling) - use global ignore or `.git/info/exclude`
- Author attribution: "SE Community" (no personal names)

### Native Snowflake Architecture
ALL code MUST be 100% native Snowflake unless technically impossible.
- Default to Snowflake-native for compute, data, orchestration, ML/AI, UIs (Streamlit in Snowflake)
- External components require explicit justification in README

---

## Project Overview

A collection of self-contained Snowflake demo tools. Each tool deploys via `deploy.sql` and cleans up via `teardown.sql`. Tools target the shared `SNOWFLAKE_EXAMPLE` database with tool-specific schemas (e.g., `SFE_CORTEX_AGENT_CHAT`).

## Architecture

```
tools/
├── shared/sql/00_shared_setup.sql    # Run first - creates SNOWFLAKE_EXAMPLE db + SFE_TOOLS_WH
└── tools/<tool-name>/
    ├── deploy.sql                     # Copy-paste into Snowsight, Run All
    ├── teardown.sql                   # Complete cleanup
    └── README.md                      # Tool-specific docs
```

## SQL File Requirements

Every SQL file MUST start with context setting after the header:

```sql
USE ROLE SYSADMIN;                     -- NEVER ACCOUNTADMIN unless truly required
USE DATABASE SNOWFLAKE_EXAMPLE;
USE WAREHOUSE SFE_TOOLS_WH;            -- Or tool-specific: SFE_<PROJECT>_WH
```

**ACCOUNTADMIN only for:** API Integrations, Network Policies, Storage Integrations. Drop back to SYSADMIN immediately after.

## Naming Conventions

| Object Type | Pattern | Example |
|-------------|---------|---------|
| Schema | `SFE_<TOOL_NAME>` | `SFE_CORTEX_AGENT_CHAT` |
| Warehouse | `SFE_<PROJECT>_WH` | `SFE_REPLICATION_WH` |
| Tables | `RAW_*`, `STG_*`, or descriptive | `RAW_EVENTS`, `FEEDBACK_SUMMARY` |
| Cortex Agents | Descriptive (no SFE_ prefix) | `SFE_REACT_DEMO_AGENT` |

## Deploy Script Pattern

All `deploy.sql` files must include:

1. **Expiration check** (30-day default):
```sql
EXECUTE IMMEDIATE $$
DECLARE
    v_expiration_date DATE := '2026-02-08';
    demo_expired EXCEPTION (-20001, 'TOOL EXPIRED');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN RAISE demo_expired; END IF;
END;
$$;
```

2. **Object comments** with metadata:
```sql
COMMENT = 'TOOL: <purpose> | Author: SE Community | Expires: YYYY-MM-DD'
```

3. **Idempotent DDL**: Use `CREATE OR REPLACE` or `CREATE IF NOT EXISTS`

## SQL Anti-Patterns (Forbidden)

- `SELECT *` - always project specific columns
- Functions on columns in WHERE: use `WHERE col >= '2024-01-01'` not `WHERE YEAR(col) = 2024`
- COMMENT inside column list (goes after closing parenthesis)
- LATERAL + GENERATOR with outer column refs (use recursive CTE instead)

## Cost Defaults

- Warehouse: `AUTO_SUSPEND = 60`, `WAREHOUSE_SIZE = 'X-SMALL'`
- Tables: Use TRANSIENT for staging data
- Resource monitors: 75% notify, 95% suspend

## Pre-Commit Hooks

Secret detection enabled via `detect-secrets` and `gitleaks`. Run `pre-commit install` after cloning.

Blocked patterns: `.cursor/` files, private keys, credentials, `.env` files.

## Testing a Tool

1. Run `shared/sql/00_shared_setup.sql` (once)
2. Copy `tools/<tool>/deploy.sql` into Snowsight, Run All
3. Verify with queries in the script's verification section
4. Clean up: `tools/<tool>/teardown.sql`

## Adding a New Tool

1. Create `tools/<tool-name>/` with `deploy.sql`, `teardown.sql`, `README.md`
2. Use `SFE_<TOOL>` schema within `SNOWFLAKE_EXAMPLE`
3. Include expiration check + object comments
4. Update root `README.md` tool table
