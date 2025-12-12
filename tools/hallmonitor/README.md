# Wallmonitor: Agent-Focused Cortex AI Monitoring

> **Purpose:** Real-time monitoring for Cortex Agent threads and runs with near real-time observability.

**Author:** SE Community  
**Expires:** 2026-01-10

---

## 🚀 Which Guide Do You Need?

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
│  - Populates AGENT_EVENTS_SNAPSHOT table               │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  DASHBOARD VIEWS (6 total)                              │
│  - AGENT_EVENTS: Raw unified events                    │
│  - THREAD_ACTIVITY: Thread-level metrics               │
│  - AGENT_METRICS: Per-agent performance                │
│  - REALTIME_KPI: Dashboard header KPIs                 │
│  - HOURLY_THREAD_ACTIVITY: Time-series data            │
│  - THREAD_TIMELINE: Drill-down detail                  │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

> 💡 **For delivery teams:** See `DELIVERY_GUIDE.md` for one-shot queries, monitoring strategies, and dashboard API patterns.

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

✅ **Use when:** Single agent, debugging, or demo

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
CALL SETUP_MONITORING(24);
-- ✅ Done! Data auto-refreshes every 10 minutes
```

#### 3. Query Dashboard

```sql
-- Real-time KPIs (auto-updated)
SELECT * FROM REALTIME_KPI;

-- Thread activity
SELECT * FROM THREAD_ACTIVITY
ORDER BY thread_start_time DESC
LIMIT 20;
```

✅ **Use when:** Multiple agents, production dashboard, historical trending

## Schema Structure

```
SNOWFLAKE_EXAMPLE.WALLMONITOR/
├── Tables
│   ├── AGENT_REGISTRY                -- Registered agents to monitor
│   └── AGENT_EVENTS_SNAPSHOT         -- Event cache (refreshed every 10 min)
├── Procedures
│   ├── DISCOVER_AGENTS()             -- Auto-discovery of agents
│   ├── REFRESH_AGENT_EVENTS()        -- Populate event snapshot
│   └── SETUP_MONITORING()            -- Create/resume serverless task
├── Tasks
│   └── REFRESH_AGENT_EVENTS_TASK     -- Serverless task (runs every 10 min)
└── Views
    ├── AGENT_EVENTS                  -- Raw unified events (last 24h)
    ├── THREAD_ACTIVITY               -- Thread-level aggregations
    ├── AGENT_METRICS                 -- Per-agent performance
    ├── REALTIME_KPI                  -- Last hour KPIs with comparison
    ├── HOURLY_THREAD_ACTIVITY        -- Hourly time-series data
    ├── THREAD_TIMELINE               -- Event-by-event drill-down
    └── (bonus views for cost/heatmaps)
```

## Data Sources

| Source | Latency | Data | Privileges Required |
|--------|---------|------|---------------------|
| `GET_AI_OBSERVABILITY_EVENTS()` | **Seconds** | Thread events, tokens, spans | `CORTEX_USER` role |
| `SHOW AGENTS` | Real-time | Agent enumeration | `USAGE` on databases/schemas containing agents |

## Dashboard Components

### KPI Cards (Header Metrics)

Query: `SELECT * FROM REALTIME_KPI`

Metrics (last hour with hour-over-hour comparison):
- Active Threads
- Active Users
- Active Agents
- LLM Calls
- Total Tokens
- Avg Latency
- Error Rate

### Thread List (Main View)

Query: `SELECT * FROM THREAD_ACTIVITY ORDER BY thread_start_time DESC LIMIT 50`

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

Query: `SELECT * FROM THREAD_TIMELINE WHERE thread_id = :id`

Timeline view showing:
- Each span in chronological order
- Span type (LLM, Tool, Retrieval, Agent)
- Tokens per span
- Latency per span
- Errors

### Agent Performance Comparison

Query: `SELECT * FROM AGENT_METRICS`

Per-agent metrics:
- Unique Threads/Users
- Call Counts (LLM/Tool/Retrieval)
- Token Totals
- Latency Percentiles (avg, p50, p95, p99)
- Error Rate
- Most Used Model

### Time-Series Charts

Query: `SELECT * FROM HOURLY_THREAD_ACTIVITY WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())`

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
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE <dashboard_role>;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE <dashboard_role>;
GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE <dashboard_role>;
GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE <dashboard_role>;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE <dashboard_role>;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE <dashboard_role>;
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
| `AGENT_EVENTS_SNAPSHOT` (Table) | Last 24 hours | 10 minutes | **10 minutes** |
| All Views/Aggregations | Based on snapshot | On query | **Instant** |

**How It Works:**
1. Serverless task runs `REFRESH_AGENT_EVENTS()` every 10 minutes
2. Procedure queries `GET_AI_OBSERVABILITY_EVENTS()` for each active agent
3. Results populate `AGENT_EVENTS_SNAPSHOT` table
4. All views read from the snapshot (instant queries)

**Task Management:**
```sql
-- Pause monitoring (stops serverless task)
ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;

-- Resume monitoring
ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;

-- Manual refresh (on-demand)
CALL REFRESH_AGENT_EVENTS(24);

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
   SELECT * FROM AGENT_REGISTRY WHERE is_active = TRUE;
   ```

2. **Check task execution:**
   ```sql
   SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
       SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
   ))
   WHERE name = 'REFRESH_AGENT_EVENTS_TASK'
   ORDER BY scheduled_time DESC;
   ```

3. **Test observability function directly:**
   ```sql
   SELECT * FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
       '<db>', '<schema>', '<agent>', 'CORTEX AGENT'
   )) LIMIT 10;
   ```

### Empty THREAD_ACTIVITY view

- Views filter to last 24 hours by default
- Check if agents have had activity: `SELECT * FROM AGENT_EVENTS LIMIT 10`
- Verify agents are being called with thread IDs

### Performance issues

- Dashboard queries are optimized for 24-hour windows
- Serverless task runs every 10 minutes (adjust lookback hours if needed)
- Agent discovery is expensive - run on schedule, not per query

### Extending data retention

To keep data longer than 24 hours, modify the `REFRESH_AGENT_EVENTS()` procedure:

```sql
-- Current: Last 24 hours
CALL REFRESH_AGENT_EVENTS(24);

-- Extended: Last 7 days
CALL REFRESH_AGENT_EVENTS(168);

-- Update task to use longer lookback:
ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;
-- Recreate task with longer retention:
CALL SETUP_MONITORING(168);  -- 7 days
```

**Note:** Longer retention increases query time and storage. Consider creating aggregated summary tables for historical analysis.

## Files

| File | Purpose |
|------|---------|
| `DELIVERY_GUIDE.md` | **START HERE for customer delivery** - One-shot queries, monitoring strategies, dashboard API patterns |
| `deploy.sql` | Complete deployment (run once, everything included) |
| `example_queries.sql` | 60+ dashboard-ready query examples |
| `enhancements.md` | Future improvements and advanced options |
| `README.md` | This documentation (architecture & operations) |

## Future Enhancements

- [ ] Cortex Search integration (search service usage metrics)
- [ ] Cost tracking (backfill from ACCOUNT_USAGE)
- [ ] Anomaly detection (auto-alert on unusual patterns)
- [ ] Cross-account aggregation (organization-wide view)
- [ ] Streamlit dashboard template
