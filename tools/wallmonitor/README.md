# Wallmonitor: Agent-Focused Cortex AI Monitoring

> **Purpose:** Real-time monitoring for Cortex Agent threads and runs with near real-time observability.

**Author:** SE Community
**Created:** 2026-01-07
**Expires:** 2026-02-06

---

## Which guide do you need?

| Your Goal | Start Here |
|-----------|------------|
| **Delivering to a customer** | Read `DELIVERY_GUIDE.md` |
| **Building a dashboard** | Read `DELIVERY_GUIDE.md` → Section 3 (Dashboard Patterns) |
| **Quick test/demo** | Read `DELIVERY_GUIDE.md` → Section 1 (One-Shot Query) |
| **Understanding architecture** | Read this file (README.md) |
| **Query examples** | Read `example_queries.sql` |

---

## Overview

Wallmonitor provides real-time visibility into Cortex Agent activity across your entire account. It auto-discovers agents, collects observability events, and presents thread-focused metrics perfect for operational dashboards.

### Key Features

- **Automated Refresh** - Serverless task updates data every 10 minutes
- **Auto-Discovery** - Automatically finds and registers all agents in your account
- **Thread-Centric** - Track full conversation flows with token usage and latency
- **Account-Wide** - Monitor all agents from a single dashboard
- **Filter-Friendly** - Include/exclude patterns for selective monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  AGENT REGISTRY                                         │
│  - Auto-discovery via SHOW AGENTS                      │
│  - Include/exclude filtering                           │
│  - Manual additions supported                          │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  SERVERLESS TASK (runs every 10 minutes)                │
│  - Calls REFRESH_AGENT_EVENTS() procedure              │
│  - Iterates all registered agents                      │
│  - Queries GET_AI_OBSERVABILITY_EVENTS() per agent     │
│  - Upserts AGENT_EVENTS_HISTORY (7-30d)                │
│  - Rebuilds AGENT_EVENTS_SNAPSHOT (24h)                │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  DASHBOARD LAYER                                         │
│  - Realtime views (snapshot):                           │
│    - REALTIME_KPI, THREAD_ACTIVITY, AGENT_METRICS,      │
│      HOURLY_THREAD_ACTIVITY, THREAD_TIMELINE            │
│  - Recent history (dynamic tables + views):             │
│    - THREAD_ACTIVITY_RECENT, AGENT_METRICS_RECENT,      │
│      HOURLY_THREAD_ACTIVITY_RECENT, THREAD_TIMELINE_RECENT│
│  - Streamlit: WALLMONITOR_DASHBOARD                     │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

For delivery teams: see `DELIVERY_GUIDE.md` for one-shot queries, monitoring strategies, and dashboard patterns.

### Option A: One-Shot Query (No Setup)

Get metrics from ONE agent RIGHT NOW (no deployment needed):

```sql
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;

-- Replace: MY_DB, MY_SCHEMA, MY_AGENT with your agent
SELECT
    record:thread_id::STRING AS thread_id,
    record:timestamp::TIMESTAMP_LTZ AS event_time,
    record:span_name::STRING AS span_name,
    record:attributes:total_tokens::NUMBER AS tokens,
    record:attributes:duration_ms::NUMBER AS latency_ms,
    record:attributes:status::STRING AS status
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'MY_DB', 'MY_SCHEMA', 'MY_AGENT', 'CORTEX AGENT'
))
WHERE record:timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY record:timestamp DESC;
```

Use when: single agent, debugging, or demo

---

### Option B: Automated Monitoring (Full Deployment)

For multi-agent dashboards with auto-refresh:

#### 1. Deploy Wallmonitor

```sql
-- Copy entire deploy.sql into Snowsight and click "Run All"
```

#### 2. Discover & Setup

```sql
USE ROLE ACCOUNTADMIN;  -- Required for serverless task creation
USE SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR;

-- Discover agents
CALL DISCOVER_AGENTS('%', NULL, TRUE);

-- Activate monitoring (creates serverless task)
CALL SETUP_MONITORING(24, 30);
-- Data auto-refreshes every 10 minutes
```

#### 3. Query Dashboard

```sql
-- Real-time KPIs (auto-updated)
SELECT
    active_threads,
    active_users,
    active_agents,
    llm_calls,
    total_tokens,
    avg_span_duration_ms,
    error_rate_pct
FROM REALTIME_KPI;

-- Thread activity
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_start_time,
    thread_last_activity,
    thread_duration_seconds,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_tokens,
    error_count,
    latest_status,
    latest_model
FROM THREAD_ACTIVITY
ORDER BY thread_start_time DESC
LIMIT 20;
```

#### 4. Open Streamlit Dashboard

In Snowsight: Projects -> Streamlit -> WALLMONITOR_DASHBOARD

Use when: multiple agents, dashboarding, historical trending

## Schema Structure

```
SNOWFLAKE_EXAMPLE.WALLMONITOR/
├── Tables
│   ├── AGENT_REGISTRY                -- Registered agents to monitor
│   ├── AGENT_INGEST_STATE            -- Per-agent watermark/status for incremental ingest
│   ├── AGENT_EVENTS_HISTORY          -- Retained recent history (7-30d, configurable)
│   └── AGENT_EVENTS_SNAPSHOT         -- Snapshot window used for realtime views (refreshed every 10 min)
├── Dynamic Tables
│   ├── DT_THREAD_ACTIVITY_RECENT     -- Recent history rollup (threads)
│   ├── DT_AGENT_METRICS_RECENT       -- Recent history rollup (agents)
│   └── DT_HOURLY_THREAD_ACTIVITY_RECENT -- Recent history rollup (hourly)
├── Procedures
│   ├── DISCOVER_AGENTS()             -- Auto-discovery of agents
│   ├── REFRESH_AGENT_EVENTS()        -- Incremental ingest (history) + rebuild snapshot
│   ├── SETUP_MONITORING()            -- Create/resume serverless task
│   └── SETUP_WALLMONITOR_STREAMLIT_APP() -- Upload Streamlit source to stage
├── Tasks
│   └── REFRESH_AGENT_EVENTS_TASK     -- Serverless task (runs every 10 min)
├── Stage
│   └── WALLMONITOR_STREAMLIT_STAGE   -- Stage for Streamlit app source
├── Streamlit
│   └── WALLMONITOR_DASHBOARD         -- Streamlit in Snowflake dashboard
└── Views
    ├── AGENT_EVENTS                  -- Unified events over snapshot window
    ├── REALTIME_KPI                  -- Last hour KPIs with comparison
    ├── THREAD_ACTIVITY               -- Thread rollups over snapshot window
    ├── AGENT_METRICS                 -- Agent rollups over snapshot window
    ├── HOURLY_THREAD_ACTIVITY        -- Hourly rollups over snapshot window
    ├── THREAD_TIMELINE               -- Per-event timeline over snapshot window
    ├── AGENT_EVENTS_RECENT           -- Unified events over retained history
    ├── THREAD_ACTIVITY_RECENT        -- Thread rollups over retained history
    ├── AGENT_METRICS_RECENT          -- Agent rollups over retained history
    ├── HOURLY_THREAD_ACTIVITY_RECENT -- Hourly rollups over retained history
    └── THREAD_TIMELINE_RECENT        -- Per-event timeline over retained history
```

## Data Sources

| Source | Latency | Data | Privileges Required |
|--------|---------|------|---------------------|
| `GET_AI_OBSERVABILITY_EVENTS()` | **Seconds** | Thread events, tokens, spans | `CORTEX_USER` role |
| `SHOW AGENTS` | Real-time | Agent enumeration | `USAGE` on databases/schemas containing agents |

## Dashboard Components

### KPI Cards (Header Metrics)

Query: `SELECT active_threads, active_users, active_agents, llm_calls, total_tokens, avg_span_duration_ms, error_rate_pct FROM REALTIME_KPI`

Metrics (last hour with hour-over-hour comparison):
- Active Threads
- Active Users
- Active Agents
- LLM Calls
- Total Tokens
- Avg Latency
- Error Rate

### Thread List (Main View)

Query: `SELECT thread_id, agent_full_name, user_id, thread_start_time, thread_last_activity, thread_duration_seconds, llm_calls, tool_calls, retrieval_calls, total_tokens, error_count, latest_status, latest_model FROM THREAD_ACTIVITY ORDER BY thread_start_time DESC LIMIT 50`

Shows:
- Thread ID & User
- Agent Used
- Start/End Times
- Duration
- LLM/Tool/Retrieval Calls
- Token Usage (prompt/completion breakdown)
- Error Count
- Latest Status

### Thread Detail (Drill-Down)

Query: `SELECT event_timestamp, event_sequence, seconds_since_thread_start, span_name, span_category, model_name, total_tokens, prompt_tokens, completion_tokens, span_duration_ms, tool_name, retrieval_query, status, error_message FROM THREAD_TIMELINE WHERE thread_id = :id ORDER BY event_timestamp`

Timeline view showing:
- Each span in chronological order
- Span type (LLM, Tool, Retrieval, Agent)
- Tokens per span
- Latency per span
- Errors

### Agent Performance Comparison

Query: `SELECT agent_full_name, unique_threads, unique_users, llm_calls, tool_calls, retrieval_calls, total_tokens, avg_span_duration_ms, p50_span_duration_ms, p95_span_duration_ms, error_rate_pct, most_used_model FROM AGENT_METRICS`

Per-agent metrics:
- Unique Threads/Users
- Call Counts (LLM/Tool/Retrieval)
- Token Totals
- Latency Percentiles (avg, p50, p95, p99)
- Error Rate
- Most Used Model

### Time-Series Charts

Query: `SELECT event_hour, agent_full_name, unique_threads, llm_calls, total_tokens, avg_span_duration_ms, error_count FROM HOURLY_THREAD_ACTIVITY WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP()) ORDER BY event_hour`

Hourly aggregations for:
- Thread Volume
- Token Usage
- Latency Trends
- Error Rate

## Agent Discovery

### Auto-Discovery

```sql
-- Discover all agents
CALL DISCOVER_AGENTS('%', NULL, TRUE);

-- Discover with include filter (only production)
CALL DISCOVER_AGENTS('%PROD%', NULL, TRUE);

-- Discover with exclude filter (skip test agents)
CALL DISCOVER_AGENTS('%', '%TEST%', TRUE);

-- Discover without auto-activation
CALL DISCOVER_AGENTS('%', NULL, FALSE);
```

### Manual Registration

```sql
INSERT INTO AGENT_REGISTRY (agent_database, agent_schema, agent_name, is_active, notes)
VALUES ('MY_DB', 'MY_SCHEMA', 'SUPPORT_AGENT', TRUE, 'Customer support agent');
```

### Activate/Deactivate

```sql
-- Deactivate agent
UPDATE AGENT_REGISTRY
SET is_active = FALSE
WHERE agent_name = 'test_agent';

-- Reactivate
UPDATE AGENT_REGISTRY
SET is_active = TRUE
WHERE agent_name = 'support_agent';
```

## Example Dashboard Queries

All queries available in `example_queries.sql`, organized by component:

1. **Setup & Discovery** - Agent registration
2. **Real-Time KPI Cards** - Header metrics
3. **Thread-Focused Queries** - Main thread list, drill-downs
4. **Agent Performance** - Comparison, model usage, tool usage
5. **Time-Series Charts** - Hourly trends
6. **Error Analysis** - Error logs, frequency
7. **User Activity** - Per-user metrics
8. **Filters/Dropdowns** - Distinct values for UI
9. **Advanced Analytics** - Complexity, efficiency
10. **Monitoring & Alerts** - Slow threads, high errors, no activity

## Permissions Required

### Deploying Role

```sql
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <deploy_role>;
GRANT CREATE SCHEMA ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <deploy_role>;
```

### Dashboard/Query Role

```sql
-- Recommended viewer role created by deploy.sql
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON WAREHOUSE SFE_WALLMONITOR_WH TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON STREAMLIT SNOWFLAKE_EXAMPLE.WALLMONITOR.WALLMONITOR_DASHBOARD TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
```

### Required for Observability Access

The deployment role (ACCOUNTADMIN) needs:

```sql
-- Required for serverless task creation
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;

-- Required database role for observability events
-- (Already granted during deployment)
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;
```

## Data Retention & Refresh

| Component | Retention | Refresh Interval | Latency |
|-----------|-----------|------------------|---------|
| `AGENT_EVENTS_SNAPSHOT` (Table) | Snapshot window (`LOOKBACK_HOURS`, default 24h) | 10 minutes | ~10 minutes |
| `AGENT_EVENTS_HISTORY` (Table) | Recent history (`HISTORY_DAYS`, default 30d) | 10 minutes | ~10 minutes |
| Dynamic tables (`DT_*_RECENT`) | Based on history | Target lag (default 30 minutes) | ~30 minutes |
| Views | Based on snapshot/history | On query | Instant (reads precomputed tables) |

How it works:
1. Serverless task runs `REFRESH_AGENT_EVENTS(LOOKBACK_HOURS, HISTORY_DAYS)` every 10 minutes
2. Procedure queries `GET_AI_OBSERVABILITY_EVENTS()` for each active agent
3. Procedure upserts into `AGENT_EVENTS_HISTORY` and rebuilds `AGENT_EVENTS_SNAPSHOT`
4. Dynamic tables refresh from `AGENT_EVENTS_HISTORY` at the configured target lag
5. Dashboards query views/dynamic tables without hitting the observability API directly

**Task Management:**
```sql
-- Pause monitoring (stops serverless task)
ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;

-- Resume monitoring
ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;

-- Manual refresh (on-demand)
CALL REFRESH_AGENT_EVENTS(24, 30);

-- Check task status
SHOW TASKS LIKE 'REFRESH_AGENT_EVENTS_TASK';
```

## Latency Profile

| Component | Latency | Notes |
|-----------|---------|-------|
| Raw observability data | **Seconds** | Snowflake's `GET_AI_OBSERVABILITY_EVENTS()` provides near real-time data |
| Snapshot refresh | **10 minutes** | Serverless task runs every 10 minutes |
| View queries | **Sub-second** | Views query pre-computed snapshot table |
| Agent discovery | Manual trigger | Run `DISCOVER_AGENTS()` when new agents are deployed |

## Troubleshooting

### No events appearing

1. **Check agent registration:**
   ```sql
   SELECT
       agent_database,
       agent_schema,
       agent_name,
       is_active,
       added_at,
       last_discovered,
       notes
   FROM AGENT_REGISTRY
   WHERE is_active = TRUE;
   ```

2. **Check task execution:**
   ```sql
   SELECT
       name,
       state,
       scheduled_time,
       completed_time,
       error_code,
       error_message
   FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
       SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
   ))
   WHERE name = 'REFRESH_AGENT_EVENTS_TASK'
   ORDER BY scheduled_time DESC;
   ```

3. **Test observability function directly:**
   ```sql
   SELECT
       record:timestamp::TIMESTAMP_LTZ AS event_time,
       record:span_name::STRING AS span_name,
       record:attributes:thread_id::STRING AS thread_id,
       record:attributes:user_id::STRING AS user_id,
       record:attributes:total_tokens::NUMBER AS total_tokens,
       record:attributes:duration_ms::NUMBER AS duration_ms,
       record:attributes:status::STRING AS status
   FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
       '<db>', '<schema>', '<agent>', 'CORTEX AGENT'
   ))
   LIMIT 10;
   ```

### Empty THREAD_ACTIVITY view

- Views filter to last 24 hours by default
- Check if agents have had activity: `SELECT agent_full_name, event_timestamp, span_name, thread_id, user_id, total_tokens, status FROM AGENT_EVENTS ORDER BY event_timestamp DESC LIMIT 10`
- Verify agents are being called with thread IDs

### Performance issues

- Dashboard queries are optimized for 24-hour windows
- Serverless task runs every 10 minutes (adjust lookback hours if needed)
- Agent discovery is expensive - run on schedule, not per query

### Extending data retention

Wallmonitor maintains two windows:
- Snapshot window (used by realtime views): `LOOKBACK_HOURS` (default 24)
- Recent-history window (used by dynamic tables): `HISTORY_DAYS` (default 30)

```sql
-- Default: 24h snapshot + 30d recent history
CALL REFRESH_AGENT_EVENTS(24, 30);

-- Lower cost: 24h snapshot + 7d recent history
CALL REFRESH_AGENT_EVENTS(24, 7);

-- Update the task configuration (recommended)
ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;
CALL SETUP_MONITORING(24, 7);
```

Note: larger history windows increase storage and dynamic table refresh cost. Keep `TARGET_LAG` conservative unless you need tighter freshness.

## Files

| File | Purpose |
|------|---------|
| `DELIVERY_GUIDE.md` | **START HERE for customer delivery** - One-shot queries, monitoring strategies, dashboard API patterns |
| `deploy.sql` | Complete deployment (run once, everything included) |
| `teardown.sql` | Cleanup script (removes objects created by deploy.sql) |
| `example_queries.sql` | 60+ dashboard-ready query examples |
| Streamlit app | Deployed by `deploy.sql` into the `WALLMONITOR_DASHBOARD` Streamlit object (multi-page app) |
| `diagrams/` | Architecture diagrams (data-model, data-flow, network-flow, auth-flow) |
| `enhancements.md` | Future improvements and advanced options |
| `README.md` | This documentation (architecture & operations) |

## Future Enhancements

- [ ] Cortex Search integration (search service usage metrics)
- [ ] Cost tracking (backfill from ACCOUNT_USAGE)
- [ ] Anomaly detection (auto-alert on unusual patterns)
- [ ] Cross-account aggregation (organization-wide view)
- [ ] Multi-page Streamlit dashboard (current: single-page WALLMONITOR_DASHBOARD)
