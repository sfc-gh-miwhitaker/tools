-- =============================================================================
-- WALLMONITOR: Agent-Focused Cortex AI Monitoring Platform
-- =============================================================================
-- Purpose: Real-time monitoring for Cortex Agent runs and threads across
--          all agents in the account with near real-time observability
-- Target: SNOWFLAKE_EXAMPLE.WALLMONITOR schema
-- Author: SE Community
-- Created: 2026-01-07
-- Expires: 2026-02-06
--
-- Architecture:
--   1. AGENT_REGISTRY - Table tracking agents to monitor (auto-discovery)
--   2. DISCOVER_AGENTS() - Procedure to auto-populate registry
--   3. REFRESH_AGENT_EVENTS() - Serverless ingestion into snapshot + history
--   4. Dynamic tables - 7-30d aggregations for fast dashboards
--   5. Dashboard views - 1h/24h realtime + recent history rollups
--   6. Streamlit app - Native dashboard in Snowsight
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
    v_expiration_date DATE := '2026-02-06';
    tool_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-02-06. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE tool_expired;
    END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- CONTEXT (MANDATORY)
-- -----------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

-- -------------------------------------------------------------------------
-- BEST-PRACTICE RBAC (deployer/owner vs viewer)
-- -------------------------------------------------------------------------
-- NOTE: This script still uses ACCOUNTADMIN for bootstrap and grants.
-- Objects are owned by SFE_WALLMONITOR_OWNER for least-privilege operations.

CREATE ROLE IF NOT EXISTS SFE_WALLMONITOR_OWNER;
CREATE ROLE IF NOT EXISTS SFE_WALLMONITOR_VIEWER;

-- Required for managed (serverless) task creation
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE SFE_WALLMONITOR_OWNER;

-- Required to access GET_AI_OBSERVABILITY_EVENTS()
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE SFE_WALLMONITOR_OWNER;

-- Optional: enable direct queries against SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
-- (requires an application role; not always available in all accounts/roles).
EXECUTE IMMEDIATE
$$
BEGIN
    GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP TO ROLE SFE_WALLMONITOR_OWNER;
EXCEPTION
    WHEN OTHER THEN
        -- Ignore if the application role is not available or cannot be granted.
        NULL;
END;
$$;

-- Dedicated warehouse for this tool (dynamic tables + Streamlit query warehouse)
CREATE WAREHOUSE IF NOT EXISTS SFE_WALLMONITOR_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'DEMO: Wallmonitor warehouse | Author: SE Community | Expires: 2026-02-06';

GRANT USAGE ON WAREHOUSE SFE_WALLMONITOR_WH TO ROLE SFE_WALLMONITOR_OWNER;
GRANT USAGE ON WAREHOUSE SFE_WALLMONITOR_WH TO ROLE SFE_WALLMONITOR_VIEWER;

USE WAREHOUSE SFE_WALLMONITOR_WH;

USE DATABASE SNOWFLAKE_EXAMPLE;

-- -----------------------------------------------------------------------------
-- SCHEMA SETUP
-- -----------------------------------------------------------------------------
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SFE_WALLMONITOR_OWNER;
GRANT CREATE SCHEMA ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SFE_WALLMONITOR_OWNER;

USE ROLE SFE_WALLMONITOR_OWNER;
USE WAREHOUSE SFE_WALLMONITOR_WH;
USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS WALLMONITOR
    COMMENT = 'DEMO: Wallmonitor - Agent-focused Cortex AI monitoring with real-time observability | Expires: 2026-02-06';

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
COMMENT = 'DEMO: Registry of Cortex Agents to monitor. Auto-populated by DISCOVER_AGENTS() procedure. | Expires: 2026-02-06';

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
LANGUAGE SQL
EXECUTE AS CALLER
COMMENT = 'DEMO: Discovers Cortex Agents and adds them to AGENT_REGISTRY. Use include/exclude patterns to filter. | Expires: 2026-02-06'
AS
$$
DECLARE
    discovered_count INTEGER DEFAULT 0;
    added_count INTEGER DEFAULT 0;
    updated_count INTEGER DEFAULT 0;
BEGIN
    EXECUTE IMMEDIATE 'SHOW AGENTS IN ACCOUNT';

    CREATE OR REPLACE TEMP TABLE TMP_DISCOVER_AGENTS AS
    SELECT
        "database_name"::STRING AS agent_database,
        "schema_name"::STRING AS agent_schema,
        "name"::STRING AS agent_name,
        ("database_name"::STRING || '.' || "schema_name"::STRING || '.' || "name"::STRING) AS agent_full_name
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    WHERE (:INCLUDE_PATTERN IS NULL OR agent_full_name ILIKE :INCLUDE_PATTERN)
      AND (:EXCLUDE_PATTERN IS NULL OR agent_full_name NOT ILIKE :EXCLUDE_PATTERN);

    SELECT COUNT(*) INTO :discovered_count
    FROM TMP_DISCOVER_AGENTS;

    SELECT COUNT(*) INTO :added_count
    FROM TMP_DISCOVER_AGENTS s
    LEFT JOIN AGENT_REGISTRY t
      ON t.agent_database = s.agent_database
     AND t.agent_schema = s.agent_schema
     AND t.agent_name = s.agent_name
    WHERE t.agent_database IS NULL;

    SELECT COUNT(*) INTO :updated_count
    FROM TMP_DISCOVER_AGENTS s
    JOIN AGENT_REGISTRY t
      ON t.agent_database = s.agent_database
     AND t.agent_schema = s.agent_schema
     AND t.agent_name = s.agent_name;

    MERGE INTO AGENT_REGISTRY AS target
    USING (
        SELECT
            agent_database,
            agent_schema,
            agent_name
        FROM TMP_DISCOVER_AGENTS
    ) AS source
      ON target.agent_database = source.agent_database
     AND target.agent_schema = source.agent_schema
     AND target.agent_name = source.agent_name
    WHEN MATCHED THEN
        UPDATE SET last_discovered = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (agent_database, agent_schema, agent_name, is_active, include_pattern, exclude_pattern)
        VALUES (source.agent_database, source.agent_schema, source.agent_name, :AUTO_ACTIVATE, :INCLUDE_PATTERN, :EXCLUDE_PATTERN);

    RETURN 'Discovery complete. Found: ' || discovered_count || ', Added: ' || added_count || ', Updated: ' || updated_count;
END;
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
COMMENT = 'DEMO: Snapshot of agent events, refreshed every 10 minutes by serverless task | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- TABLE: AGENT_INGEST_STATE
-- Per-agent ingest watermark and status (used for incremental history loads)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AGENT_INGEST_STATE (
    agent_database STRING NOT NULL,
    agent_schema STRING NOT NULL,
    agent_name STRING NOT NULL,
    last_event_timestamp TIMESTAMP_LTZ,
    last_refresh_at TIMESTAMP_LTZ,
    last_refresh_status STRING,
    last_error_message STRING,
    PRIMARY KEY (agent_database, agent_schema, agent_name)
)
COMMENT = 'DEMO: Per-agent ingest watermark and status for Wallmonitor | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- TABLE: AGENT_EVENTS_HISTORY
-- Recent event history used by dynamic tables (retained by REFRESH_AGENT_EVENTS)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS AGENT_EVENTS_HISTORY (
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
COMMENT = 'DEMO: Recent history of agent events used for 7-30d dashboards | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- PROCEDURE: REFRESH_AGENT_EVENTS
-- Incremental ingest into history + rebuild snapshot window for realtime views
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REFRESH_AGENT_EVENTS(
    LOOKBACK_HOURS FLOAT DEFAULT 24,
    HISTORY_DAYS INTEGER DEFAULT 30
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: Incremental ingest into history (7-30d) and snapshot (24h) for Wallmonitor | Expires: 2026-02-06'
AS
$$
DECLARE
    agent_cursor CURSOR FOR SELECT agent_database, agent_schema, agent_name FROM AGENT_REGISTRY WHERE is_active = TRUE;
    db STRING;
    schema_name STRING;
    agent STRING;
    history_rows INTEGER DEFAULT 0;
    snapshot_rows INTEGER DEFAULT 0;
    agent_count INTEGER DEFAULT 0;
    history_cutoff TIMESTAMP_LTZ;
    last_ts TIMESTAMP_LTZ;
    start_ts TIMESTAMP_LTZ;
    max_ts TIMESTAMP_LTZ;
BEGIN
    -- Normalize retention bounds
    IF (HISTORY_DAYS IS NULL OR HISTORY_DAYS < 1) THEN
        HISTORY_DAYS := 1;
    END IF;

    IF (LOOKBACK_HOURS IS NULL OR LOOKBACK_HOURS < 1) THEN
        LOOKBACK_HOURS := 1;
    END IF;

    history_cutoff := DATEADD('day', -HISTORY_DAYS, CURRENT_TIMESTAMP());

    -- Retention enforcement for history
    DELETE FROM AGENT_EVENTS_HISTORY
    WHERE event_timestamp < :history_cutoff;

    -- Loop through active agents
    FOR agent_record IN agent_cursor DO
        db := agent_record.agent_database;
        schema_name := agent_record.agent_schema;
        agent := agent_record.agent_name;
        agent_count := agent_count + 1;

        -- Compute incremental window (5 minute overlap to tolerate late/duplicated events)
        SELECT MAX(last_event_timestamp) INTO :last_ts
        FROM AGENT_INGEST_STATE
        WHERE agent_database = :db
          AND agent_schema = :schema_name
          AND agent_name = :agent;

        IF (last_ts IS NULL) THEN
            start_ts := :history_cutoff;
        ELSE
            start_ts := DATEADD('minute', -5, last_ts);
            IF (start_ts < history_cutoff) THEN
                start_ts := history_cutoff;
            END IF;
        END IF;

        BEGIN
            MERGE INTO AGENT_EVENTS_HISTORY AS t
            USING (
                SELECT
                    :db AS agent_database,
                    :schema_name AS agent_schema,
                    :agent AS agent_name,
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
                    :db, :schema_name, :agent, 'CORTEX AGENT'
                ))
                WHERE record:timestamp::TIMESTAMP_LTZ >= :start_ts
            ) AS s
            ON t.agent_database = s.agent_database
               AND t.agent_schema = s.agent_schema
               AND t.agent_name = s.agent_name
               AND COALESCE(t.span_id, '') = COALESCE(s.span_id, '')
               AND COALESCE(t.trace_id, '') = COALESCE(s.trace_id, '')
               AND t.event_timestamp = s.event_timestamp
            WHEN NOT MATCHED THEN
                INSERT (
                    agent_database,
                    agent_schema,
                    agent_name,
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
                    loaded_at
                )
                VALUES (
                    s.agent_database,
                    s.agent_schema,
                    s.agent_name,
                    s.event_timestamp,
                    s.event_name,
                    s.span_name,
                    s.span_id,
                    s.trace_id,
                    s.agent_id,
                    s.thread_id,
                    s.user_id,
                    s.model_name,
                    s.prompt_tokens,
                    s.completion_tokens,
                    s.total_tokens,
                    s.span_duration_ms,
                    s.tool_name,
                    s.retrieval_query,
                    s.status,
                    s.error_message,
                    s.raw_attributes,
                    s.loaded_at
                );

            history_rows := history_rows + SQLROWCOUNT;

            SELECT MAX(event_timestamp) INTO :max_ts
            FROM AGENT_EVENTS_HISTORY
            WHERE agent_database = :db
              AND agent_schema = :schema_name
              AND agent_name = :agent;

            MERGE INTO AGENT_INGEST_STATE AS st
            USING (SELECT :db AS agent_database, :schema_name AS agent_schema, :agent AS agent_name) AS src
            ON st.agent_database = src.agent_database
               AND st.agent_schema = src.agent_schema
               AND st.agent_name = src.agent_name
            WHEN MATCHED THEN
                UPDATE SET
                    last_event_timestamp = COALESCE(:max_ts, st.last_event_timestamp),
                    last_refresh_at = CURRENT_TIMESTAMP(),
                    last_refresh_status = 'OK',
                    last_error_message = NULL
            WHEN NOT MATCHED THEN
                INSERT (agent_database, agent_schema, agent_name, last_event_timestamp, last_refresh_at, last_refresh_status, last_error_message)
                VALUES (src.agent_database, src.agent_schema, src.agent_name, :max_ts, CURRENT_TIMESTAMP(), 'OK', NULL);
        EXCEPTION
            WHEN OTHER THEN
                MERGE INTO AGENT_INGEST_STATE AS st
                USING (SELECT :db AS agent_database, :schema_name AS agent_schema, :agent AS agent_name) AS src
                ON st.agent_database = src.agent_database
                   AND st.agent_schema = src.agent_schema
                   AND st.agent_name = src.agent_name
                WHEN MATCHED THEN
                    UPDATE SET
                        last_refresh_at = CURRENT_TIMESTAMP(),
                        last_refresh_status = 'ERROR',
                        last_error_message = 'Ingest failed (check privileges and agent existence)'
                WHEN NOT MATCHED THEN
                    INSERT (agent_database, agent_schema, agent_name, last_event_timestamp, last_refresh_at, last_refresh_status, last_error_message)
                    VALUES (src.agent_database, src.agent_schema, src.agent_name, NULL, CURRENT_TIMESTAMP(), 'ERROR', 'Ingest failed (check privileges and agent existence)');

                CONTINUE;
        END;
    END FOR;

    -- Rebuild realtime snapshot window from history
    TRUNCATE TABLE AGENT_EVENTS_SNAPSHOT;

    INSERT INTO AGENT_EVENTS_SNAPSHOT (
        agent_database,
        agent_schema,
        agent_name,
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
        loaded_at
    )
    SELECT
        agent_database,
        agent_schema,
        agent_name,
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
        CURRENT_TIMESTAMP() AS loaded_at
    FROM AGENT_EVENTS_HISTORY
    WHERE event_timestamp >= DATEADD('hour', -LOOKBACK_HOURS, CURRENT_TIMESTAMP());

    snapshot_rows := SQLROWCOUNT;

    RETURN
        'Refreshed Wallmonitor: agents=' || agent_count ||
        ', history_rows_added=' || history_rows ||
        ', snapshot_rows=' || snapshot_rows ||
        ', history_days=' || HISTORY_DAYS ||
        ', snapshot_hours=' || LOOKBACK_HOURS;
END;
$$;

-- -----------------------------------------------------------------------------
-- PROCEDURE: SETUP_MONITORING
-- One-step setup: Creates serverless task to refresh events every 10 minutes
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS SETUP_MONITORING(FLOAT, INTEGER);

CREATE OR REPLACE PROCEDURE SETUP_MONITORING(
    LOOKBACK_HOURS FLOAT DEFAULT 24,
    HISTORY_DAYS INTEGER DEFAULT 30
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    task_sql STRING;
BEGIN
    -- Drop existing task if it exists
    DROP TASK IF EXISTS REFRESH_AGENT_EVENTS_TASK;

    -- Create serverless task (runs every 10 minutes)
    task_sql := '
        CREATE TASK REFRESH_AGENT_EVENTS_TASK
            SCHEDULE = ''10 MINUTES''
            USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = ''XSMALL''
            COMMENT = ''DEMO: Auto-refresh agent events every 10 minutes (serverless) | Expires: 2026-02-06''
        AS
            CALL REFRESH_AGENT_EVENTS(' || LOOKBACK_HOURS || ', ' || HISTORY_DAYS || ');
    ';
    EXECUTE IMMEDIATE :task_sql;

    -- Do initial refresh
    CALL REFRESH_AGENT_EVENTS(:LOOKBACK_HOURS, :HISTORY_DAYS);

    -- Resume task
    ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;

    RETURN
        'Monitoring active: serverless task refreshing every 10 minutes (snapshot_hours=' ||
        LOOKBACK_HOURS || ', history_days=' || HISTORY_DAYS || ')';
END;
$$;

-- -----------------------------------------------------------------------------
-- VIEW: AGENT_EVENTS
-- Raw unified events from all monitored agents (reads from snapshot table)
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

COMMENT ON VIEW AGENT_EVENTS IS 'DEMO: Unified agent events (auto-refreshed every 10 minutes via serverless task) | Expires: 2026-02-06';

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

COMMENT ON VIEW THREAD_ACTIVITY IS 'DEMO: Thread-level aggregations showing conversation flows, tokens, and performance | Expires: 2026-02-06';

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

COMMENT ON VIEW AGENT_METRICS IS 'DEMO: Per-agent performance metrics, token usage, and error rates | Expires: 2026-02-06';

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

COMMENT ON VIEW REALTIME_KPI IS 'DEMO: Real-time KPIs for last hour with hour-over-hour comparison | Expires: 2026-02-06';

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

COMMENT ON VIEW HOURLY_THREAD_ACTIVITY IS 'DEMO: Hourly aggregations for time-series dashboard charts | Expires: 2026-02-06';

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

COMMENT ON VIEW THREAD_TIMELINE IS 'DEMO: Chronological event timeline within each thread for detailed drill-down (use ORDER BY in queries) | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- VIEW: AGENT_EVENTS_RECENT
-- Unified agent events from retained history (7-30d)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW AGENT_EVENTS_RECENT AS
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
    loaded_at,

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
FROM AGENT_EVENTS_HISTORY;

COMMENT ON VIEW AGENT_EVENTS_RECENT IS 'DEMO: Unified agent events over retained history (used for 7-30d dashboards) | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- DYNAMIC TABLES: RECENT HISTORY ROLLUPS (FAST 7-30D DASHBOARD QUERIES)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE DT_THREAD_ACTIVITY_RECENT
    TARGET_LAG = '30 minutes'
    WAREHOUSE = SFE_WALLMONITOR_WH
    COMMENT = 'DEMO: Thread-level rollups over recent history for dashboards | Expires: 2026-02-06'
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
FROM AGENT_EVENTS_RECENT
WHERE thread_id IS NOT NULL
GROUP BY agent_full_name, thread_id, user_id;

CREATE OR REPLACE VIEW THREAD_ACTIVITY_RECENT AS
SELECT
    agent_full_name,
    thread_id,
    user_id,
    thread_start_time,
    thread_last_activity,
    thread_duration_seconds,
    total_events,
    total_spans,
    llm_calls,
    tool_calls,
    retrieval_calls,
    total_prompt_tokens,
    total_completion_tokens,
    total_tokens,
    total_duration_ms,
    avg_llm_latency_ms,
    avg_tool_latency_ms,
    error_count,
    success_count,
    latest_status,
    latest_model
FROM DT_THREAD_ACTIVITY_RECENT;

COMMENT ON VIEW THREAD_ACTIVITY_RECENT IS 'DEMO: Thread activity rollups over recent history (7-30d) | Expires: 2026-02-06';

CREATE OR REPLACE DYNAMIC TABLE DT_AGENT_METRICS_RECENT
    TARGET_LAG = '30 minutes'
    WAREHOUSE = SFE_WALLMONITOR_WH
    COMMENT = 'DEMO: Per-agent rollups over recent history for dashboards | Expires: 2026-02-06'
AS
SELECT
    agent_full_name,
    agent_database,
    agent_schema,
    agent_name,

    COUNT(DISTINCT thread_id) AS unique_threads,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(*) AS total_events,
    COUNT(DISTINCT span_id) AS total_spans,

    COUNT(DISTINCT CASE WHEN span_category = 'LLM_CALL' THEN span_id END) AS llm_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'TOOL_EXECUTION' THEN span_id END) AS tool_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'RETRIEVAL' THEN span_id END) AS retrieval_calls,
    COUNT(DISTINCT CASE WHEN span_category = 'AGENT_RUN' THEN span_id END) AS agent_runs,

    SUM(COALESCE(total_tokens, 0)) AS total_tokens,
    SUM(COALESCE(prompt_tokens, 0)) AS total_prompt_tokens,
    SUM(COALESCE(completion_tokens, 0)) AS total_completion_tokens,
    AVG(COALESCE(total_tokens, 0)) AS avg_tokens_per_event,

    AVG(span_duration_ms) AS avg_span_duration_ms,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY span_duration_ms) AS p50_span_duration_ms,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY span_duration_ms) AS p95_span_duration_ms,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY span_duration_ms) AS p99_span_duration_ms,

    COUNT(DISTINCT model_name) AS models_used,
    MODE(model_name) AS most_used_model,

    COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) AS error_count,
    COUNT(CASE WHEN status = 'success' THEN 1 END) AS success_count,
    ROUND(
        COUNT(CASE WHEN status = 'error' OR error_message IS NOT NULL THEN 1 END) * 100.0
        / NULLIF(COUNT(*), 0),
        2
    ) AS error_rate_pct,

    MIN(event_timestamp) AS first_event,
    MAX(event_timestamp) AS last_event,
    COUNT(DISTINCT event_date) AS active_days
FROM AGENT_EVENTS_RECENT
GROUP BY agent_full_name, agent_database, agent_schema, agent_name;

CREATE OR REPLACE VIEW AGENT_METRICS_RECENT AS
SELECT
    agent_full_name,
    agent_database,
    agent_schema,
    agent_name,
    unique_threads,
    unique_users,
    total_events,
    total_spans,
    llm_calls,
    tool_calls,
    retrieval_calls,
    agent_runs,
    total_tokens,
    total_prompt_tokens,
    total_completion_tokens,
    avg_tokens_per_event,
    avg_span_duration_ms,
    p50_span_duration_ms,
    p95_span_duration_ms,
    p99_span_duration_ms,
    models_used,
    most_used_model,
    error_count,
    success_count,
    error_rate_pct,
    first_event,
    last_event,
    active_days
FROM DT_AGENT_METRICS_RECENT;

COMMENT ON VIEW AGENT_METRICS_RECENT IS 'DEMO: Agent metrics rollups over recent history (7-30d) | Expires: 2026-02-06';

CREATE OR REPLACE DYNAMIC TABLE DT_HOURLY_THREAD_ACTIVITY_RECENT
    TARGET_LAG = '30 minutes'
    WAREHOUSE = SFE_WALLMONITOR_WH
    COMMENT = 'DEMO: Hourly rollups over recent history for dashboards | Expires: 2026-02-06'
AS
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
FROM AGENT_EVENTS_RECENT
GROUP BY event_hour, agent_full_name;

CREATE OR REPLACE VIEW HOURLY_THREAD_ACTIVITY_RECENT AS
SELECT
    event_hour,
    agent_full_name,
    unique_threads,
    unique_users,
    total_events,
    llm_calls,
    tool_calls,
    total_tokens,
    total_prompt_tokens,
    total_completion_tokens,
    avg_span_duration_ms,
    p95_span_duration_ms,
    error_count
FROM DT_HOURLY_THREAD_ACTIVITY_RECENT;

COMMENT ON VIEW HOURLY_THREAD_ACTIVITY_RECENT IS 'DEMO: Hourly activity rollups over recent history (7-30d) | Expires: 2026-02-06';

CREATE OR REPLACE VIEW THREAD_TIMELINE_RECENT AS
SELECT
    thread_id,
    agent_database || '.' || agent_schema || '.' || agent_name AS agent_full_name,
    event_timestamp,
    span_name,
    CASE
        WHEN span_name LIKE '%LLM%' OR span_name LIKE '%COMPLETION%' THEN 'LLM_CALL'
        WHEN span_name LIKE '%TOOL%' THEN 'TOOL_EXECUTION'
        WHEN span_name LIKE '%RETRIEVAL%' OR span_name LIKE '%SEARCH%' THEN 'RETRIEVAL'
        WHEN span_name LIKE '%AGENT%' THEN 'AGENT_RUN'
        ELSE 'OTHER'
    END AS span_category,
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
    ROW_NUMBER() OVER (PARTITION BY thread_id ORDER BY event_timestamp) AS event_sequence,
    DATEDIFF(
        'second',
        FIRST_VALUE(event_timestamp) OVER (PARTITION BY thread_id ORDER BY event_timestamp),
        event_timestamp
    ) AS seconds_since_thread_start
FROM AGENT_EVENTS_HISTORY
WHERE thread_id IS NOT NULL;

COMMENT ON VIEW THREAD_TIMELINE_RECENT IS 'DEMO: Chronological timeline over recent history for thread drill-down (7-30d) | Expires: 2026-02-06';

-- -----------------------------------------------------------------------------
-- OPTIONAL: USAGE ANALYTICS FROM AI OBSERVABILITY EVENT TABLE
-- -----------------------------------------------------------------------------
-- This module uses SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS directly to compute
-- per-user / per-agent request metrics (no per-agent polling).
--
-- Requirements (varies by account configuration):
-- - Application role: SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP (or ADMIN)
-- - Appropriate privileges on the agent objects being monitored
--
-- If you do not have access, the setup procedure will return a SKIPPED message
-- and Wallmonitor will continue to function using the snapshot/history pipeline.

CREATE OR REPLACE PROCEDURE SETUP_USAGE_ANALYTICS(DAYS_BACK INTEGER DEFAULT 30)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
COMMENT = 'DEMO: Creates usage analytics objects from SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS | Expires: 2026-02-06'
AS
$$
DECLARE
    v_days INTEGER;
    ddl STRING;
BEGIN
    v_days := COALESCE(DAYS_BACK, 30);
    IF (v_days < 1) THEN
        v_days := 1;
    END IF;
    IF (v_days > 365) THEN
        v_days := 365;
    END IF;

    -- By-user request metrics
    ddl := '
CREATE OR REPLACE DYNAMIC TABLE DT_AGENT_USAGE_BY_USER
  TARGET_LAG = ''30 minutes''
  WAREHOUSE = SFE_WALLMONITOR_WH
  COMMENT = ''DEMO: Agent usage by user (derived from AI_OBSERVABILITY_EVENTS) | Expires: 2026-02-06''
AS
WITH agent_events AS (
  SELECT
    RECORD_ATTRIBUTES[''snow.ai.observability.database.name'']::VARCHAR AS agent_database,
    RECORD_ATTRIBUTES[''snow.ai.observability.schema.name'']::VARCHAR AS agent_schema,
    RECORD_ATTRIBUTES[''snow.ai.observability.object.name'']::VARCHAR AS agent_name,
    RESOURCE_ATTRIBUTES[''snow.user.name'']::VARCHAR AS user_name,
    RECORD_ATTRIBUTES[''snow.ai.observability.agent.thread_id'']::VARCHAR AS thread_id,
    TIMESTAMP AS event_time,
    START_TIMESTAMP AS start_time,
    RECORD:name::VARCHAR AS span_name
  FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
  WHERE TIMESTAMP >= DATEADD(''day'', -' || v_days || ', CURRENT_TIMESTAMP())
    AND RECORD_ATTRIBUTES[''snow.ai.observability.object.type'']::VARCHAR = ''Cortex Agent''
    AND RECORD:name::VARCHAR LIKE ''%ResponseGeneration%''
)
SELECT
  agent_name AS agent_name,
  agent_database AS agent_database,
  agent_schema AS agent_schema,
  user_name AS user_name,
  COUNT(*) AS total_requests,
  MIN(event_time) AS first_access_time,
  MAX(event_time) AS last_access_time,
  AVG(DATEDIFF(''millisecond'', start_time, event_time)) AS avg_response_duration_ms,
  COUNT(DISTINCT thread_id) AS unique_threads
FROM agent_events
WHERE agent_name IS NOT NULL
  AND agent_database IS NOT NULL
  AND agent_schema IS NOT NULL
GROUP BY agent_name, agent_database, agent_schema, user_name
';
    EXECUTE IMMEDIATE :ddl;

    EXECUTE IMMEDIATE '
CREATE OR REPLACE VIEW AGENT_USAGE_BY_USER AS
SELECT
  agent_name,
  agent_database,
  agent_schema,
  user_name,
  total_requests,
  first_access_time,
  last_access_time,
  avg_response_duration_ms,
  unique_threads
FROM DT_AGENT_USAGE_BY_USER
';

    -- By-agent summary
    ddl := '
CREATE OR REPLACE DYNAMIC TABLE DT_AGENT_USAGE_BY_AGENT
  TARGET_LAG = ''30 minutes''
  WAREHOUSE = SFE_WALLMONITOR_WH
  COMMENT = ''DEMO: Agent usage summary (derived from AI_OBSERVABILITY_EVENTS) | Expires: 2026-02-06''
AS
SELECT
  agent_database || ''.'' || agent_schema || ''.'' || agent_name AS agent_full_name,
  agent_database,
  agent_schema,
  agent_name,
  SUM(total_requests) AS total_requests,
  COUNT(DISTINCT user_name) AS unique_users,
  SUM(unique_threads) AS unique_threads,
  MIN(first_access_time) AS first_access_time,
  MAX(last_access_time) AS last_access_time,
  AVG(avg_response_duration_ms) AS avg_response_duration_ms
FROM DT_AGENT_USAGE_BY_USER
GROUP BY agent_database, agent_schema, agent_name
';
    EXECUTE IMMEDIATE :ddl;

    EXECUTE IMMEDIATE '
CREATE OR REPLACE VIEW AGENT_USAGE_BY_AGENT AS
SELECT
  agent_full_name,
  agent_database,
  agent_schema,
  agent_name,
  total_requests,
  unique_users,
  unique_threads,
  first_access_time,
  last_access_time,
  avg_response_duration_ms
FROM DT_AGENT_USAGE_BY_AGENT
';

    RETURN 'Usage analytics enabled (days_back=' || v_days || '). Objects: AGENT_USAGE_BY_USER, AGENT_USAGE_BY_AGENT';
EXCEPTION
    WHEN OTHER THEN
        RETURN 'SKIPPED: Usage analytics not enabled. Missing privileges for SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS or required application role.';
END;
$$;

-- -----------------------------------------------------------------------------
-- STREAMLIT DASHBOARD (NATIVE IN SNOWFLAKE)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE STAGE WALLMONITOR_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'DEMO: Stage for Wallmonitor Streamlit app files | Expires: 2026-02-06';

CREATE OR REPLACE PROCEDURE SETUP_WALLMONITOR_STREAMLIT_APP()
    RETURNS STRING
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'setup_app'
    COMMENT = 'DEMO: Uploads Streamlit app code to stage for Wallmonitor dashboard | Expires: 2026-02-06'
AS
$$
from io import BytesIO

def setup_app(session):
    files = {}

    files["lib/__init__.py"] = ""

    files["lib/wallmonitor.py"] = '''
import streamlit as st


def sql_safe_str(value: str) -> str:
    return value.replace("'", "''")


def in_clause(values: list[str]) -> str | None:
    if not values:
        return None
    return ",".join([f"'{sql_safe_str(v)}'" for v in values])


def cutoff_expr(window: str) -> str:
    if window == "1h":
        return "DATEADD('hour', -1, CURRENT_TIMESTAMP())"
    if window == "24h":
        return "DATEADD('hour', -24, CURRENT_TIMESTAMP())"
    if window == "7d":
        return "DATEADD('day', -7, CURRENT_TIMESTAMP())"
    if window == "30d":
        return "DATEADD('day', -30, CURRENT_TIMESTAMP())"
    raise ValueError(f"Unsupported window: {window}")


@st.cache_data(ttl=30)
def query_df(session, sql: str):
    return session.sql(sql).to_pandas()


def view_exists(session, view_name: str) -> bool:
    q = f"""
    SELECT COUNT(*) AS cnt
    FROM INFORMATION_SCHEMA.VIEWS
    WHERE table_name = '{sql_safe_str(view_name.upper())}'
    """
    rows = session.sql(q).collect()
    return int(rows[0]["CNT"]) > 0 if rows else False
'''

    files["streamlit_app.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import query_df

st.set_page_config(page_title="Wallmonitor", layout="wide")
session = get_active_session()

st.title("Wallmonitor")
st.caption("Cortex Agent observability dashboard (realtime + recent history)")

st.markdown(
    \"\"\"\n+This dashboard includes:\n+- Threads: realtime and recent-history thread views\n+- Agents: per-agent performance and usage\n+- Users: per-user usage (optional, requires AI Observability lookup privileges)\n+- Errors: recent error drill-down\n+- Trends: hourly activity and token trends\n+\"\"\"\n+)

st.subheader("Realtime KPIs (last 1h)")
kpi = query_df(
    session,
    \"\"\"
    SELECT
      active_threads,
      active_users,
      active_agents,
      llm_calls,
      total_tokens,
      avg_span_duration_ms,
      error_rate_pct
    FROM REALTIME_KPI
    \"\"\",
)

if len(kpi):
    row = kpi.iloc[0]
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Active threads", int(row["ACTIVE_THREADS"]))
    c2.metric("Active users", int(row["ACTIVE_USERS"]))
    c3.metric("Active agents", int(row["ACTIVE_AGENTS"]))
    c4.metric("LLM calls", int(row["LLM_CALLS"]))
    c5.metric("Tokens", int(row["TOTAL_TOKENS"]))
else:
    st.info("No KPI data yet. Start monitoring and generate some agent activity.")
'''

    files["pages/01_threads.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import cutoff_expr, in_clause, query_df, sql_safe_str

st.set_page_config(page_title="Wallmonitor - Threads", layout="wide")
session = get_active_session()

st.title("Threads")

with st.sidebar:
    window = st.selectbox("Time window", ["1h", "24h", "7d", "30d"], index=1)
    max_threads = st.slider("Max threads", min_value=10, max_value=500, value=50, step=10)
    use_recent = window in ("7d", "30d")
    agent_source = "AGENT_EVENTS_RECENT" if use_recent else "AGENT_EVENTS"
    agents_df = query_df(session, f"SELECT DISTINCT agent_full_name FROM {agent_source} ORDER BY agent_full_name")
    agent_options = agents_df["AGENT_FULL_NAME"].tolist() if len(agents_df) else []
    selected_agents = st.multiselect("Agents", options=agent_options)

cutoff = cutoff_expr(window)
agents_in = in_clause(selected_agents)
agent_filter = f" AND agent_full_name IN ({agents_in})" if agents_in else ""

threads_view = "THREAD_ACTIVITY_RECENT" if use_recent else "THREAD_ACTIVITY"
threads_sql = f"""
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
FROM {threads_view}
WHERE thread_start_time >= {cutoff}{agent_filter}
ORDER BY thread_start_time DESC
LIMIT {int(max_threads)}
"""
threads = query_df(session, threads_sql)
st.dataframe(threads, use_container_width=True, hide_index=True)

st.subheader("Drill-down")
if len(threads):
    selected_thread = st.selectbox("Thread", options=threads["THREAD_ID"].tolist())
    timeline_view = "THREAD_TIMELINE_RECENT" if use_recent else "THREAD_TIMELINE"
    timeline_sql = f"""
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
    FROM {timeline_view}
    WHERE thread_id = '{sql_safe_str(selected_thread)}'
    ORDER BY event_timestamp
    """
    timeline = query_df(session, timeline_sql)
    st.dataframe(timeline, use_container_width=True, hide_index=True)
else:
    st.info("No threads found for the selected window/filters.")
'''

    files["pages/02_agents.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import cutoff_expr, in_clause, query_df

st.set_page_config(page_title="Wallmonitor - Agents", layout="wide")
session = get_active_session()

st.title("Agents")

with st.sidebar:
    window = st.selectbox("Time window", ["24h", "7d", "30d"], index=0)
    use_recent = window in ("7d", "30d")
    agent_source = "AGENT_EVENTS_RECENT" if use_recent else "AGENT_EVENTS"
    agents_df = query_df(session, f"SELECT DISTINCT agent_full_name FROM {agent_source} ORDER BY agent_full_name")
    agent_options = agents_df["AGENT_FULL_NAME"].tolist() if len(agents_df) else []
    selected_agents = st.multiselect("Agents", options=agent_options)

cutoff = cutoff_expr(window)
agents_in = in_clause(selected_agents)
agent_filter = f" AND agent_full_name IN ({agents_in})" if agents_in else ""

metrics_view = "AGENT_METRICS_RECENT" if use_recent else "AGENT_METRICS"
metrics_sql = f"""
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
FROM {metrics_view}
WHERE last_event >= {cutoff}{agent_filter}
ORDER BY unique_threads DESC
"""
metrics = query_df(session, metrics_sql)
st.dataframe(metrics, use_container_width=True, hide_index=True)
'''

    files["pages/03_users.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import cutoff_expr, query_df, view_exists

st.set_page_config(page_title="Wallmonitor - Users", layout="wide")
session = get_active_session()

st.title("Users")

with st.sidebar:
    window = st.selectbox("Time window", ["7d", "30d"], index=0)

cutoff = cutoff_expr(window)

if view_exists(session, "AGENT_USAGE_BY_USER"):
    st.caption("Using AI Observability event-table analytics (AGENT_USAGE_BY_USER).")
    sql = f"""
    SELECT
      agent_name,
      agent_database,
      agent_schema,
      user_name,
      total_requests,
      unique_threads,
      avg_response_duration_ms,
      first_access_time,
      last_access_time
    FROM AGENT_USAGE_BY_USER
    WHERE last_access_time >= {cutoff}
    ORDER BY total_requests DESC
    LIMIT 200
    """
    df = query_df(session, sql)
    st.dataframe(df, use_container_width=True, hide_index=True)
else:
    st.caption("Fallback: derived from thread activity (user_id).")
    sql = f"""
    SELECT
      user_id,
      COUNT(*) AS threads,
      SUM(total_tokens) AS total_tokens,
      SUM(error_count) AS errors,
      MAX(thread_last_activity) AS last_activity
    FROM THREAD_ACTIVITY_RECENT
    WHERE thread_last_activity >= {cutoff}
      AND user_id IS NOT NULL
    GROUP BY user_id
    ORDER BY threads DESC
    LIMIT 200
    """
    df = query_df(session, sql)
    st.dataframe(df, use_container_width=True, hide_index=True)
'''

    files["pages/04_errors.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import cutoff_expr, in_clause, query_df

st.set_page_config(page_title="Wallmonitor - Errors", layout="wide")
session = get_active_session()

st.title("Errors")

with st.sidebar:
    window = st.selectbox("Time window", ["24h", "7d", "30d"], index=0)
    use_recent = window in ("7d", "30d")
    agent_source = "AGENT_EVENTS_RECENT" if use_recent else "AGENT_EVENTS"
    agents_df = query_df(session, f"SELECT DISTINCT agent_full_name FROM {agent_source} ORDER BY agent_full_name")
    agent_options = agents_df["AGENT_FULL_NAME"].tolist() if len(agents_df) else []
    selected_agents = st.multiselect("Agents", options=agent_options)
    limit = st.slider("Rows", min_value=20, max_value=500, value=100, step=20)

cutoff = cutoff_expr(window)
agents_in = in_clause(selected_agents)
agent_filter = f" AND agent_full_name IN ({agents_in})" if agents_in else ""

events_view = "AGENT_EVENTS_RECENT" if use_recent else "AGENT_EVENTS"
sql = f"""
SELECT
  event_timestamp,
  agent_full_name,
  thread_id,
  user_id,
  span_name,
  span_category,
  model_name,
  tool_name,
  total_tokens,
  span_duration_ms,
  status,
  error_message
FROM {events_view}
WHERE event_timestamp >= {cutoff}
  AND (status = 'error' OR error_message IS NOT NULL){agent_filter}
ORDER BY event_timestamp DESC
LIMIT {int(limit)}
"""
df = query_df(session, sql)
st.dataframe(df, use_container_width=True, hide_index=True)
'''

    files["pages/05_trends.py"] = '''
import streamlit as st
from snowflake.snowpark.context import get_active_session
from lib.wallmonitor import cutoff_expr, query_df

st.set_page_config(page_title="Wallmonitor - Trends", layout="wide")
session = get_active_session()

st.title("Trends")

with st.sidebar:
    window = st.selectbox("Time window", ["24h", "7d", "30d"], index=0)
    use_recent = window in ("7d", "30d")

cutoff = cutoff_expr(window)
hourly_view = "HOURLY_THREAD_ACTIVITY_RECENT" if use_recent else "HOURLY_THREAD_ACTIVITY"

sql = f"""
SELECT
  event_hour,
  SUM(unique_threads) AS threads,
  SUM(llm_calls) AS llm_calls,
  SUM(total_tokens) AS total_tokens,
  ROUND(AVG(avg_span_duration_ms), 2) AS avg_latency_ms,
  SUM(error_count) AS errors
FROM {hourly_view}
WHERE event_hour >= {cutoff}
GROUP BY event_hour
ORDER BY event_hour
"""
df = query_df(session, sql)
if len(df):
    df = df.set_index("EVENT_HOUR")
    st.line_chart(df[["THREADS"]])
    st.line_chart(df[["TOTAL_TOKENS"]])
else:
    st.info("No trend data available for the selected window.")
'''

    uploaded = 0
    for rel_path, content in files.items():
        file_stream = BytesIO(content.encode("utf-8"))
        session.file.put_stream(
            input_stream=file_stream,
            stage_location=f"@WALLMONITOR_STREAMLIT_STAGE/{rel_path}",
            auto_compress=False,
            overwrite=True,
        )
        uploaded += 1

    return f"Streamlit app files uploaded: {uploaded}"
$$;

CALL SETUP_WALLMONITOR_STREAMLIT_APP();
ALTER STAGE WALLMONITOR_STREAMLIT_STAGE REFRESH;

CREATE OR REPLACE STREAMLIT WALLMONITOR_DASHBOARD
    FROM '@SNOWFLAKE_EXAMPLE.WALLMONITOR.WALLMONITOR_STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = SFE_WALLMONITOR_WH
    TITLE = 'Wallmonitor'
    COMMENT = 'DEMO: Wallmonitor Streamlit dashboard | Expires: 2026-02-06';

ALTER STREAMLIT WALLMONITOR_DASHBOARD ADD LIVE VERSION FROM LAST;

-- =============================================================================
-- QUICK START (Auto-Setup)
-- =============================================================================
-- These commands run automatically during deployment

-- Step 1: Discover agents in your account
CALL DISCOVER_AGENTS('%', NULL, TRUE);

-- Step 2: Activate monitoring (creates serverless task that runs every 10 minutes)
CALL SETUP_MONITORING(24, 30);

-- =============================================================================
-- CUSTOMIZATION
-- =============================================================================

-- Pause monitoring (stops serverless task)
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK SUSPEND;

-- Resume monitoring
-- ALTER TASK REFRESH_AGENT_EVENTS_TASK RESUME;

-- Manual refresh (on-demand)
-- CALL REFRESH_AGENT_EVENTS(24, 30);

-- Add more agents (re-run setup after discovering new agents)
-- CALL DISCOVER_AGENTS('%NEW_PATTERN%', NULL, TRUE);
-- CALL SETUP_MONITORING(24, 30);

-- -----------------------------------------------------------------------------
-- GRANTS (adjust as needed)
-- -----------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON WAREHOUSE SFE_WALLMONITOR_WH TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT SELECT ON ALL VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT USAGE ON ALL FUNCTIONS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT USAGE ON ALL PROCEDURES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;

GRANT USAGE ON STREAMLIT SNOWFLAKE_EXAMPLE.WALLMONITOR.WALLMONITOR_DASHBOARD TO ROLE SFE_WALLMONITOR_VIEWER;
GRANT USAGE ON FUTURE STREAMLITS IN SCHEMA SNOWFLAKE_EXAMPLE.WALLMONITOR TO ROLE SFE_WALLMONITOR_VIEWER;

-- -----------------------------------------------------------------------------
-- DEPLOYMENT SUMMARY
-- -----------------------------------------------------------------------------
SELECT
    '========================================' AS message
UNION ALL SELECT 'WALLMONITOR DEPLOYED & ACTIVE'
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
UNION ALL SELECT '  - REALTIME_KPI'
UNION ALL SELECT '  - THREAD_ACTIVITY'
UNION ALL SELECT '  - AGENT_METRICS'
UNION ALL SELECT '  - THREAD_ACTIVITY_RECENT'
UNION ALL SELECT '  - AGENT_METRICS_RECENT'
UNION ALL SELECT '  - HOURLY_THREAD_ACTIVITY_RECENT'
UNION ALL SELECT '  - THREAD_TIMELINE_RECENT'
UNION ALL SELECT ''
UNION ALL SELECT 'Streamlit: Projects > Streamlit > WALLMONITOR_DASHBOARD'
UNION ALL SELECT ''
UNION ALL SELECT 'Data refreshes every 10 minutes (serverless)'
UNION ALL SELECT 'See example_queries.sql for dashboard queries';
