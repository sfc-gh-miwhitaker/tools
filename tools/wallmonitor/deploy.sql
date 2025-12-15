-- =============================================================================
-- WALLMONITOR: Agent-Focused Cortex AI Monitoring Platform
-- =============================================================================
-- Purpose: Real-time monitoring for Cortex Agent runs and threads across
--          all agents in the account with near real-time observability
-- Target: SNOWFLAKE_EXAMPLE.WALLMONITOR schema
-- Author: SE Community
-- Expires: 2026-01-10
--
-- Architecture:
--   1. AGENT_REGISTRY - Table tracking agents to monitor (auto-discovery)
--   2. DISCOVER_AGENTS() - Procedure to auto-populate registry
--   3. Dynamic Table (AGENT_EVENTS_SOURCE) - Auto-refreshing events (5 min lag)
--   4. Dashboard views - Thread-focused aggregations
--
-- Data Sources:
--   - SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS() (near real-time)
--   - SHOW AGENTS (agent enumeration)
-- =============================================================================

-- =============================================================================
-- EXPIRATION CHECK (MANDATORY)
-- =============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-01-10';
    tool_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-01-10. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE tool_expired;
    END IF;
END;
$$;

-- Grant serverless task privilege (required for ACCOUNTADMIN)
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;

USE DATABASE SNOWFLAKE_EXAMPLE;

-- -----------------------------------------------------------------------------
-- SCHEMA SETUP
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS WALLMONITOR
    COMMENT = 'DEMO: Wallmonitor - Agent-focused Cortex AI monitoring with real-time observability | Expires: 2026-01-10';

USE SCHEMA WALLMONITOR;

-- -----------------------------------------------------------------------------
-- TABLE: AGENT_REGISTRY
-- Tracks which agents should be monitored
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AGENT_REGISTRY (
    agent_database STRING NOT NULL,
    agent_schema STRING NOT NULL,
    agent_name STRING NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    include_pattern STRING DEFAULT '%',
    exclude_pattern STRING DEFAULT NULL,
    added_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    last_discovered TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    notes STRING,
    PRIMARY KEY (agent_database, agent_schema, agent_name)
)
COMMENT = 'DEMO: Registry of Cortex Agents to monitor. Auto-populated by DISCOVER_AGENTS() procedure. | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- PROCEDURE: DISCOVER_AGENTS
-- Auto-discovers Cortex Agents in the account and populates registry
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DISCOVER_AGENTS(
    INCLUDE_PATTERN STRING DEFAULT '%',
    EXCLUDE_PATTERN STRING DEFAULT NULL,
    AUTO_ACTIVATE BOOLEAN DEFAULT TRUE
)
RETURNS STRING
LANGUAGE JAVASCRIPT
COMMENT = 'DEMO: Discovers Cortex Agents and adds them to AGENT_REGISTRY. Use include/exclude patterns to filter. | Expires: 2026-01-10'
AS
$$
    // Query to find all agents in the account
    var discover_sql = `
        SELECT 
            "database_name" AS agent_database,
            "schema_name" AS agent_schema, 
            "name" AS agent_name
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    `;
    
    // Execute SHOW to get all agents (correct command for Cortex Agents)
    try {
        snowflake.execute({sqlText: "SHOW AGENTS IN ACCOUNT"});
    } catch(err) {
        // If SHOW fails, try organization level (may require elevated privileges)
        try {
            snowflake.execute({sqlText: "SHOW AGENTS IN ORGANIZATION"});
        } catch(org_err) {
            return "ERROR: Unable to enumerate agents. Ensure you have proper privileges.";
        }
    }
    
    // Get results
    var agents_rs = snowflake.execute({sqlText: discover_sql});
    var discovered_count = 0;
    var added_count = 0;
    var updated_count = 0;
    
    // Process each discovered agent
    while (agents_rs.next()) {
        discovered_count++;
        var db = agents_rs.getColumnValue('AGENT_DATABASE');
        var schema = agents_rs.getColumnValue('AGENT_SCHEMA');
        var name = agents_rs.getColumnValue('AGENT_NAME');
        var full_name = db + '.' + schema + '.' + name;
        
        // Check include/exclude patterns
        if (INCLUDE_PATTERN && INCLUDE_PATTERN !== '%') {
            if (!full_name.match(new RegExp(INCLUDE_PATTERN.replace('%', '.*'), 'i'))) {
                continue;
            }
        }
        
        if (EXCLUDE_PATTERN) {
            if (full_name.match(new RegExp(EXCLUDE_PATTERN.replace('%', '.*'), 'i'))) {
                continue;
            }
        }
        
        // Merge into registry
        var merge_sql = `
            MERGE INTO AGENT_REGISTRY AS target
            USING (SELECT 
                '${db}' AS agent_database,
                '${schema}' AS agent_schema,
                '${name}' AS agent_name
            ) AS source
            ON target.agent_database = source.agent_database
               AND target.agent_schema = source.agent_schema
               AND target.agent_name = source.agent_name
            WHEN MATCHED THEN 
                UPDATE SET last_discovered = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN
                INSERT (agent_database, agent_schema, agent_name, is_active, include_pattern, exclude_pattern)
                VALUES (source.agent_database, source.agent_schema, source.agent_name, 
                        ${AUTO_ACTIVATE}, '${INCLUDE_PATTERN}', 
                        ${EXCLUDE_PATTERN ? "'" + EXCLUDE_PATTERN + "'" : 'NULL'})
        `;
        
        var merge_rs = snowflake.execute({sqlText: merge_sql});
        merge_rs.next();
        var rows_affected = merge_rs.getColumnValue(1);
        
        if (rows_affected > 0) {
            added_count++;
        } else {
            updated_count++;
        }
    }
    
    return `Discovery complete. Found: ${discovered_count}, Added: ${added_count}, Updated: ${updated_count}`;
$$;

-- -----------------------------------------------------------------------------
-- TABLE: AGENT_EVENTS_SNAPSHOT
-- Snapshot table populated by scheduled task every 10 minutes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AGENT_EVENTS_SNAPSHOT (
    agent_database STRING,
    agent_schema STRING,
    agent_name STRING,
    event_timestamp TIMESTAMP_LTZ,
    event_name STRING,
    span_name STRING,
    span_id STRING,
    trace_id STRING,
    agent_id STRING,
    thread_id STRING,
    user_id STRING,
    model_name STRING,
    prompt_tokens NUMBER,
    completion_tokens NUMBER,
    total_tokens NUMBER,
    span_duration_ms NUMBER,
    tool_name STRING,
    retrieval_query STRING,
    status STRING,
    error_message STRING,
    raw_attributes VARIANT,
    loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Snapshot of agent events, refreshed every 10 minutes by serverless task | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- PROCEDURE: REFRESH_AGENT_EVENTS
-- Populates AGENT_EVENTS_SNAPSHOT with events from all active agents
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REFRESH_AGENT_EVENTS(LOOKBACK_HOURS FLOAT DEFAULT 24)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: Refreshes AGENT_EVENTS_SNAPSHOT table with latest events from all active agents | Expires: 2026-01-10'
AS
$$
DECLARE
    agent_cursor CURSOR FOR SELECT agent_database, agent_schema, agent_name FROM AGENT_REGISTRY WHERE is_active = TRUE;
    db STRING;
    schema_name STRING;
    agent STRING;
    sql_stmt STRING;
    event_count INTEGER DEFAULT 0;
    agent_count INTEGER DEFAULT 0;
BEGIN
    -- Truncate snapshot table
    TRUNCATE TABLE AGENT_EVENTS_SNAPSHOT;
    
    -- Loop through active agents
    FOR agent_record IN agent_cursor DO
        db := agent_record.agent_database;
        schema_name := agent_record.agent_schema;
        agent := agent_record.agent_name;
        agent_count := agent_count + 1;
        
        -- Build dynamic SQL for this agent
        sql_stmt := '
            INSERT INTO AGENT_EVENTS_SNAPSHOT
            SELECT 
                ''' || db || ''' AS agent_database,
                ''' || schema_name || ''' AS agent_schema,
                ''' || agent || ''' AS agent_name,
                record:timestamp::TIMESTAMP_LTZ AS event_timestamp,
                record:name::STRING AS event_name,
                record:span_name::STRING AS span_name,
                record:span_id::STRING AS span_id,
                record:trace_id::STRING AS trace_id,
                record:attributes:agent_id::STRING AS agent_id,
                record:attributes:thread_id::STRING AS thread_id,
                record:attributes:user_id::STRING AS user_id,
                record:attributes:model_name::STRING AS model_name,
                record:attributes:prompt_tokens::NUMBER AS prompt_tokens,
                record:attributes:completion_tokens::NUMBER AS completion_tokens,
                record:attributes:total_tokens::NUMBER AS total_tokens,
                record:attributes:duration_ms::NUMBER AS span_duration_ms,
                record:attributes:tool_name::STRING AS tool_name,
                record:attributes:retrieval_query::STRING AS retrieval_query,
                record:attributes:status::STRING AS status,
                record:attributes:error_message::STRING AS error_message,
                record:attributes AS raw_attributes,
                CURRENT_TIMESTAMP() AS loaded_at
            FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
                ''' || db || ''', ''' || schema_name || ''', ''' || agent || ''', ''CORTEX AGENT''
            ))
            WHERE record:timestamp >= DATEADD(''hour'', -' || LOOKBACK_HOURS || ', CURRENT_TIMESTAMP())
        ';
        
        -- Execute with error handling
        BEGIN
            EXECUTE IMMEDIATE :sql_stmt;
            LET rows_inserted INTEGER := SQLROWCOUNT;
            event_count := event_count + rows_inserted;
        EXCEPTION
            WHEN OTHER THEN
                -- Skip agents that fail (permissions, not found, etc.)
                CONTINUE;
        END;
    END FOR;
    
    RETURN 'Loaded ' || event_count || ' events from ' || agent_count || ' agents';
END;
$$;

-- -----------------------------------------------------------------------------
-- PROCEDURE: SETUP_MONITORING
-- One-step setup: Creates serverless task to refresh events every 10 minutes
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS SETUP_MONITORING(FLOAT, STRING, STRING);

CREATE OR REPLACE PROCEDURE SETUP_MONITORING(LOOKBACK_HOURS FLOAT DEFAULT 24)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- Drop existing task if it exists
    DROP TASK IF EXISTS REFRESH_AGENT_EVENTS_TASK;
    
    -- Create serverless task (runs every 10 minutes)
    CREATE TASK REFRESH_AGENT_EVENTS_TASK
        SCHEDULE = '10 minute'
        USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
        COMMENT = 'DEMO: Auto-refresh agent events every 10 minutes (serverless) | Expires: 2026-01-10'
    AS
        CALL REFRESH_AGENT_EVENTS(:LOOKBACK_HOURS);
    
    -- Do initial refresh
    CALL REFRESH_AGENT_EVENTS(:LOOKBACK_HOURS);
    
    -- Resume task
    ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;
    
    RETURN '✅ Monitoring active: Serverless task refreshing every 10 minutes (last ' || LOOKBACK_HOURS || 'h)';
END;
$$;

-- -----------------------------------------------------------------------------
-- VIEW: AGENT_EVENTS
-- Raw unified events from all monitored agents (reads from dynamic table)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW AGENT_EVENTS AS
SELECT 
    agent_database,
    agent_schema,
    agent_name,
    agent_database || '.' || agent_schema || '.' || agent_name AS agent_full_name,
    event_timestamp,
    event_name,
    span_name,
    span_id,
    trace_id,
    agent_id,
    thread_id,
    user_id,
    model_name,
    prompt_tokens,
    completion_tokens,
    total_tokens,
    span_duration_ms,
    tool_name,
    retrieval_query,
    status,
    error_message,
    raw_attributes,
    
    -- Derived fields
    DATE_TRUNC('hour', event_timestamp) AS event_hour,
    DATE_TRUNC('day', event_timestamp) AS event_date,
    CASE 
        WHEN span_name LIKE '%LLM%' OR span_name LIKE '%COMPLETION%' THEN 'LLM_CALL'
        WHEN span_name LIKE '%TOOL%' THEN 'TOOL_EXECUTION'
        WHEN span_name LIKE '%RETRIEVAL%' OR span_name LIKE '%SEARCH%' THEN 'RETRIEVAL'
        WHEN span_name LIKE '%AGENT%' THEN 'AGENT_RUN'
        ELSE 'OTHER'
    END AS span_category
    
FROM AGENT_EVENTS_SNAPSHOT;

COMMENT ON VIEW AGENT_EVENTS IS 'DEMO: Unified agent events (auto-refreshed every 10 minutes via serverless task) | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- VIEW: THREAD_ACTIVITY
-- Thread-level aggregations showing conversation flows
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW THREAD_ACTIVITY AS
SELECT 
    agent_full_name,
    thread_id,
    user_id,
    
    -- Temporal boundaries
    MIN(event_timestamp) AS thread_start_time,
    MAX(event_timestamp) AS thread_last_activity,
    DATEDIFF('second', MIN(event_timestamp), MAX(event_timestamp)) AS thread_duration_seconds,
    
    -- Activity counts
    COUNT(*) AS total_events,
    COUNT(DISTINCT span_id) AS total_spans,
    COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'RETRIEVAL' THEN span_id END) AS retrieval_calls,
    
    -- Token usage
    SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
    SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
    SUM(COALESCE(total_tokens, 0)) AS total_tokens,
    
    -- Performance
    SUM(COALESCE(span_duration_ms, 0)) AS total_duration_ms,
    AVG(CASE WHEN span_category = 'LLM_CALL' THEN span_duration_ms END) AS avg_llm_latency_ms,
    AVG(CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_duration_ms END) AS avg_tool_latency_ms,
    
    -- Quality
    COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count,
    COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count,
    
    -- Latest state
    MAX_BY(status, event_timestamp) AS latest_status,
    MAX_BY(model_name, event_timestamp) AS latest_model

FROM AGENT_EVENTS
WHERE thread_id IS NOT NULL
GROUP BY agent_full_name, thread_id, user_id;

COMMENT ON VIEW THREAD_ACTIVITY IS 'DEMO: Thread-level aggregations showing conversation flows, tokens, and performance | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- VIEW: AGENT_METRICS
-- Per-agent performance and usage metrics
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW AGENT_METRICS AS
SELECT 
    agent_full_name,
    agent_database,
    agent_schema,
    agent_name,
    
    -- Volume metrics
    COUNT(DISTINCT thread_id) AS unique_threads,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(*) AS total_events,
    COUNT(DISTINCT span_id) AS total_spans,
    
    -- Span breakdown
    COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'RETRIEVAL' THEN span_id END) AS retrieval_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'AGENT_RUN' THEN span_id END) AS agent_runs,
    
    -- Token metrics
    SUM(COALESCE(total_tokens, 0)) AS total_tokens,
    SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
    SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
    AVG(COALESCE(total_tokens, 0)) AS avg_tokens_per_event,
    
    -- Performance metrics
    AVG(span_duration_ms) AS avg_span_duration_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY span_duration_ms) AS p50_span_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY span_duration_ms) AS p95_span_duration_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY span_duration_ms) AS p99_span_duration_ms,
    
    -- Model distribution
    COUNT(DISTINCT model_name) AS models_used,
    MODE(model_name) AS most_used_model,
    
    -- Error metrics
    COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count,
    COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count,
    ROUND(
        COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) * 100.0 
        / NULLIF(COUNT(*), 0), 
        2
    ) AS error_rate_pct,
    
    -- Temporal
    MIN(event_timestamp) AS first_event,
    MAX(event_timestamp) AS last_event,
    COUNT(DISTINCT event_date) AS active_days

FROM AGENT_EVENTS
GROUP BY agent_full_name, agent_database, agent_schema, agent_name;

COMMENT ON VIEW AGENT_METRICS IS 'DEMO: Per-agent performance metrics, token usage, and error rates | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- VIEW: REALTIME_KPI
-- Real-time KPIs for dashboard header
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW REALTIME_KPI AS
WITH current_period AS (
    SELECT 
        COUNT(DISTINCT thread_id) AS active_threads,
        COUNT(DISTINCT user_id) AS active_users,
        COUNT(DISTINCT agent_full_name) AS active_agents,
        COUNT(*) AS total_events,
        COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
        SUM(COALESCE(total_tokens, 0)) AS total_tokens,
        AVG(span_duration_ms) AS avg_span_duration_ms,
        COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS errors
    FROM AGENT_EVENTS
    WHERE event_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
),

previous_period AS (
    SELECT 
        COUNT(DISTINCT thread_id) AS active_threads,
        COUNT(DISTINCT user_id) AS active_users,
        COUNT(DISTINCT agent_full_name) AS active_agents,
        COUNT(*) AS total_events,
        COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
        SUM(COALESCE(total_tokens, 0)) AS total_tokens,
        AVG(span_duration_ms) AS avg_span_duration_ms,
        COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS errors
    FROM AGENT_EVENTS
    WHERE event_timestamp >= DATEADD('hour', -2, CURRENT_TIMESTAMP())
      AND event_timestamp < DATEADD('hour', -1, CURRENT_TIMESTAMP())
)

SELECT 
    'last_1h' AS period,
    c.active_threads,
    c.active_users,
    c.active_agents,
    c.total_events,
    c.llm_calls,
    c.total_tokens,
    ROUND(c.avg_span_duration_ms, 2) AS avg_span_duration_ms,
    c.errors,
    ROUND(c.errors * 100.0 / NULLIF(c.total_events, 0), 2) AS error_rate_pct,
    
    -- Period over period changes
    ROUND((c.active_threads - p.active_threads) * 100.0 / NULLIF(p.active_threads, 0), 2) AS threads_change_pct,
    ROUND((c.llm_calls - p.llm_calls) * 100.0 / NULLIF(p.llm_calls, 0), 2) AS llm_calls_change_pct,
    ROUND((c.total_tokens - p.total_tokens) * 100.0 / NULLIF(p.total_tokens, 0), 2) AS tokens_change_pct,
    ROUND((c.avg_span_duration_ms - p.avg_span_duration_ms) * 100.0 / NULLIF(p.avg_span_duration_ms, 0), 2) AS latency_change_pct
    
FROM current_period c, previous_period p;

COMMENT ON VIEW REALTIME_KPI IS 'DEMO: Real-time KPIs for last hour with hour-over-hour comparison | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- VIEW: HOURLY_THREAD_ACTIVITY
-- Hourly thread activity for time-series charts
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW HOURLY_THREAD_ACTIVITY AS
SELECT 
    event_hour,
    agent_full_name,
    
    COUNT(DISTINCT thread_id) AS unique_threads,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(*) AS total_events,
    COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
    
    SUM(COALESCE(total_tokens, 0)) AS total_tokens,
    SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
    SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
    
    AVG(span_duration_ms) AS avg_span_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY span_duration_ms) AS p95_span_duration_ms,
    
    COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count

FROM AGENT_EVENTS
GROUP BY event_hour, agent_full_name;

COMMENT ON VIEW HOURLY_THREAD_ACTIVITY IS 'DEMO: Hourly aggregations for time-series dashboard charts | Expires: 2026-01-10';

-- -----------------------------------------------------------------------------
-- VIEW: THREAD_TIMELINE
-- Detailed timeline of events within a thread (for drill-down)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW THREAD_TIMELINE AS
SELECT 
    thread_id,
    agent_full_name,
    event_timestamp,
    span_name,
    span_category,
    span_id,
    trace_id,
    model_name,
    total_tokens,
    prompt_tokens,
    completion_tokens,
    span_duration_ms,
    tool_name,
    retrieval_query,
    status,
    error_message,
    
    -- Sequence within thread
    ROW_NUMBER() OVER (PARTITION BY thread_id ORDER BY event_timestamp) AS event_sequence,
    
    -- Time since thread start
    DATEDIFF('second', 
        FIRST_VALUE(event_timestamp) OVER (PARTITION BY thread_id ORDER BY event_timestamp),
        event_timestamp
    ) AS seconds_since_thread_start

FROM AGENT_EVENTS
WHERE thread_id IS NOT NULL;

COMMENT ON VIEW THREAD_TIMELINE IS 'DEMO: Chronological event timeline within each thread for detailed drill-down (use ORDER BY in queries) | Expires: 2026-01-10';

-- =============================================================================
-- QUICK START (Auto-Setup)
-- =============================================================================
-- These commands run automatically during deployment

-- Step 1: Discover agents in your account
CALL DISCOVER_AGENTS('%', NULL, TRUE);

-- Step 2: Activate monitoring (creates serverless task that runs every 10 minutes)
CALL SETUP_MONITORING(24);

-- =============================================================================
-- CUSTOMIZATION
-- =============================================================================

-- Pause monitoring (stops serverless task)
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;

-- Resume monitoring
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;

-- Manual refresh (on-demand)
-- CALL REFRESH_AGENT_EVENTS(24);

-- Add more agents (re-run setup after discovering new agents)
-- CALL DISCOVER_AGENTS('%NEW_PATTERN%', NULL, TRUE);
-- CALL SETUP_MONITORING(24);

-- -----------------------------------------------------------------------------
-- GRANTS (adjust as needed)
-- -----------------------------------------------------------------------------
-- GRANT USAGE ON SCHEMA WALLMONITOR TO ROLE <dashboard_role>;
-- GRANT SELECT ON ALL VIEWS IN SCHEMA WALLMONITOR TO ROLE <dashboard_role>;
-- GRANT SELECT ON ALL TABLES IN SCHEMA WALLMONITOR TO ROLE <dashboard_role>;
-- GRANT USAGE ON ALL FUNCTIONS IN SCHEMA WALLMONITOR TO ROLE <dashboard_role>;
-- GRANT USAGE ON ALL PROCEDURES IN SCHEMA WALLMONITOR TO ROLE <dashboard_role>;

-- -----------------------------------------------------------------------------
-- DEPLOYMENT SUMMARY
-- -----------------------------------------------------------------------------
SELECT 
    '========================================' AS message
UNION ALL SELECT '✅ WALLMONITOR DEPLOYED & ACTIVE'
UNION ALL SELECT '========================================'
UNION ALL SELECT ''
UNION ALL SELECT 'Monitoring: ' || 
    COALESCE((SELECT COUNT(DISTINCT agent_full_name)::STRING FROM AGENT_EVENTS), '0') || 
    ' agents'
UNION ALL SELECT 'Active Threads (last 1h): ' || 
    COALESCE((SELECT active_threads::STRING FROM REALTIME_KPI), '0')
UNION ALL SELECT 'Tokens Used (last 1h): ' || 
    COALESCE((SELECT TO_VARCHAR(total_tokens, '999,999,999') FROM REALTIME_KPI), '0')
UNION ALL SELECT 'Avg Latency: ' || 
    COALESCE((SELECT ROUND(avg_span_duration_ms)::STRING || 'ms' FROM REALTIME_KPI), 'N/A')
UNION ALL SELECT ''
UNION ALL SELECT 'Dashboard Views Ready:'
UNION ALL SELECT '  • REALTIME_KPI'
UNION ALL SELECT '  • THREAD_ACTIVITY'
UNION ALL SELECT '  • AGENT_METRICS'
UNION ALL SELECT ''
UNION ALL SELECT 'Data refreshes every 10 minutes (serverless)'
UNION ALL SELECT 'See example_queries.sql for dashboard queries';

