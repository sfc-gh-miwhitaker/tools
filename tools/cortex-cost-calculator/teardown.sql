/******************************************************************************
 * Tool: Cortex Cost Calculator
 * File: teardown.sql
 * Author: SE Community
 *
 * Purpose: Removes all objects created by this tool
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 ******************************************************************************/

USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

-- Suspend task first
ALTER TASK IF EXISTS SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC.SFE_DAILY_SNAPSHOT_TASK SUSPEND;

-- Drop schema (CASCADE removes all contained objects)
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC CASCADE;

SELECT
    '✅ TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Cost Calculator removed' AS message;
