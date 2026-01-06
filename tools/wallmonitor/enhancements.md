# Wallmonitor: Future Enhancements

This document outlines potential improvements to extend Wallmonitor's capabilities beyond the current real-time implementation.

## Current Implementation

**Architecture:** Standard views calling table function on-demand
**Data Window:** Last 24 hours (configurable)
**Latency:** Seconds (real-time)
**Storage:** None (computed on query)

---

## Enhancement 1: Extended Retention with Dynamic Tables

### Problem
Current implementation limits queries to 24-hour windows. For trend analysis, capacity planning, and historical comparison, we need 30-90 days of data.

### Solution: Multi-Tier Architecture

```
┌────────────────────────────────────────────────────────┐
│ TIER 1: Real-Time (Current)                           │
│ - Standard views                                       │
│ - Last 24 hours                                        │
│ - Seconds latency                                      │
│ - No storage cost                                      │
└────────────────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│ TIER 2: Recent History (Dynamic Table)                │
│ - Auto-refreshing materialized view                   │
│ - Last 30 days                                         │
│ - 1-5 minute lag                                       │
│ - Storage cost: ~moderate                             │
└────────────────────────────────────────────────────────┘
                         │
                         ▼
┌────────────────────────────────────────────────────────┐
│ TIER 3: Long-Term Analytics (Standard Table + Task)   │
│ - Daily aggregations                                   │
│ - 90+ days                                             │
│ - Daily refresh                                        │
│ - Storage cost: ~low (aggregated)                     │
└────────────────────────────────────────────────────────┘
```

### Implementation

#### Tier 2: Dynamic Table for 30-Day Retention

```sql
USE SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR;

-- Create dynamic table with 5-minute refresh
CREATE DYNAMIC TABLE AGENT_EVENTS_HISTORY
TARGET_LAG = '5 minute'
WAREHOUSE = compute_wh
COMMENT = 'Historical agent events with automatic refresh (last 30 days)'
AS
SELECT * FROM TABLE(COLLECT_AGENT_EVENTS(720));  -- 30 days = 720 hours

-- Create dynamic table for thread aggregations
CREATE DYNAMIC TABLE THREAD_ACTIVITY_HISTORY
TARGET_LAG = '5 minute'
WAREHOUSE = compute_wh
COMMENT = 'Historical thread aggregations (last 30 days)'
AS
SELECT
    agent_full_name,
    thread_id,
    user_id,
    MIN(event_timestamp) AS thread_start_time,
    MAX(event_timestamp) AS thread_last_activity,
    DATEDIFF('second', MIN(event_timestamp), MAX(event_timestamp)) AS thread_duration_seconds,
    COUNT(*) AS total_events,
    COUNT(DISTINCT span_id) AS total_spans,
    COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'RETRIEVAL' THEN span_id END) AS retrieval_calls,
    SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
    SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
    SUM(COALESCE(total_tokens, 0)) AS total_tokens,
    SUM(COALESCE(span_duration_ms, 0)) AS total_duration_ms,
    AVG(CASE WHEN span_category = 'LLM_CALL' THEN span_duration_ms END) AS avg_llm_latency_ms,
    AVG(CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_duration_ms END) AS avg_tool_latency_ms,
    COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count,
    COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count,
    MAX_BY(status, event_timestamp) AS latest_status,
    MAX_BY(model_name, event_timestamp) AS latest_model
FROM AGENT_EVENTS_HISTORY
WHERE thread_id IS NOT NULL
GROUP BY agent_full_name, thread_id, user_id;
```

#### Tier 3: Daily Aggregations for Long-Term Analytics

```sql
-- Create table for daily summaries
CREATE TABLE DAILY_AGENT_METRICS (
    event_date DATE NOT NULL,
    agent_full_name STRING NOT NULL,
    agent_database STRING,
    agent_schema STRING,
    agent_name STRING,

    -- Volume metrics
    unique_threads NUMBER,
    unique_users NUMBER,
    total_events NUMBER,
    llm_calls NUMBER,
    tool_calls NUMBER,
    retrieval_calls NUMBER,

    -- Token metrics
    total_tokens NUMBER,
    total_prompt_tokens NUMBER,
    total_completion_tokens NUMBER,
    avg_tokens_per_thread FLOAT,

    -- Performance metrics
    avg_span_duration_ms FLOAT,
    p50_span_duration_ms FLOAT,
    p95_span_duration_ms FLOAT,
    p99_span_duration_ms FLOAT,

    -- Quality metrics
    error_count NUMBER,
    success_count NUMBER,
    error_rate_pct FLOAT,

    -- Metadata
    created_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),

    PRIMARY KEY (event_date, agent_full_name)
);

-- Create task to refresh daily
CREATE OR REPLACE TASK REFRESH_DAILY_METRICS
WAREHOUSE = compute_wh
SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM UTC
COMMENT = 'Refresh daily agent metrics from historical events'
AS
MERGE INTO DAILY_AGENT_METRICS AS target
USING (
    SELECT
        DATE_TRUNC('day', event_timestamp) AS event_date,
        agent_full_name,
        agent_database,
        agent_schema,
        agent_name,
        COUNT(DISTINCT thread_id) AS unique_threads,
        COUNT(DISTINCT user_id) AS unique_users,
        COUNT(*) AS total_events,
        COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
        COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
        COUNT(DISTINCT CASE WHEN span_category = 'RETRIEVAL' THEN span_id END) AS retrieval_calls,
        SUM(COALESCE(total_tokens, 0)) AS total_tokens,
        SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
        SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
        AVG(COALESCE(total_tokens, 0)) AS avg_tokens_per_thread,
        AVG(span_duration_ms) AS avg_span_duration_ms,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY span_duration_ms) AS p50_span_duration_ms,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY span_duration_ms) AS p95_span_duration_ms,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY span_duration_ms) AS p99_span_duration_ms,
        COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count,
        COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count,
        ROUND(
            COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) * 100.0
            / NULLIF(COUNT(*), 0),
            2
        ) AS error_rate_pct
    FROM AGENT_EVENTS_HISTORY
    WHERE DATE_TRUNC('day', event_timestamp) = CURRENT_DATE() - 1  -- Yesterday
    GROUP BY
        DATE_TRUNC('day', event_timestamp),
        agent_full_name,
        agent_database,
        agent_schema,
        agent_name
) AS source
ON target.event_date = source.event_date
   AND target.agent_full_name = source.agent_full_name
WHEN MATCHED THEN
    UPDATE SET
        unique_threads = source.unique_threads,
        unique_users = source.unique_users,
        total_events = source.total_events,
        llm_calls = source.llm_calls,
        tool_calls = source.tool_calls,
        retrieval_calls = source.retrieval_calls,
        total_tokens = source.total_tokens,
        total_prompt_tokens = source.total_prompt_tokens,
        total_completion_tokens = source.total_completion_tokens,
        avg_tokens_per_thread = source.avg_tokens_per_thread,
        avg_span_duration_ms = source.avg_span_duration_ms,
        p50_span_duration_ms = source.p50_span_duration_ms,
        p95_span_duration_ms = source.p95_span_duration_ms,
        p99_span_duration_ms = source.p99_span_duration_ms,
        error_count = source.error_count,
        success_count = source.success_count,
        error_rate_pct = source.error_rate_pct
WHEN NOT MATCHED THEN
    INSERT (
        event_date, agent_full_name, agent_database, agent_schema, agent_name,
        unique_threads, unique_users, total_events, llm_calls, tool_calls, retrieval_calls,
        total_tokens, total_prompt_tokens, total_completion_tokens, avg_tokens_per_thread,
        avg_span_duration_ms, p50_span_duration_ms, p95_span_duration_ms, p99_span_duration_ms,
        error_count, success_count, error_rate_pct
    )
    VALUES (
        source.event_date, source.agent_full_name, source.agent_database, source.agent_schema, source.agent_name,
        source.unique_threads, source.unique_users, source.total_events, source.llm_calls, source.tool_calls, source.retrieval_calls,
        source.total_tokens, source.total_prompt_tokens, source.total_completion_tokens, source.avg_tokens_per_thread,
        source.avg_span_duration_ms, source.p50_span_duration_ms, source.p95_span_duration_ms, source.p99_span_duration_ms,
        source.error_count, source.success_count, source.error_rate_pct
    );

-- Enable the task
ALTER TASK REFRESH_DAILY_METRICS RESUME;
```

### Dashboard Query Changes

```sql
-- Real-time (last 24h) - Use current views
SELECT * FROM THREAD_ACTIVITY
WHERE thread_start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP());

-- Recent history (last 30 days) - Use dynamic table
SELECT * FROM THREAD_ACTIVITY_HISTORY
WHERE thread_start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP());

-- Long-term trends (90+ days) - Use daily aggregations
SELECT * FROM DAILY_AGENT_METRICS
WHERE event_date >= DATEADD('day', -90, CURRENT_DATE())
ORDER BY event_date;
```

### Cost Considerations

| Tier | Storage | Compute | Total Monthly (Est.) |
|------|---------|---------|----------------------|
| Tier 1 (Views) | $0 | ~$5 (query cost) | **$5** |
| Tier 2 (Dynamic Table, 30d) | ~$50 | ~$100 (5min refresh) | **$150** |
| Tier 3 (Daily Table, 90d) | ~$5 (aggregated) | ~$10 (daily task) | **$15** |

**Total with all tiers:** ~$170/month

**Optimization options:**
- Reduce dynamic table refresh to 15 minutes: saves ~50% compute
- Use smaller warehouse: saves ~50% compute
- Reduce retention windows: saves storage

---

## Enhancement 2: Hybrid Tables for Ultra-Low Latency

### Problem
Dashboard queries on 1000s of concurrent threads can be slow even with dynamic tables. Sub-100ms response time needed for live monitoring.

### Solution: Hybrid Tables with Direct Writes

**Architecture Change:** Agents write events directly to Hybrid Table instead of relying on observability API polling.

```sql
-- Create hybrid table with indexes
CREATE HYBRID TABLE REALTIME_THREAD_EVENTS (
    thread_id STRING NOT NULL,
    event_timestamp TIMESTAMP_LTZ NOT NULL,
    event_sequence NUMBER NOT NULL,
    agent_full_name STRING NOT NULL,
    user_id STRING,
    span_category STRING,
    span_name STRING,
    model_name STRING,
    total_tokens NUMBER,
    prompt_tokens NUMBER,
    completion_tokens NUMBER,
    span_duration_ms NUMBER,
    tool_name STRING,
    status STRING,
    error_message STRING,

    PRIMARY KEY (thread_id, event_timestamp, event_sequence),
    INDEX idx_timestamp (event_timestamp),
    INDEX idx_agent (agent_full_name),
    INDEX idx_user (user_id),
    INDEX idx_status (status)
)
COMMENT = 'Ultra-low latency thread events with row-level access';

-- Query examples (sub-100ms)
-- Single thread lookup
SELECT * FROM REALTIME_THREAD_EVENTS
WHERE thread_id = 'abc-123-def'
ORDER BY event_timestamp;

-- Recent errors
SELECT * FROM REALTIME_THREAD_EVENTS
WHERE status = 'error'
  AND event_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC;

-- Active threads by user
SELECT thread_id, COUNT(*) AS events
FROM REALTIME_THREAD_EVENTS
WHERE user_id = 'user@example.com'
  AND event_timestamp >= DATEADD('minute', -15, CURRENT_TIMESTAMP())
GROUP BY thread_id;
```

### Application Integration

Agents must write events on each span completion:

```python
import snowflake.connector

def log_agent_event(thread_id, span_data):
    conn = snowflake.connector.connect(...)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO WALLMONITOR.REALTIME_THREAD_EVENTS (
            thread_id, event_timestamp, event_sequence, agent_full_name,
            user_id, span_category, model_name, total_tokens, span_duration_ms, status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        thread_id,
        span_data.timestamp,
        span_data.sequence,
        'MY_DB.MY_SCHEMA.SUPPORT_AGENT',
        span_data.user_id,
        span_data.category,
        span_data.model,
        span_data.tokens,
        span_data.duration_ms,
        span_data.status
    ))
```

### Trade-offs

**Pros:**
- Sub-100ms queries (vs 2-10 seconds with function)
- Row-level operations (UPDATE/DELETE specific events)
- Primary key enforcement (no duplicates)
- Indexes for fast filtering

**Cons:**
- Application must write events (can't use observability API alone)
- Row limit (~10M rows recommended)
- Feature in preview (not fully GA)
- Additional application complexity

**When to Use:**
- You control agent code
- Ultra-low latency critical (real-time dashboard with <100ms SLA)
- Need to update/delete events (data quality use case)

---

## Enhancement 3: Cost Tracking Integration

### Problem
Current implementation shows tokens but not credits/costs. For chargeback and budget tracking, need cost data.

### Solution: Backfill from ACCOUNT_USAGE

```sql
-- Create view joining events with cost data
CREATE OR REPLACE VIEW THREAD_ACTIVITY_WITH_COST AS
WITH event_costs AS (
    SELECT
        e.thread_id,
        e.agent_full_name,
        e.event_timestamp,
        e.total_tokens,
        c.total_credits,
        c.input_credits,
        c.output_credits
    FROM AGENT_EVENTS e
    LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY c
        ON e.query_id = c.query_id  -- If we tracked query_id
)
SELECT
    thread_id,
    agent_full_name,
    SUM(total_tokens) AS total_tokens,
    SUM(total_credits) AS total_credits,
    SUM(input_credits) AS input_credits,
    SUM(output_credits) AS output_credits,
    AVG(total_credits / NULLIF(total_tokens, 0)) AS cost_per_token
FROM event_costs
GROUP BY thread_id, agent_full_name;
```

**Challenge:** `GET_AI_OBSERVABILITY_EVENTS()` doesn't provide query_id for joining with ACCOUNT_USAGE. Would need to:
1. Capture query_id from agent context when available
2. Use approximate matching (timestamp + model + tokens)
3. Accept 45min-3hr lag for cost backfill

---

## Enhancement 4: Anomaly Detection & Auto-Alerting

### Problem
Manually checking for slow threads, high errors, or unusual patterns is reactive. Need proactive alerting.

### Solution: Scheduled Anomaly Detection

```sql
-- Create table to store anomalies
CREATE TABLE ANOMALY_LOG (
    detected_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    anomaly_type STRING,
    severity STRING,  -- CRITICAL, WARNING, INFO
    agent_full_name STRING,
    thread_id STRING,
    metric_name STRING,
    metric_value FLOAT,
    baseline_value FLOAT,
    deviation_pct FLOAT,
    details VARIANT,
    PRIMARY KEY (detected_at, anomaly_type, agent_full_name)
);

-- Task to detect anomalies every 5 minutes
CREATE OR REPLACE TASK DETECT_ANOMALIES
WAREHOUSE = compute_wh
SCHEDULE = '5 minute'
AS
INSERT INTO ANOMALY_LOG (anomaly_type, severity, agent_full_name, thread_id, metric_name, metric_value, baseline_value, deviation_pct)
-- Slow thread detection (>2x p95)
SELECT
    'SLOW_THREAD' AS anomaly_type,
    'WARNING' AS severity,
    t.agent_full_name,
    t.thread_id,
    'thread_duration_seconds' AS metric_name,
    t.thread_duration_seconds AS metric_value,
    a.p95_span_duration_ms / 1000.0 AS baseline_value,
    (t.thread_duration_seconds - (a.p95_span_duration_ms / 1000.0)) * 100.0 / (a.p95_span_duration_ms / 1000.0) AS deviation_pct
FROM THREAD_ACTIVITY t
JOIN AGENT_METRICS a ON t.agent_full_name = a.agent_full_name
WHERE t.thread_last_activity >= DATEADD('minute', -5, CURRENT_TIMESTAMP())
  AND t.thread_duration_seconds > (a.p95_span_duration_ms / 1000.0) * 2

UNION ALL

-- High error rate detection (>10% in last 5 min)
SELECT
    'HIGH_ERROR_RATE' AS anomaly_type,
    'CRITICAL' AS severity,
    agent_full_name,
    NULL AS thread_id,
    'error_rate_pct' AS metric_name,
    error_rate_pct AS metric_value,
    5.0 AS baseline_value,
    (error_rate_pct - 5.0) AS deviation_pct
FROM (
    SELECT
        agent_full_name,
        COUNT(CASE WHEN error_count > 0 THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) AS error_rate_pct
    FROM THREAD_ACTIVITY
    WHERE thread_start_time >= DATEADD('minute', -5, CURRENT_TIMESTAMP())
    GROUP BY agent_full_name
)
WHERE error_rate_pct > 10;

-- Enable task
ALTER TASK DETECT_ANOMALIES RESUME;

-- Query anomalies for alerting
SELECT * FROM ANOMALY_LOG
WHERE detected_at >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY severity DESC, detected_at DESC;
```

### Integration with Alerting

Use Snowflake email/webhook notifications:

```sql
CREATE NOTIFICATION INTEGRATION anomaly_alerts
TYPE = EMAIL
ENABLED = TRUE
ALLOWED_RECIPIENTS = ('ops-team@example.com');

-- Alert on critical anomalies
CREATE OR REPLACE TASK SEND_ANOMALY_ALERTS
WAREHOUSE = compute_wh
SCHEDULE = '5 minute'
WHEN SYSTEM$STREAM_HAS_DATA('ANOMALY_STREAM')
AS
CALL SYSTEM$SEND_EMAIL(
    'anomaly_alerts',
    'ops-team@example.com',
    'Wallmonitor Alert: Agent Anomalies Detected',
    (SELECT LISTAGG(anomaly_type || ' - ' || agent_full_name, '\n')
     FROM ANOMALY_LOG
     WHERE severity = 'CRITICAL'
       AND detected_at >= DATEADD('minute', -5, CURRENT_TIMESTAMP()))
);
```

---

## Enhancement 5: Organization-Wide (Cross-Account) Monitoring

### Problem
Large organizations have multiple Snowflake accounts. Need unified view across all accounts.

### Solution: Data Sharing + Central Aggregator

**Architecture:**

```
Account A (miwhitaker-prod)
├── WALLMONITOR schema
└── SHARE: WALLMONITOR_SHARE
        ↓
Account B (miwhitaker-dev)      Central Account (monitoring-hub)
├── WALLMONITOR schema          ├── FROM SHARE: account_a_events
└── SHARE: WALLMONITOR_SHARE    ├── FROM SHARE: account_b_events
        ↓                        └── VIEW: ORG_WIDE_AGENT_EVENTS
        └────────────────────────────→
```

**Implementation:**

```sql
-- In each source account (A, B, etc.)
CREATE SHARE WALLMONITOR_SHARE;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO SHARE WALLMONITOR_SHARE;
GRANT USAGE ON SCHEMA WALLMONITOR TO SHARE WALLMONITOR_SHARE;
GRANT SELECT ON TABLE AGENT_EVENTS_HISTORY TO SHARE WALLMONITOR_SHARE;

-- Share to central account
ALTER SHARE WALLMONITOR_SHARE ADD ACCOUNTS = central_org_account;

-- In central account
CREATE DATABASE ACCOUNT_A_WALLMONITOR FROM SHARE source_account_a.WALLMONITOR_SHARE;
CREATE DATABASE ACCOUNT_B_WALLMONITOR FROM SHARE source_account_b.WALLMONITOR_SHARE;

-- Create unified view
CREATE OR REPLACE VIEW ORG_WIDE_AGENT_EVENTS AS
SELECT 'account-a' AS source_account, * FROM ACCOUNT_A_WALLMONITOR.WALLMONITOR.AGENT_EVENTS_HISTORY
UNION ALL
SELECT 'account-b' AS source_account, * FROM ACCOUNT_B_WALLMONITOR.WALLMONITOR.AGENT_EVENTS_HISTORY;
```

---

## Enhancement 6: Streamlit Dashboard Template

### Problem
Wallmonitor provides SQL queries but users must build UI.

### Solution: Pre-built Streamlit Dashboard

```python
# streamlit_app.py
import streamlit as st
import snowflake.snowpark as snowpark

st.set_page_config(page_title="Wallmonitor", layout="wide")

# Connect to Snowflake
session = snowpark.Session.builder.configs(st.secrets["snowflake"]).create()

# KPI Cards
col1, col2, col3, col4 = st.columns(4)
kpi_df = session.sql("SELECT * FROM WALLMONITOR.REALTIME_KPI").to_pandas()

with col1:
    st.metric("Active Threads", kpi_df['active_threads'][0],
              delta=f"{kpi_df['threads_change_pct'][0]}%")
with col2:
    st.metric("LLM Calls", kpi_df['llm_calls'][0],
              delta=f"{kpi_df['llm_calls_change_pct'][0]}%")
with col3:
    st.metric("Total Tokens", f"{kpi_df['total_tokens'][0]:,}",
              delta=f"{kpi_df['tokens_change_pct'][0]}%")
with col4:
    st.metric("Avg Latency", f"{kpi_df['avg_span_duration_ms'][0]:.0f}ms",
              delta=f"{kpi_df['latency_change_pct'][0]}%")

# Thread List
st.subheader("Recent Threads")
threads_df = session.sql("""
    SELECT * FROM WALLMONITOR.THREAD_ACTIVITY
    ORDER BY thread_start_time DESC LIMIT 50
""").to_pandas()
st.dataframe(threads_df, use_container_width=True)

# Time-Series Chart
st.subheader("Hourly Activity")
hourly_df = session.sql("""
    SELECT event_hour, SUM(unique_threads) AS threads
    FROM WALLMONITOR.HOURLY_THREAD_ACTIVITY
    WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
    GROUP BY event_hour ORDER BY event_hour
""").to_pandas()
st.line_chart(hourly_df.set_index('EVENT_HOUR'))
```

---

## Priority Ranking

| Enhancement | Effort | Value | Priority |
|-------------|--------|-------|----------|
| 1. Dynamic Tables (30d retention) | Low | High | **P0** |
| 3. Cost Tracking | Medium | High | **P1** |
| 4. Anomaly Detection | Medium | Medium | **P1** |
| 6. Streamlit Dashboard | Medium | Medium | **P2** |
| 1. Daily Aggregations (90d) | Low | Low | **P2** |
| 2. Hybrid Tables | High | Medium | **P3** |
| 5. Org-Wide Monitoring | High | Low | **P3** |

---

## Quick Wins (Implement First)

### Week 1: Add Dynamic Table for 30-Day Retention
- Deploy `AGENT_EVENTS_HISTORY` dynamic table
- Update dashboard queries to use it for date ranges >24h
- Monitor cost and adjust `TARGET_LAG` if needed

### Week 2: Basic Cost Tracking
- Add query_id tracking to event collector
- Create cost backfill view joining with ACCOUNT_USAGE
- Add cost columns to dashboard

### Week 3: Simple Alerting
- Deploy `ANOMALY_LOG` table
- Create detection task for critical issues
- Set up email notifications

---

## Cost-Benefit Analysis

### Dynamic Tables (Recommended)
- **Cost:** ~$150/month
- **Benefit:** 30-day retention, 5x faster queries, trend analysis
- **ROI:** High - enables historical analysis without rebuilding infrastructure

### Hybrid Tables
- **Cost:** ~$50/month + application changes
- **Benefit:** Sub-100ms queries, row-level operations
- **ROI:** Medium - only if ultra-low latency critical

### Anomaly Detection
- **Cost:** ~$10/month
- **Benefit:** Proactive issue detection, reduced MTTR
- **ROI:** High - prevents outages, improves reliability

---

## Next Steps

1. **Validate Requirements:** Determine if 24-hour window is sufficient or if extended retention needed
2. **Pilot Dynamic Tables:** Start with 7-day retention, 15-minute lag to assess cost/value
3. **Measure Dashboard Performance:** Baseline current query times to justify further optimization
4. **Build Business Case:** Estimate cost savings from proactive anomaly detection vs reactive firefighting
