# Wallmonitor: Delivery Guide for Customer Solutions

> **Purpose:** This guide provides exactly what you need to deliver Cortex Agent monitoring to customers.

**Author:** SE Community
**Created:** 2026-01-07
**Expires:** 2026-02-06

---

## 1. One-shot live query (get metrics now)

### Simplest Possible Query - Single Agent

```sql
-- Copy/paste this to get immediate metrics from ONE agent
-- Replace: MY_DB, MY_SCHEMA, MY_AGENT with actual values

USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;

SELECT
    record:thread_id::STRING AS thread_id,
    record:attributes:user_id::STRING AS user_id,
    record:timestamp::TIMESTAMP_LTZ AS event_time,
    record:span_name::STRING AS span_name,
    record:attributes:model_name::STRING AS model,
    record:attributes:prompt_tokens::NUMBER AS prompt_tokens,
    record:attributes:completion_tokens::NUMBER AS completion_tokens,
    record:attributes:total_tokens::NUMBER AS total_tokens,
    record:attributes:duration_ms::NUMBER AS latency_ms,
    record:attributes:status::STRING AS status,
    record:attributes:error_message::STRING AS error
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'MY_DB',           -- Replace with agent's database
    'MY_SCHEMA',       -- Replace with agent's schema
    'MY_AGENT',        -- Replace with agent's name
    'CORTEX AGENT'     -- Always this value
))
WHERE record:timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY record:timestamp DESC
LIMIT 100;
```

**Output:** Raw events from the last hour - available within seconds of agent activity.

### Quick KPIs - Single Agent

```sql
-- Get instant KPIs for ONE agent (last hour)
WITH events AS (
    SELECT
        record:thread_id::STRING AS thread_id,
        record:span_name::STRING AS span_name,
        record:attributes:total_tokens::NUMBER AS tokens,
        record:attributes:duration_ms::NUMBER AS latency_ms,
        record:attributes:status::STRING AS status
    FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
        'MY_DB', 'MY_SCHEMA', 'MY_AGENT', 'CORTEX AGENT'
    ))
    WHERE record:timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
)
SELECT
    COUNT(DISTINCT thread_id) AS active_threads,
    COUNT(*) AS total_events,
    SUM(CASE WHEN span_name = 'agent:run' THEN 1 ELSE 0 END) AS agent_runs,
    SUM(CASE WHEN span_name LIKE 'llm:%' THEN 1 ELSE 0 END) AS llm_calls,
    SUM(tokens) AS total_tokens,
    ROUND(AVG(latency_ms), 0) AS avg_latency_ms,
    SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) AS errors,
    ROUND(100.0 * SUM(CASE WHEN status = 'ERROR' THEN 1 ELSE 0 END) / COUNT(*), 2) AS error_rate_pct
FROM events;
```

When to use:
- Demo/exploration
- Single-agent debugging
- Verifying observability access
- Not recommended for multi-agent dashboards (too slow to query each agent individually)

---

## 2. Monitoring strategies (choose your path)

### Strategy Matrix

| Approach | Setup Time | Refresh Latency | Best For | Limitations |
|----------|------------|-----------------|----------|-------------|
| **One-Shot Query** | None | Real-time (seconds) | Single agent, debugging | Manual query per agent |
| **Automated (Wallmonitor + Streamlit)** | 5 minutes | 10 minutes (ingest) / 30 minutes (history rollups) | Multi-agent dashboards | Requires setup |
| **Custom ETL** | Hours | Your choice | Enterprise integration | Build your own |

### Strategy 1: One-Shot (No Setup)

**Use when:**
- Single agent to monitor
- Ad-hoc debugging
- Demo/exploration
- Verifying access

**How:**
```sql
-- Just query GET_AI_OBSERVABILITY_EVENTS() directly
SELECT
    record:timestamp::TIMESTAMP_LTZ AS event_time,
    record:span_name::STRING AS span_name,
    record:attributes:thread_id::STRING AS thread_id,
    record:attributes:user_id::STRING AS user_id,
    record:attributes:total_tokens::NUMBER AS total_tokens,
    record:attributes:duration_ms::NUMBER AS duration_ms,
    record:attributes:status::STRING AS status
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(...));
```

**Pros:** Zero setup, real-time data
**Cons:** Must query each agent separately

---

### Strategy 2: Automated Monitoring (Wallmonitor - This Tool)

**Use when:**
- Multiple agents (2+)
- Production dashboard
- Historical trending
- Operational monitoring

**How:**
```sql
-- Deploy Wallmonitor (5 minutes)
-- Run deploy.sql
CALL DISCOVER_AGENTS('%', NULL, TRUE);
CALL SETUP_MONITORING(24, 30);

-- Query unified views
SELECT
    active_threads,
    active_users,
    active_agents,
    llm_calls,
    total_tokens,
    avg_span_duration_ms,
    error_rate_pct
FROM REALTIME_KPI;

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
ORDER BY thread_start_time DESC;
```

Open Streamlit dashboard in Snowsight: Projects -> Streamlit -> WALLMONITOR_DASHBOARD

**Pros:**
- Multi-agent unified view
- Auto-discovery
- 10-minute refresh
- Dashboard-ready views

**Cons:**
- Initial setup required
- 10-minute data lag

---

### Strategy 3: Custom ETL (Your Own)

**Use when:**
- Complex enterprise requirements
- Custom retention policies
- Integration with existing systems
- Sub-minute refresh needed

**How:**
- Call `GET_AI_OBSERVABILITY_EVENTS()` from your ETL tool
- Store in your data warehouse
- Build custom aggregations

**Pros:** Full control, custom logic
**Cons:** You build and maintain everything

---

## 3. Dashboard query patterns (API-ready)

These queries are formatted for REST API consumption (e.g., React dashboard calling Snowflake SQL API).

### Pattern 1: KPI Cards (Header Metrics)

```sql
-- API Endpoint: /api/metrics/kpi
-- Method: GET
-- Refresh: Every 30-60 seconds

SELECT
    active_threads,
    active_users,
    active_agents,
    llm_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 0) AS avg_latency_ms,
    error_rate_pct,
    threads_change_pct,
    llm_calls_change_pct,
    tokens_change_pct
FROM REALTIME_KPI;
```

**Expected Output (JSON):**
```json
{
  "active_threads": 42,
  "active_users": 12,
  "active_agents": 5,
  "llm_calls": 156,
  "total_tokens": 45230,
  "avg_latency_ms": 1250,
  "error_rate_pct": 2.3,
  "threads_change_pct": 15.2,
  "llm_calls_change_pct": -5.1,
  "tokens_change_pct": 8.7
}
```

---

### Pattern 2: Thread List (Main Table)

```sql
-- API Endpoint: /api/threads
-- Method: GET
-- Parameters: ?limit=50&offset=0&agent_filter=null
-- Refresh: Every 10-30 seconds

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
WHERE
    (:agent_filter IS NULL OR agent_full_name = :agent_filter)
ORDER BY thread_start_time DESC
LIMIT :limit OFFSET :offset;
```

**Expected Output (JSON Array):**
```json
[
  {
    "thread_id": "01234567-89ab-cdef-0123-456789abcdef",
    "agent_full_name": "MYDB.MYSCHEMA.SUPPORT_AGENT",
    "user_id": "user@example.com",
    "thread_start_time": "2025-12-11T10:30:00Z",
    "thread_last_activity": "2025-12-11T10:32:15Z",
    "thread_duration_seconds": 135,
    "llm_calls": 3,
    "tool_calls": 2,
    "retrieval_calls": 1,
    "total_tokens": 1250,
    "error_count": 0,
    "latest_status": "OK",
    "latest_model": "mistral-large2"
  }
]
```

---

### Pattern 3: Thread Detail (Drill-Down)

```sql
-- API Endpoint: /api/threads/:thread_id
-- Method: GET
-- Parameters: thread_id (path parameter)
-- Refresh: On-demand (cached 10s)

SELECT
    event_timestamp,
    event_sequence,
    seconds_since_thread_start,
    span_name,
    span_category,
    model_name,
    total_tokens,
    prompt_tokens,
    completion_tokens,
    span_duration_ms,
    tool_name,
    retrieval_query,
    status,
    error_message
FROM THREAD_TIMELINE
WHERE thread_id = :thread_id
ORDER BY event_timestamp;
```

**Expected Output (JSON Array - Timeline):**
```json
[
  {
    "event_timestamp": "2025-12-11T10:30:00Z",
    "event_sequence": 1,
    "seconds_since_thread_start": 0,
    "span_name": "agent:run",
    "span_category": "Agent",
    "model_name": null,
    "total_tokens": 0,
    "span_duration_ms": 125,
    "status": "OK"
  },
  {
    "event_timestamp": "2025-12-11T10:30:01Z",
    "event_sequence": 2,
    "seconds_since_thread_start": 1,
    "span_name": "llm:chat",
    "span_category": "LLM",
    "model_name": "mistral-large2",
    "total_tokens": 456,
    "prompt_tokens": 128,
    "completion_tokens": 328,
    "span_duration_ms": 1250,
    "status": "OK"
  }
]
```

---

### Pattern 4: Agent Performance (Comparison Table)

```sql
-- API Endpoint: /api/agents/performance
-- Method: GET
-- Parameters: ?time_window=1h
-- Refresh: Every 60 seconds

SELECT
    agent_full_name,
    unique_threads,
    unique_users,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 0) AS avg_latency_ms,
    ROUND(p50_span_duration_ms, 0) AS p50_latency_ms,
    ROUND(p95_span_duration_ms, 0) AS p95_latency_ms,
    error_rate_pct,
    most_used_model
FROM AGENT_METRICS
ORDER BY unique_threads DESC;
```

**Expected Output (JSON Array):**
```json
[
  {
    "agent_full_name": "MYDB.PROD.SUPPORT_AGENT",
    "unique_threads": 42,
    "unique_users": 12,
    "llm_calls": 156,
    "tool_calls": 45,
    "retrieval_calls": 23,
    "total_tokens": 45230,
    "avg_latency_ms": 1250,
    "p50_latency_ms": 980,
    "p95_latency_ms": 2300,
    "error_rate_pct": 2.3,
    "most_used_model": "mistral-large2"
  }
]
```

---

### Pattern 5: Time-Series Chart (Hourly Trends)

```sql
-- API Endpoint: /api/metrics/timeseries
-- Method: GET
-- Parameters: ?hours=24
-- Refresh: Every 60 seconds

SELECT
    event_hour,
    active_threads,
    unique_users,
    active_agents,
    total_events,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 0) AS avg_latency_ms,
    errors,
    error_rate_pct
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -:hours, CURRENT_TIMESTAMP())
ORDER BY event_hour;
```

**Expected Output (JSON Array - Chart Data):**
```json
[
  {
    "event_hour": "2025-12-11T10:00:00Z",
    "active_threads": 15,
    "unique_users": 8,
    "llm_calls": 45,
    "total_tokens": 12340,
    "avg_latency_ms": 1050,
    "error_rate_pct": 1.2
  },
  {
    "event_hour": "2025-12-11T11:00:00Z",
    "active_threads": 23,
    "unique_users": 12,
    "llm_calls": 67,
    "total_tokens": 18920,
    "avg_latency_ms": 1150,
    "error_rate_pct": 2.1
  }
]
```

---

### Pattern 6: Error Log (Alert Component)

```sql
-- API Endpoint: /api/errors/recent
-- Method: GET
-- Parameters: ?limit=20
-- Refresh: Every 30 seconds

SELECT
    event_timestamp,
    thread_id,
    agent_full_name,
    user_id,
    span_name,
    error_message,
    model_name,
    tool_name
FROM AGENT_EVENTS
WHERE status = 'ERROR'
    AND event_timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY event_timestamp DESC
LIMIT :limit;
```

**Expected Output (JSON Array):**
```json
[
  {
    "event_timestamp": "2025-12-11T11:45:32Z",
    "thread_id": "abc-123",
    "agent_full_name": "MYDB.PROD.SUPPORT_AGENT",
    "user_id": "user@example.com",
    "span_name": "tool:execute",
    "error_message": "Tool execution timeout after 30s",
    "model_name": null,
    "tool_name": "search_knowledge_base"
  }
]
```

---

### Pattern 7: Filter Dropdowns (UI Components)

```sql
-- API Endpoint: /api/filters/agents
-- Method: GET
-- Refresh: Every 5 minutes (cached)

SELECT DISTINCT agent_full_name
FROM AGENT_EVENTS
WHERE event_timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY agent_full_name;
```

```sql
-- API Endpoint: /api/filters/users
SELECT DISTINCT user_id
FROM AGENT_EVENTS
WHERE event_timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
    AND user_id IS NOT NULL
ORDER BY user_id;
```

```sql
-- API Endpoint: /api/filters/models
SELECT DISTINCT model_name, COUNT(*) AS usage_count
FROM AGENT_EVENTS
WHERE model_name IS NOT NULL
    AND event_timestamp >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY model_name
ORDER BY usage_count DESC;
```

---

## 🎯 Quick Decision Tree

**Start here:** What's your use case?

```
Are you monitoring just ONE agent?
├─ YES → Use One-Shot Query (Section 1)
│         No setup, real-time, simple
│
└─ NO → Multiple agents?
    └─ YES → Do you need a dashboard?
        ├─ YES → Deploy Wallmonitor (Section 2, Strategy 2)
        │         Use Dashboard Patterns (Section 3)
        │
        └─ NO → Do you have custom requirements?
            ├─ YES → Build Custom ETL (Section 2, Strategy 3)
            └─ NO → Start with Wallmonitor, customize later
```

---

## Complete dashboard example (React)

### Dashboard Component Structure

```
┌─────────────────────────────────────────┐
│  KPI Cards (Pattern 1)                  │  ← Query every 30s
│  [Active Threads] [Tokens] [Latency]    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Thread List Table (Pattern 2)          │  ← Query every 10s
│  [Thread ID] [Agent] [User] [Status]    │     Paginated
│  [Click to drill down]                  │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Thread Detail Modal (Pattern 3)        │  ← On-demand
│  [Event Timeline] [Tokens] [Latency]    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Time-Series Chart (Pattern 5)          │  ← Query every 60s
│  [Hourly thread volume line chart]      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Error Log (Pattern 6)                  │  ← Query every 30s
│  [Recent errors with timestamps]        │
└─────────────────────────────────────────┘
```

### API Implementation Checklist

- [ ] **KPI Cards**: Implement Pattern 1 with 30s polling
- [ ] **Thread List**: Implement Pattern 2 with pagination
- [ ] **Thread Detail**: Implement Pattern 3 as modal/drawer
- [ ] **Time-Series**: Implement Pattern 5 with recharts/d3
- [ ] **Error Log**: Implement Pattern 6 with auto-refresh
- [ ] **Filters**: Implement Pattern 7 for dropdowns
- [ ] **Loading States**: Show skeleton/spinner during queries
- [ ] **Error Handling**: Graceful degradation if queries fail
- [ ] **Caching**: Client-side cache with SWR or React Query
- [ ] **Websockets** (Optional): Replace polling with real-time updates

---

## 🔐 Security Checklist for Delivery

- [ ] Customer has `CORTEX_USER` role granted
- [ ] Customer has `ACCOUNTADMIN` or equivalent for setup
- [ ] Agents have `MONITOR` privilege granted (if using individual grants)
- [ ] Verify `GET_AI_OBSERVABILITY_EVENTS()` works for at least one agent
- [ ] Network access: Snowflake SQL API accessible from dashboard app
- [ ] Authentication: Snowflake OAuth or key-pair for API calls
- [ ] Rate limiting: Don't query faster than data refresh (10 min)

---

## 📝 Delivery Checklist

### For Customers

**Before the meeting:**
- [ ] Confirm customer has Cortex Agents deployed
- [ ] Get agent names/locations (DB.SCHEMA.AGENT)
- [ ] Verify observability access with one-shot query

**During the meeting:**
- [ ] Show one-shot query (Section 1) - instant results
- [ ] Explain monitoring strategies (Section 2)
- [ ] Deploy Wallmonitor if multi-agent (5 minutes)
- [ ] Demo dashboard queries (Section 3)

**After the meeting:**
- [ ] Share `deploy.sql` and this guide
- [ ] Share `example_queries.sql` for reference
- [ ] Share dashboard query patterns (Section 3)

### For Dashboard Developers

- [ ] Use Snowflake SQL API or connector
- [ ] Implement query patterns from Section 3
- [ ] Add parameter binding (`:thread_id`, `:agent_filter`, etc.)
- [ ] Add error handling and loading states
- [ ] Test with real agent data
- [ ] Document refresh intervals for each endpoint

---

## Next steps after delivery

1. **Immediate (Day 1):**
   - Verify one-shot query works
   - Deploy Wallmonitor if multi-agent
   - Confirm data appearing in views

2. **Short-term (Week 1):**
   - Build dashboard with patterns from Section 3
   - Add filtering and drill-down
   - Test with real user activity

3. **Long-term (Month 1+):**
   - Add alerting (slow threads, errors)
   - Historical trending
   - Cost tracking (backfill from ACCOUNT_USAGE)
   - Custom aggregations

---

## 📞 Support Resources

- **Documentation**: See `README.md` for architecture details
- **Query Library**: See `example_queries.sql` for 60+ examples
- **Enhancements**: See `enhancements.md` for future ideas
- **Troubleshooting**: See `README.md` → Troubleshooting section
