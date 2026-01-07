/******************************************************************************
 * Tool: Wallmonitor (Cortex Agent Monitoring)
 * File: teardown.sql
 * Author: SE Community
 *
 * Purpose: Removes all objects created by tools/wallmonitor/deploy.sql
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 ******************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================================
-- DROP STREAMLIT + STAGE (explicit, then drop schema)
-- ============================================================================
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR.WALLMONITOR_DASHBOARD;
DROP STAGE IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR.WALLMONITOR_STREAMLIT_STAGE;

-- ============================================================================
-- DROP TASK (explicit, then drop schema)
-- ============================================================================
DROP TASK IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR.REFRESH_AGENT_EVENTS_TASK;

-- ============================================================================
-- DROP SCHEMA (CASCADE removes all contained objects: tables, views, procedures,
-- dynamic tables, stages not already removed, etc.)
-- ============================================================================
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.WALLMONITOR CASCADE;

-- ============================================================================
-- DROP DEDICATED WAREHOUSE
-- ============================================================================
DROP WAREHOUSE IF EXISTS SFE_WALLMONITOR_WH;

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
SELECT
    'TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Wallmonitor' AS tool,
    'Dropped schema SNOWFLAKE_EXAMPLE.WALLMONITOR and warehouse SFE_WALLMONITOR_WH' AS message;
