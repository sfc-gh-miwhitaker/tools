-- =============================================================================
-- WALLMONITOR: Thread-Focused Dashboard Queries
-- =============================================================================
-- Purpose: Example queries for React dashboard components monitoring
--          Cortex Agent threads and runs
-- Schema: SNOWFLAKE_EXAMPLE.WALLMONITOR
-- Author: SE Community
-- Created: 2026-01-07
-- Expires: 2026-02-06
--
-- Organization:
--   1. Setup & Discovery
--   2. Real-Time KPI Cards
--   3. Thread-Focused Queries
--   4. Agent Performance Queries
--   5. Time-Series Charts
--   6. Error Analysis
--   7. User Activity
--   8. Filters/Dropdowns
--   9. Advanced Analytics
--   10. Monitoring & Alerts
-- =============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA WALLMONITOR;

-- =============================================================================
-- 1. SETUP & MONITORING MANAGEMENT
-- =============================================================================

-- 1.1 Discover all agents in account and add to registry
-- CALL DISCOVER_AGENTS('%', NULL, TRUE);

-- 1.2 View registered agents
SELECT
    agent_database,
    agent_schema,
    agent_name,
    is_active,
    added_at,
    last_discovered,
    notes
FROM AGENT_REGISTRY
ORDER BY last_discovered DESC;

-- 1.3 Activate monitoring (creates serverless task)
-- CALL SETUP_MONITORING(24, 30);

-- 1.4 Check serverless task status
SHOW TASKS LIKE 'REFRESH_AGENT_EVENTS_TASK';

-- 1.5 Check task execution history
SELECT
    name,
    database_name,
    schema_name,
    scheduled_time,
    completed_time,
    state,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
WHERE name = 'REFRESH_AGENT_EVENTS_TASK'
ORDER BY scheduled_time DESC
LIMIT 20;

-- 1.6 Manual refresh (on-demand)
-- CALL REFRESH_AGENT_EVENTS(24, 30);

-- 1.7 Discover agents with filtering (example: only production agents)
-- CALL DISCOVER_AGENTS('%PROD%', '%TEST%', TRUE);

-- 1.8 Activate/deactivate specific agents
-- UPDATE AGENT_REGISTRY
-- SET is_active = FALSE
-- WHERE agent_name = 'test_agent';
-- After changing active agents, re-run: CALL SETUP_MONITORING(24, 30);

-- 1.9 Add agent manually
-- INSERT INTO AGENT_REGISTRY (agent_database, agent_schema, agent_name, is_active, notes)
-- VALUES ('MY_DB', 'MY_SCHEMA', 'MY_AGENT', TRUE, 'Manually added for monitoring');

-- 1.10 Pause monitoring
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;

-- 1.11 Resume monitoring
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;


-- =============================================================================
-- 2. REAL-TIME KPI CARDS - Dashboard Header
-- =============================================================================

-- 2.1 Main KPI Card (Last Hour)
SELECT
    active_threads,
    active_users,
    active_agents,
    total_events,
    llm_calls,
    total_tokens,
    avg_span_duration_ms,
    errors,
    error_rate_pct,
    threads_change_pct,
    llm_calls_change_pct,
    tokens_change_pct,
    latency_change_pct
FROM REALTIME_KPI;

-- 2.2 Current Active Threads (Live Activity)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_start_time,
    thread_last_activity,
    thread_duration_seconds,
    total_events,
    llm_calls,
    tool_calls,
    total_tokens,
    latest_status
FROM THREAD_ACTIVITY
WHERE thread_last_activity >= DATEADD('minute', -15, CURRENT_TIMESTAMP())
ORDER BY thread_last_activity DESC;

-- 2.3 Agent Health Summary
SELECT
    agent_full_name,
    unique_threads,
    llm_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 2) AS avg_latency_ms,
    error_rate_pct,
    CASE
        WHEN error_rate_pct > 10 THEN 'CRITICAL'
        WHEN error_rate_pct > 5 THEN 'WARNING'
        WHEN avg_span_duration_ms > 5000 THEN 'SLOW'
        ELSE 'HEALTHY'
    END AS health_status
FROM AGENT_METRICS
ORDER BY last_event DESC;


-- =============================================================================
-- 3. THREAD-FOCUSED QUERIES
-- =============================================================================

-- 3.1 Recent Threads (Main Thread List)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_start_time,
    thread_last_activity,
    thread_duration_seconds,
    total_events,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_tokens,
    ROUND(total_prompt_tokens, 0) AS prompt_tokens,
    ROUND(total_completion_tokens, 0) AS completion_tokens,
    error_count,
    latest_status,
    latest_model
FROM THREAD_ACTIVITY
ORDER BY thread_start_time DESC
LIMIT 50;

-- 3.2 Thread Details (Single Thread Drill-Down)
-- Replace :thread_id with parameter
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
WHERE thread_id = :thread_id  -- Parameter placeholder
ORDER BY event_timestamp;

-- 3.3 Thread Conversation Flow (For Visualization)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    event_timestamp,
    span_category,
    span_name,
    total_tokens,
    span_duration_ms,
    status
FROM AGENT_EVENTS
WHERE thread_id = :thread_id  -- Parameter placeholder
ORDER BY event_timestamp;

-- 3.4 Long-Running Threads (Performance Analysis)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_duration_seconds,
    total_events,
    llm_calls,
    total_tokens,
    ROUND(total_duration_ms / 1000.0, 2) AS total_duration_seconds,
    ROUND(avg_llm_latency_ms, 2) AS avg_llm_latency_ms,
    error_count
FROM THREAD_ACTIVITY
WHERE thread_duration_seconds > 60
ORDER BY thread_duration_seconds DESC
LIMIT 20;

-- 3.5 High-Token Threads (Cost Analysis)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_start_time,
    total_tokens,
    total_prompt_tokens,
    total_completion_tokens,
    llm_calls,
    ROUND(total_tokens / NULLIF(llm_calls, 0), 0) AS avg_tokens_per_llm_call
FROM THREAD_ACTIVITY
ORDER BY total_tokens DESC
LIMIT 20;

-- 3.6 Threads with Errors
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_start_time,
    thread_last_activity,
    error_count,
    success_count,
    total_events,
    ROUND(error_count * 100.0 / NULLIF(total_events, 0), 2) AS thread_error_rate_pct,
    latest_status
FROM THREAD_ACTIVITY
WHERE error_count > 0
ORDER BY error_count DESC, thread_last_activity DESC
LIMIT 50;


-- =============================================================================
-- 4. AGENT PERFORMANCE QUERIES
-- =============================================================================

-- 4.1 Agent Performance Comparison
SELECT
    agent_full_name,
    unique_threads,
    unique_users,
    llm_calls,
    tool_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 2) AS avg_latency_ms,
    ROUND(p50_span_duration_ms, 2) AS p50_latency_ms,
    ROUND(p95_span_duration_ms, 2) AS p95_latency_ms,
    error_rate_pct,
    most_used_model,
    active_days
FROM AGENT_METRICS
ORDER BY unique_threads DESC;

-- 4.2 Agent Activity Over Time (24h)
SELECT
    event_hour,
    agent_full_name,
    unique_threads,
    llm_calls,
    total_tokens,
    ROUND(avg_span_duration_ms, 2) AS avg_latency_ms,
    error_count
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
ORDER BY event_hour DESC, unique_threads DESC;

-- 4.3 Model Usage by Agent
SELECT
    agent_full_name,
    model_name,
    COUNT(*) AS events,
    COUNT(DISTINCT thread_id) AS threads,
    SUM(total_tokens) AS tokens,
    ROUND(AVG(span_duration_ms), 2) AS avg_latency_ms
FROM AGENT_EVENTS
WHERE model_name IS NOT NULL
GROUP BY agent_full_name, model_name
ORDER BY events DESC;

-- 4.4 Tool Usage Analysis
SELECT
    agent_full_name,
    tool_name,
    COUNT(*) AS tool_executions,
    COUNT(DISTINCT thread_id) AS threads_using_tool,
    ROUND(AVG(span_duration_ms), 2) AS avg_tool_latency_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY span_duration_ms), 2) AS p95_tool_latency_ms,
    COUNT(CASE WHEN status = 'error' THEN 1 END) AS tool_errors
FROM AGENT_EVENTS
WHERE span_category = 'TOOL_EXECUTION'
  AND tool_name IS NOT NULL
GROUP BY agent_full_name, tool_name
ORDER BY tool_executions DESC;


-- =============================================================================
-- 5. TIME-SERIES CHARTS
-- =============================================================================

-- 5.1 Hourly Thread Activity (Line Chart)
SELECT
    event_hour,
    SUM(unique_threads) AS total_threads,
    SUM(llm_calls) AS total_llm_calls,
    SUM(total_tokens) AS total_tokens,
    ROUND(AVG(avg_span_duration_ms), 2) AS avg_latency_ms
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY event_hour
ORDER BY event_hour;

-- 5.2 Thread Activity by Agent (Stacked Area Chart)
SELECT
    event_hour,
    agent_full_name,
    SUM(unique_threads) AS threads,
    SUM(llm_calls) AS llm_calls,
    SUM(total_tokens) AS tokens
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY event_hour, agent_full_name
ORDER BY event_hour, threads DESC;

-- 5.3 Token Usage Trend (Line Chart)
SELECT
    event_hour,
    SUM(total_tokens) AS total_tokens,
    SUM(total_prompt_tokens) AS prompt_tokens,
    SUM(total_completion_tokens) AS completion_tokens
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY event_hour
ORDER BY event_hour;

-- 5.4 Latency Percentiles (Multi-Line Chart)
SELECT
    event_hour,
    ROUND(AVG(avg_span_duration_ms), 2) AS avg_latency,
    ROUND(AVG(p95_span_duration_ms), 2) AS p95_latency
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY event_hour
ORDER BY event_hour;

-- 5.5 Error Rate Trend (Line Chart)
SELECT
    event_hour,
    SUM(error_count) AS errors,
    SUM(unique_threads) AS total_threads,
    ROUND(SUM(error_count) * 100.0 / NULLIF(SUM(unique_threads), 0), 2) AS error_rate_pct
FROM HOURLY_THREAD_ACTIVITY
WHERE event_hour >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
GROUP BY event_hour
ORDER BY event_hour;


-- =============================================================================
-- 6. ERROR ANALYSIS
-- =============================================================================

-- 6.1 Recent Errors
SELECT
    event_timestamp,
    agent_full_name,
    thread_id,
    user_id,
    span_name,
    span_category,
    model_name,
    tool_name,
    error_message,
    span_duration_ms
FROM AGENT_EVENTS
WHERE status = 'error' OR error_message IS NOT NULL
ORDER BY event_timestamp DESC
LIMIT 50;

-- 6.2 Error Frequency by Agent
SELECT
    agent_full_name,
    COUNT(*) AS error_count,
    COUNT(DISTINCT thread_id) AS threads_with_errors,
    COUNT(DISTINCT user_id) AS users_affected,
    MODE(error_message) AS most_common_error
FROM AGENT_EVENTS
WHERE status = 'error' OR error_message IS NOT NULL
GROUP BY agent_full_name
ORDER BY error_count DESC;

-- 6.3 Error Frequency by Span Type
SELECT
    span_category,
    span_name,
    COUNT(*) AS error_count,
    ROUND(AVG(span_duration_ms), 2) AS avg_duration_before_error_ms,
    MODE(error_message) AS most_common_error
FROM AGENT_EVENTS
WHERE status = 'error' OR error_message IS NOT NULL
GROUP BY span_category, span_name
ORDER BY error_count DESC;

-- 6.4 Tool Errors
SELECT
    agent_full_name,
    tool_name,
    COUNT(*) AS error_count,
    MODE(error_message) AS most_common_error,
    MAX(event_timestamp) AS last_error_time
FROM AGENT_EVENTS
WHERE span_category = 'TOOL_EXECUTION'
  AND (status = 'error' OR error_message IS NOT NULL)
GROUP BY agent_full_name, tool_name
ORDER BY error_count DESC;


-- =============================================================================
-- 7. USER ACTIVITY
-- =============================================================================

-- 7.1 User Activity Summary
SELECT
    user_id,
    COUNT(DISTINCT agent_full_name) AS agents_used,
    COUNT(DISTINCT thread_id) AS total_threads,
    SUM(total_events) AS total_events,
    SUM(llm_calls) AS llm_calls,
    SUM(total_tokens) AS total_tokens,
    MIN(thread_start_time) AS first_activity,
    MAX(thread_last_activity) AS last_activity,
    SUM(error_count) AS errors
FROM THREAD_ACTIVITY
WHERE user_id IS NOT NULL
GROUP BY user_id
ORDER BY total_threads DESC;

-- 7.2 Top Users by Activity (Last 24h)
SELECT
    user_id,
    COUNT(DISTINCT thread_id) AS threads,
    COUNT(DISTINCT agent_full_name) AS agents_used,
    SUM(total_tokens) AS tokens,
    MAX(thread_last_activity) AS last_active
FROM THREAD_ACTIVITY
WHERE thread_start_time >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND user_id IS NOT NULL
GROUP BY user_id
ORDER BY threads DESC
LIMIT 20;

-- 7.3 User Thread History
-- Replace :user_id with parameter
SELECT
    thread_id,
    agent_full_name,
    thread_start_time,
    thread_last_activity,
    thread_duration_seconds,
    llm_calls,
    tool_calls,
    total_tokens,
    error_count,
    latest_status
FROM THREAD_ACTIVITY
WHERE user_id = :user_id
ORDER BY thread_start_time DESC;


-- =============================================================================
-- 8. FILTERS/DROPDOWNS - Distinct values for UI
-- =============================================================================

-- 8.1 Available Agents
SELECT DISTINCT agent_full_name
FROM AGENT_EVENTS
ORDER BY agent_full_name;

-- 8.2 Available Users
SELECT DISTINCT user_id
FROM AGENT_EVENTS
WHERE user_id IS NOT NULL
ORDER BY user_id;

-- 8.3 Available Models
SELECT DISTINCT model_name
FROM AGENT_EVENTS
WHERE model_name IS NOT NULL
ORDER BY model_name;

-- 8.4 Available Tools
SELECT DISTINCT tool_name
FROM AGENT_EVENTS
WHERE tool_name IS NOT NULL
ORDER BY tool_name;

-- 8.5 Active Time Range
SELECT
    MIN(event_timestamp) AS earliest_event,
    MAX(event_timestamp) AS latest_event,
    DATEDIFF('hour', MIN(event_timestamp), MAX(event_timestamp)) AS hours_of_data
FROM AGENT_EVENTS;


-- =============================================================================
-- 9. ADVANCED ANALYTICS
-- =============================================================================

-- 9.1 Thread Complexity Analysis
SELECT
    CASE
        WHEN llm_calls = 0 THEN 'No LLM'
        WHEN llm_calls = 1 THEN 'Simple (1 LLM call)'
        WHEN llm_calls BETWEEN 2 AND 5 THEN 'Moderate (2-5 LLM calls)'
        WHEN llm_calls > 5 THEN 'Complex (5+ LLM calls)'
    END AS complexity_category,
    COUNT(*) AS thread_count,
    ROUND(AVG(total_tokens), 0) AS avg_tokens,
    ROUND(AVG(thread_duration_seconds), 2) AS avg_duration_seconds,
    ROUND(AVG(tool_calls), 1) AS avg_tool_calls
FROM THREAD_ACTIVITY
GROUP BY complexity_category
ORDER BY
    CASE complexity_category
        WHEN 'No LLM' THEN 1
        WHEN 'Simple (1 LLM call)' THEN 2
        WHEN 'Moderate (2-5 LLM calls)' THEN 3
        WHEN 'Complex (5+ LLM calls)' THEN 4
    END;

-- 9.2 Retrieval Effectiveness
SELECT
    agent_full_name,
    COUNT(*) AS retrieval_calls,
    COUNT(DISTINCT thread_id) AS threads_with_retrieval,
    ROUND(AVG(span_duration_ms), 2) AS avg_retrieval_latency_ms,
    COUNT(CASE WHEN status = 'error' THEN 1 END) AS retrieval_errors
FROM AGENT_EVENTS
WHERE span_category = 'RETRIEVAL'
GROUP BY agent_full_name
ORDER BY retrieval_calls DESC;

-- 9.3 Token Efficiency by Agent
SELECT
    agent_full_name,
    COUNT(DISTINCT thread_id) AS threads,
    SUM(llm_calls) AS llm_calls,
    SUM(total_tokens) AS total_tokens,
    ROUND(SUM(total_tokens) / NULLIF(SUM(llm_calls), 0), 0) AS avg_tokens_per_llm_call,
    ROUND(SUM(total_prompt_tokens) * 100.0 / NULLIF(SUM(total_tokens), 0), 1) AS prompt_token_pct
FROM THREAD_ACTIVITY
GROUP BY agent_full_name
ORDER BY total_tokens DESC;

-- 9.4 Thread Success Rate by Agent
SELECT
    agent_full_name,
    COUNT(*) AS total_threads,
    COUNT(CASE WHEN error_count = 0 THEN 1 END) AS successful_threads,
    COUNT(CASE WHEN error_count > 0 THEN 1 END) AS failed_threads,
    ROUND(COUNT(CASE WHEN error_count = 0 THEN 1 END) * 100.0 / COUNT(*), 2) AS success_rate_pct
FROM THREAD_ACTIVITY
GROUP BY agent_full_name
ORDER BY success_rate_pct ASC;


-- =============================================================================
-- 10. MONITORING & ALERTS
-- =============================================================================

-- 10.1 Slow Threads Alert (>30 seconds)
SELECT
    thread_id,
    agent_full_name,
    user_id,
    thread_duration_seconds,
    llm_calls,
    tool_calls,
    ROUND(avg_llm_latency_ms, 2) AS avg_llm_latency_ms,
    thread_last_activity
FROM THREAD_ACTIVITY
WHERE thread_duration_seconds > 30
  AND thread_last_activity >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY thread_duration_seconds DESC;

-- 10.2 High Error Rate Alert (>10% errors)
SELECT
    agent_full_name,
    COUNT(*) AS recent_threads,
    SUM(error_count) AS total_errors,
    ROUND(SUM(error_count) * 100.0 / NULLIF(COUNT(*), 0), 2) AS error_rate_pct
FROM THREAD_ACTIVITY
WHERE thread_start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
GROUP BY agent_full_name
HAVING error_rate_pct > 10
ORDER BY error_rate_pct DESC;

-- 10.3 No Activity Alert (agents with no threads in last hour)
SELECT
    r.agent_database,
    r.agent_schema,
    r.agent_name,
    r.agent_database || '.' || r.agent_schema || '.' || r.agent_name AS agent_full_name,
    r.last_discovered
FROM AGENT_REGISTRY r
WHERE r.is_active = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM AGENT_EVENTS e
      WHERE e.agent_full_name = r.agent_database || '.' || r.agent_schema || '.' || r.agent_name
        AND e.event_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
  );

-- 10.4 High Token Usage Alert (>100k tokens in last hour)
SELECT
    agent_full_name,
    SUM(total_tokens) AS total_tokens_last_hour,
    COUNT(DISTINCT thread_id) AS thread_count
FROM THREAD_ACTIVITY
WHERE thread_start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
GROUP BY agent_full_name
HAVING total_tokens_last_hour > 100000
ORDER BY total_tokens_last_hour DESC;

-- =============================================================================
-- 11. RECENT HISTORY (7-30D) - Uses *_RECENT views backed by dynamic tables
-- =============================================================================

-- 11.1 Recent threads (last 7 days)
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
FROM THREAD_ACTIVITY_RECENT
WHERE thread_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY thread_start_time DESC
LIMIT 100;

-- 11.2 Agent performance (last 30 days)
SELECT
    agent_full_name,
    unique_threads,
    unique_users,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_tokens,
    avg_span_duration_ms,
    p95_span_duration_ms,
    error_rate_pct,
    most_used_model,
    last_event
FROM AGENT_METRICS_RECENT
WHERE last_event >= DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY unique_threads DESC;

-- 11.3 Hourly trend (last 30 days, all agents)
SELECT
    event_hour,
    SUM(unique_threads) AS total_threads,
    SUM(llm_calls) AS total_llm_calls,
    SUM(total_tokens) AS total_tokens,
    ROUND(AVG(avg_span_duration_ms), 2) AS avg_latency_ms,
    SUM(error_count) AS errors
FROM HOURLY_THREAD_ACTIVITY_RECENT
WHERE event_hour >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY event_hour
ORDER BY event_hour;

-- 11.4 Thread timeline (use for drill-down over 7-30d)
-- Replace :thread_id with parameter
SELECT
    event_timestamp,
    event_sequence,
    seconds_since_thread_start,
    span_name,
    span_category,
    model_name,
    total_tokens,
    span_duration_ms,
    tool_name,
    status,
    error_message
FROM THREAD_TIMELINE_RECENT
WHERE thread_id = :thread_id
ORDER BY event_timestamp;

-- =============================================================================
-- 12. OPTIONAL: USAGE ANALYTICS (AI_OBSERVABILITY_EVENTS)
-- =============================================================================
-- Requires AI Observability lookup privileges. If available, enable:
-- CALL SETUP_USAGE_ANALYTICS(30);

-- 12.1 Requests by user (last N days, based on setup)
SELECT
    agent_database,
    agent_schema,
    agent_name,
    user_name,
    total_requests,
    unique_threads,
    avg_response_duration_ms,
    first_access_time,
    last_access_time
FROM AGENT_USAGE_BY_USER
ORDER BY total_requests DESC
LIMIT 200;

-- 12.2 Requests by agent (summary)
SELECT
    agent_full_name,
    total_requests,
    unique_users,
    unique_threads,
    avg_response_duration_ms,
    first_access_time,
    last_access_time
FROM AGENT_USAGE_BY_AGENT
ORDER BY total_requests DESC;
