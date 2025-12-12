![Snowflake Tools Collection](https://img.shields.io/badge/Snowflake-Tools%20Collection-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)
![SE Community](https://img.shields.io/badge/Author-SE%20Community-blue)

# Snowflake Tools Collection

A curated collection of small, focused Snowflake tools and examples. Each tool demonstrates a specific capability or pattern without the overhead of a full project repository.

**Author:** SE Community  
**Purpose:** Central repository for standalone tools, examples, and utilities  
**Pattern:** Each tool is self-contained with its own deployment and cleanup

---

## 👋 First Time Here?

1. **Browse the tools** in the table below
2. **Pick a tool** that interests you
3. **Navigate to its folder** and follow its README
4. **Deploy with one script** - each tool is self-contained

---

## 🧰 Available Tools

| Tool | Description | Snowflake Features | Status |
|------|-------------|-------------------|--------|
| [Wallmonitor](/tools/wallmonitor/) | Cortex Agent monitoring & thread analytics | GET_AI_OBSERVABILITY_EVENTS, Serverless Tasks, Views | ✅ Active |
| [Contact Form (Streamlit)](/tools/contact-form-streamlit/) | Form UI that writes to Snowflake table | Streamlit in Snowflake, Snowpark | ✅ Active |
| [API Data Fetcher](/tools/api-data-fetcher/) | Stored procedure that fetches from REST API | External Access Integration, Python Procedures | ✅ Active |
| [Replication Cost Calculator](/tools/replication-cost-calculator/) | DR/Replication cost estimator | Streamlit, ACCOUNT_USAGE | ✅ Active |
| [Cortex Cost Calculator](/tools/cortex-cost-calculator/) | Cortex AI usage monitoring & forecasting | Streamlit, ACCOUNT_USAGE, Serverless Tasks | ✅ Active |

---

## 📁 Repository Structure

```
tools/
├── README.md                       # This file - tools index
├── docs/
│   └── 01-CONTRIBUTING.md          # How to add new tools
├── shared/
│   └── sql/
│       └── 00_shared_setup.sql     # Shared database setup
└── tools/
    ├── wallmonitor/                # Cortex Agent monitoring
    ├── contact-form-streamlit/     # Streamlit contact form
    ├── api-data-fetcher/           # API fetch procedure
    ├── replication-cost-calculator/ # DR cost estimator
    └── cortex-cost-calculator/     # Cortex AI cost monitoring
```

---

## 🚀 Quick Start (Any Tool)

Every tool follows the same deployment pattern:

```sql
-- 1. Run shared setup (first time only)
-- Copy/paste shared/sql/00_shared_setup.sql into Snowsight, Run All

-- 2. Deploy your chosen tool
-- Navigate to tools/<tool-name>/
-- Copy/paste deploy.sql into Snowsight, Run All

-- 3. Cleanup when done
-- Copy/paste teardown.sql into Snowsight, Run All
```

---

## 🏗️ Shared Infrastructure

All tools use common infrastructure to avoid collisions:

| Resource | Name | Purpose |
|----------|------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Shared demo database |
| Warehouse | `SFE_TOOLS_WH` | Shared compute (X-SMALL) |

Each tool creates its own **schema** within `SNOWFLAKE_EXAMPLE` using the naming pattern:
```
SNOWFLAKE_EXAMPLE.SFE_<TOOL_NAME>
```

---

## ➕ Adding a New Tool

See [docs/01-CONTRIBUTING.md](/docs/01-CONTRIBUTING.md) for the complete guide.

**Quick checklist:**
- [ ] Create folder: `tools/<tool-name>/`
- [ ] Add `README.md` with overview, deploy steps, cleanup
- [ ] Add `deploy.sql` with expiration check and context setup
- [ ] Add `teardown.sql` for complete cleanup
- [ ] Add `diagrams/` if architecture is non-trivial
- [ ] Update this README's tool table

---

## 📋 Standards

All tools in this collection follow these standards:

### Required
- ✅ **Self-contained** - Each tool deploys/cleans independently
- ✅ **SFE_ prefix** - All Snowflake objects use `SFE_` prefix
- ✅ **Expiration dates** - Each tool has 30-day expiration from creation
- ✅ **COMMENT on objects** - All objects have descriptive comments
- ✅ **One-click deploy** - Copy/paste → Run All workflow
- ✅ **Complete cleanup** - Teardown removes all tool objects

### Best Practices
- 📝 Clear README with use case and instructions
- 🔒 No hardcoded credentials or personal data
- 💰 Cost-conscious (X-SMALL warehouse, auto-suspend)
- 🎯 Focused scope (one capability per tool)

---

## 🔗 Related Resources

- [Snowflake Documentation](https://docs.snowflake.com/)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)
- [Python Stored Procedures](https://docs.snowflake.com/en/developer-guide/stored-procedure/python/procedure-python-overview)
- [External Access Integration](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

---

## 📊 Tool Status Legend

| Status | Meaning |
|--------|---------|
| ✅ Active | Tool is current and maintained |
| ⚠️ Expiring | Tool will expire within 7 days |
| ❌ Expired | Tool needs update before use |
| 🚧 In Progress | Tool is being developed |

---

*SE Community • Tools Collection • Last Updated: 2025-12-11*
