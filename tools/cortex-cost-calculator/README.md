# Cortex Cost Calculator

> **Expires:** 2026-01-09

Monitor Snowflake Cortex AI service costs and forecast future spend.

---

## What It Does

- Tracks usage across all Cortex services (Analyst, Search, Functions, Document AI)
- Shows LLM model comparison (cost per million tokens)
- Projects future costs with configurable growth rates
- Daily snapshots for fast historical queries

---

## Quick Start

```sql
-- Copy deploy.sql into Snowsight, Run All
-- Then: Projects -> Streamlit -> SFE_CORTEX_CALCULATOR
```

**No ACCOUNTADMIN required!** Just SYSADMIN + IMPORTED PRIVILEGES on SNOWFLAKE database.

---

## Objects Created

| Object | Name | Purpose |
|--------|------|---------|
| Schema | `SFE_CORTEX_CALC` | Tool namespace |
| Views | `V_CORTEX_*` (8 views) | Query ACCOUNT_USAGE |
| Table | `SFE_CORTEX_SNAPSHOTS` | Historical data cache |
| Task | `SFE_DAILY_SNAPSHOT_TASK` | Daily 3AM snapshot |
| Streamlit | `SFE_CORTEX_CALCULATOR` | Cost calculator UI |

Uses shared `SFE_TOOLS_WH` warehouse.

---

## Features

### Historical Analysis
- Total credits and costs across services
- Daily usage trends by service type
- Credit distribution breakdown

### LLM Model Costs
- Compare costs across models (Claude, Llama, Mistral, etc.)
- Cost per million tokens
- Call counts and total tokens

### Cost Projections
- Configurable growth rates (0-100%)
- 3-24 month projections
- High/low variance bands

---

## Data Latency

⚠️ ACCOUNT_USAGE has **45 min - 3 hour latency**. Recent usage won't appear immediately.

---

## Prerequisites

Need access to ACCOUNT_USAGE views:

```sql
-- If you get "Object does not exist" errors:
USE ROLE ACCOUNTADMIN;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;
```

---

## Cleanup

```sql
-- Copy teardown.sql into Snowsight, Run All
```

---

## Comparison to Original

This is a simplified version of `cortex-trail`. Key differences:

| Feature | cortex-trail | This Tool |
|---------|--------------|-----------|
| Git integration | Yes (requires ACCOUNTADMIN) | No (embedded code) |
| Views | 16 | 8 (essentials) |
| Streamlit lines | ~1500 | ~150 |
| ACCOUNTADMIN needed | Yes | No |
| Setup complexity | Higher | Lower |

For the full-featured version with detailed query-level analysis, see the original `cortex-trail` repository.

---

*SE Community • Cortex Cost Calculator • 2025-12-10*
