CREATE OR REPLACE PROCEDURE SNOWFLAKE_EXAMPLE.WALLMONITOR.ANALYZE_AGENT_USAGE_HISTORY(
    DAYS_BACK INT
)
RETURNS TABLE(
    AGENT_NAME VARCHAR,
    AGENT_DATABASE VARCHAR,
    AGENT_SCHEMA VARCHAR,
    USER_NAME VARCHAR,
    TOTAL_REQUESTS NUMBER,
    FIRST_ACCESS_TIME TIMESTAMP_LTZ,
    LAST_ACCESS_TIME TIMESTAMP_LTZ,
    AVG_RESPONSE_DURATION_MS NUMBER,
    UNIQUE_THREADS NUMBER
)
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    result_set RESULTSET;
BEGIN
    result_set := (
        WITH agent_events AS (
            SELECT
                RECORD_ATTRIBUTES['snow.ai.observability.database.name']::VARCHAR AS agent_database,
                RECORD_ATTRIBUTES['snow.ai.observability.schema.name']::VARCHAR AS agent_schema,
                RECORD_ATTRIBUTES['snow.ai.observability.object.name']::VARCHAR AS agent_name,
                RESOURCE_ATTRIBUTES['snow.user.name']::VARCHAR AS user_name,
                RECORD_ATTRIBUTES['snow.ai.observability.agent.thread_id']::VARCHAR AS thread_id,
                TIMESTAMP,
                START_TIMESTAMP,
                RECORD:name::VARCHAR AS span_name,
                RECORD_ATTRIBUTES['snow.ai.observability.agent.planning.duration']::FLOAT AS planning_duration_ms
            FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
            WHERE
                TIMESTAMP >= DATEADD(DAY, -:DAYS_BACK, CURRENT_TIMESTAMP())
                AND RECORD_ATTRIBUTES['snow.ai.observability.object.type']::VARCHAR = 'Cortex Agent'
                AND RECORD:name::VARCHAR LIKE '%ResponseGeneration%'
        )
        SELECT
            agent_name::VARCHAR AS AGENT_NAME,
            agent_database::VARCHAR AS AGENT_DATABASE,
            agent_schema::VARCHAR AS AGENT_SCHEMA,
            user_name::VARCHAR AS USER_NAME,
            COUNT(*)::NUMBER AS TOTAL_REQUESTS,
            MIN(TIMESTAMP)::TIMESTAMP_LTZ AS FIRST_ACCESS_TIME,
            MAX(TIMESTAMP)::TIMESTAMP_LTZ AS LAST_ACCESS_TIME,
            AVG(DATEDIFF(millisecond, START_TIMESTAMP, TIMESTAMP))::NUMBER AS AVG_RESPONSE_DURATION_MS,
            COUNT(DISTINCT thread_id)::NUMBER AS UNIQUE_THREADS
        FROM agent_events
        GROUP BY agent_name, agent_database, agent_schema, user_name
        ORDER BY total_requests DESC, agent_name, user_name
    );

    RETURN TABLE(result_set);
END;
$$;

CALL SNOWFLAKE_EXAMPLE.WALLMONITOR.ANALYZE_AGENT_USAGE_HISTORY(120);
