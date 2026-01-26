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

### Deployable Tools

| Tool | Type | What it does | Key Snowflake Features | Deploy | Cleanup | Notes |
|------|------|--------------|------------------------|--------|--------|-------|
| [`cortex-agent-chat/`](/tools/cortex-agent-chat/) | Hybrid (Snowflake + local UI) | React chat UI for Cortex Agents (REST API + key-pair JWT) | Cortex Agents, REST API, Key-pair JWT | `deploy.sql` | `teardown.sql` | Requires local Node for the UI; creates schema `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT`. |
| [`contact-form-streamlit/`](/tools/contact-form-streamlit/) | Snowflake-native | Streamlit form that writes submissions to a Snowflake table | Streamlit in Snowflake, Snowpark | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_CONTACT_FORM`. |
| [`api-data-fetcher/`](/tools/api-data-fetcher/) | Snowflake-native | Python stored procedure that fetches from a REST API | External Access Integration, Network Rule, Python Procedure | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_API_FETCHER`; may require elevated privileges for integrations. |
| [`replication-cost-calculator/`](/tools/replication-cost-calculator/) | Snowflake-native | Streamlit estimator for replication / DR costs | Streamlit, `ACCOUNT_USAGE` | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC`. |
| [`cortex-cost-calculator/`](/tools/cortex-cost-calculator/) | Snowflake-native | Streamlit monitoring and forecasting for Cortex usage | Streamlit, `ACCOUNT_USAGE`, Serverless Task | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC`. |
| [`semantic-view-enhancer/`](/tools/semantic-view-enhancer/) | Snowflake-native | Enhances semantic view descriptions using Cortex AI | Cortex AI, Semantic Views, Python Procedure | `deploy.sql` | `teardown.sql` | Creates schema `SNOWFLAKE_EXAMPLE.SEMANTIC_ENHANCEMENTS` and warehouse `SFE_ENHANCEMENT_WH`. |

### Guides and Examples (no deploy/teardown)

| Path | Type | What it contains |
|------|------|------------------|
| [`agent-config-diff/`](/tools/agent-config-diff/) | Utility | Extract Cortex Agent specs for comparison, version control, and config management. |
| [`api-routing-test/`](/tools/api-routing-test/) | Example | Generic curl command for calling `agent:run` endpoint with role/warehouse overrides. |
| [`api-tricks/`](/tools/api-tricks/) | Examples | Working examples of calling the `agent:run` REST API with execution context (role/warehouse). |
| [`cortex-search/`](/tools/cortex-search/) | Guide | Creating, managing, and querying Cortex Search services (UI + SQL). |
| [`DocAI-Sunset/`](/tools/DocAI-Sunset/) | Migration Guide | Migrating from Document AI to `AI_PARSE_DOCUMENT` and `AI_EXTRACT` (deadline: Feb 28, 2026). |
| [`multi-tenant/`](/tools/multi-tenant/) | Guide | End-to-end multi-tenant agent pattern (OAuth IdP + Snowflake row access policies + agent API context). |
| [`replication-workbook/`](/tools/replication-workbook/) | Guide | Replication and failover guides (SQL runbooks for Snowsight). |
| [`Slack-qs-patch/`](/tools/Slack-qs-patch/) | Patch | Adds chart/visualization support to the Cortex Agent + Slack quickstart. |

---

## Repository Structure

```
tools/
├── README.md                        # This file - tools index
├── docs/
│   └── 01-CONTRIBUTING.md           # How to add new tools
├── shared/
│   └── sql/
│       └── 00_shared_setup.sql      # Shared database setup
└── tools/
    ├── agent-config-diff/           # Agent spec extraction for diff/versioning
    ├── api-data-fetcher/            # API fetch procedure (deploy/teardown)
    ├── api-routing-test/            # Generic agent:run curl command
    ├── api-tricks/                  # Agent Run API examples
    ├── contact-form-streamlit/      # Streamlit contact form (deploy/teardown)
    ├── cortex-agent-chat/           # React chat UI for Cortex Agents (deploy/teardown)
    ├── cortex-cost-calculator/      # Cortex AI cost monitoring (deploy/teardown)
    ├── cortex-search/               # Cortex Search service guide
    ├── DocAI-Sunset/                # Document AI migration guide
    ├── multi-tenant/                # Multi-tenant agent pattern guide
    ├── replication-cost-calculator/ # DR cost estimator (deploy/teardown)
    ├── replication-workbook/        # Replication guides (SQL runbooks)
    ├── semantic-view-enhancer/      # AI-enhanced semantic views (deploy/teardown)
    └── Slack-qs-patch/              # Slack quickstart visualization patch
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

Each deployable tool creates its own **schema** within `SNOWFLAKE_EXAMPLE`. Schema names are tool-specific (many use an `SFE_...` prefix, but some tools use descriptive schemas like `SEMANTIC_ENHANCEMENTS`). For the authoritative schema name, see the tool's `deploy.sql`.

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

*SE Community • Tools Collection • Last Updated: 2026-01-26*
