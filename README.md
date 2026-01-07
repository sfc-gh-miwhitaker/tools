![Snowflake Tools Collection](https://img.shields.io/badge/Snowflake-Tools%20Collection-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![Author: SE Community](https://img.shields.io/badge/Author-SE%20Community-blue)

# Snowflake Tools Collection

A curated collection of small, focused Snowflake tools and examples. Most tools are deployable with a single `deploy.sql` and removable with a single `teardown.sql`.

**Author:** SE Community
**Purpose:** Central repository for standalone tools, examples, and utilities
**Pattern:** Each deployable tool is self-contained with its own deployment and cleanup

---

## First Time Here?

Follow these steps in order:

1. `shared/sql/00_shared_setup.sql` - Create shared database and warehouse in Snowflake (2 min)
2. Browse the tool index below and pick a tool (2 min)
3. `tools/<tool>/deploy.sql` - Deploy your chosen tool in Snowsight (2-10 min, depends on tool)
4. `tools/<tool>/teardown.sql` - Clean up when finished (1-2 min)

Total setup time: ~7-16 minutes (varies by tool)

---

## Available Tools and Guides

### Deployable tools

| Tool | Type | What it does | Key Snowflake features | Deploy | Cleanup | Notes |
|------|------|--------------|------------------------|--------|--------|-------|
| [`tools/cortex-agent-chat/`](/tools/cortex-agent-chat/) | Tool (hybrid: Snowflake + local UI) | React chat UI for Cortex Agents (REST API + key-pair JWT) | Cortex Agents, REST API, Key-pair JWT | `deploy.sql` | `teardown.sql` | Requires local Node for the UI; SQL deploy creates the agent and schema `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT`. |
| [`tools/wallmonitor/`](/tools/wallmonitor/) | Tool (Snowflake-native) | Agent monitoring and thread analytics | `GET_AI_OBSERVABILITY_EVENTS`, Serverless Tasks, Views | `deploy.sql` | Manual (see below) | Creates schema `SNOWFLAKE_EXAMPLE.WALLMONITOR` (not `SFE_*`). Requires `ACCOUNTADMIN` for serverless task setup. |
| [`tools/contact-form-streamlit/`](/tools/contact-form-streamlit/) | Tool (Snowflake-native) | Streamlit form that writes submissions to a Snowflake table | Streamlit in Snowflake, Snowpark | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM`. |
| [`tools/api-data-fetcher/`](/tools/api-data-fetcher/) | Tool (Snowflake-native) | Python stored procedure that fetches from a REST API | External Access Integration, Network Rule, Python Procedure | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_API_FETCHER`; creates account-level external access objects (may require elevated privileges to create integrations). |
| [`tools/replication-cost-calculator/`](/tools/replication-cost-calculator/) | Tool (Snowflake-native) | Streamlit estimator for replication / DR costs | Streamlit, `ACCOUNT_USAGE` | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC`. |
| [`tools/cortex-cost-calculator/`](/tools/cortex-cost-calculator/) | Tool (Snowflake-native) | Streamlit monitoring and forecasting for Cortex usage | Streamlit, `ACCOUNT_USAGE`, Serverless Task | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC`. |
| [`tools/semantic-view-enhancer/`](/tools/semantic-view-enhancer/) | Tool (Snowflake-native) | Enhances semantic view descriptions using Cortex AI | Cortex AI, Semantic Views, Python Procedure | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS` (not `SFE_*`) and warehouse `SFE_ENHANCEMENT_WH`. |

### Guides and examples (no deploy/teardown)

| Path | Type | What it contains |
|------|------|------------------|
| [`tools/api-tricks/`](/tools/api-tricks/) | Examples | Working examples of calling the `agent:run` REST API with execution context (role/warehouse). |
| [`tools/multi-tenant/`](/tools/multi-tenant/) | Guide | End-to-end multi-tenant agent pattern (OAuth IdP + Snowflake row access policies + agent API context). |
| [`tools/replication-workbook/`](/tools/replication-workbook/) | Guide | Replication and failover guides (SQL runbooks for Snowsight). |

---

## Repository Structure

```
tools/
├── README.md                       # This file - tools index
├── docs/
│   └── 01-CONTRIBUTING.md          # How to add new tools
├── shared/
│   └── sql/
│       └── 00_shared_setup.sql     # Shared database setup
└── tools/
    ├── cortex-agent-chat/          # React chat UI for Cortex Agents
    ├── wallmonitor/                # Cortex Agent monitoring
    ├── contact-form-streamlit/     # Streamlit contact form
    ├── api-data-fetcher/           # API fetch procedure
    ├── replication-cost-calculator/ # DR cost estimator
    ├── cortex-cost-calculator/     # Cortex AI cost monitoring
    ├── semantic-view-enhancer/     # AI-enhanced semantic views
    ├── api-tricks/                 # Agent Run API examples
    ├── multi-tenant/               # Multi-tenant agent guide
    └── replication-workbook/       # Replication guides (SQL runbooks)
```

---

## Quick Start (Deployable Tools)

Most tools follow the same Snowflake deployment pattern:

```sql
-- 1. Run shared setup (first time only)
-- Copy/paste shared/sql/00_shared_setup.sql into Snowsight, Run All

-- 2. Deploy your chosen tool
-- Navigate to tools/<tool-name>/
-- Copy/paste deploy.sql into Snowsight, Run All

-- 3. Cleanup when done
-- Copy/paste teardown.sql into Snowsight, Run All
```

For folders that are guides/examples (no `deploy.sql`), open the folder README and follow the instructions.

---

## Shared Infrastructure

All tools use common infrastructure to avoid collisions:

| Resource | Name | Purpose |
|----------|------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Warehouse | `SFE_TOOLS_WH` | Shared compute (X-SMALL) |

Each deployable tool creates its own **schema** within `SNOWFLAKE_EXAMPLE`. Schema names are currently tool-specific (many use an `SFE_...` schema, but some tools use descriptive schemas like `WALLMONITOR` and `SEMANTIC_ENHANCEMENTS`). For the authoritative schema name, see the tool's `deploy.sql`.

### Wallmonitor cleanup note

`tools/wallmonitor/` does not currently ship a `teardown.sql`. To remove it, run:

```sql
USE ROLE ACCOUNTADMIN;
DROP TASK IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR.REFRESH_AGENT_EVENTS_TASK;
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR CASCADE;
```

---

## Adding a New Tool

See [docs/01-CONTRIBUTING.md](/docs/01-CONTRIBUTING.md) for the complete guide.

**Quick checklist:**
- [ ] Create folder: `tools/<tool-name>/`
- [ ] Add `README.md` with overview, deploy steps, cleanup
- [ ] Add `deploy.sql` with expiration check and context setup
- [ ] Add `teardown.sql` for complete cleanup
- [ ] Add `diagrams/` if architecture is non-trivial
- [ ] Update this README's tool table

---

## Standards

All tools in this collection follow these standards:

### Required
- **Self-contained**: Each deployable tool deploys and cleans up independently.
- **Expiration dates**: Each deployable tool includes an expiration check in `deploy.sql`.
- **Comments on objects**: Objects include descriptive `COMMENT` metadata.
- **One-click deploy**: Designed for Snowsight copy/paste and "Run All" execution.
- **Complete cleanup**: `teardown.sql` removes objects created by that tool.

### Best Practices
- **Clear README**: Each tool folder explains deploy, usage, and cleanup.
- **No hardcoded credentials or personal data**: Use environment variables or Snowflake-native security objects.
- **Cost-conscious defaults**: Prefer X-SMALL warehouses and auto-suspend.
- **Focused scope**: One capability per tool.

### Architecture diagrams

Some tools include Mermaid diagrams under `tools/<tool>/diagrams/` to document data flow, network flow, auth flow, and/or data model.

---

## Related Resources

- [Snowflake Documentation](https://docs.snowflake.com/)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Python Stored Procedures](https://docs.snowflake.com/en/developer-guide/stored-procedure/python/procedure-python-overview)
- [External Access Overview](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

---

*SE Community • Tools Collection • Last Updated: 2026-01-07*
