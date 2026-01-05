-- =============================================================================
-- MCP Snowflake Bridge - Cleanup
-- =============================================================================
-- Purpose: Remove demo objects created by deploy_all.sql
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- This demo uses stable names for frictionless cleanup.
SET demo_db = 'SNOWFLAKE_EXAMPLE';
SET project_schema = 'MCP_SNOWFLAKE_BRIDGE';
SET warehouse_name = 'SFE_MCP_SNOWFLAKE_BRIDGE_WH';
SET mcp_server_name = 'MCP_SNOWFLAKE_BRIDGE';

DECLARE
    stmt STRING;
BEGIN
    stmt := 'DROP MCP SERVER IF EXISTS ' || $demo_db || '.' || $project_schema || '.' || $mcp_server_name;
    EXECUTE IMMEDIATE stmt;

    stmt := 'DROP FUNCTION IF EXISTS ' || $demo_db || '.' || $project_schema || '.LIST_SCHEMA_OBJECTS(NUMBER)';
    EXECUTE IMMEDIATE stmt;

    stmt := 'DROP AGENT IF EXISTS ' || $demo_db || '.' || $project_schema || '.MCP_SQL_HELPER';
    EXECUTE IMMEDIATE stmt;

    stmt := 'DROP SCHEMA IF EXISTS ' || $demo_db || '.' || $project_schema || ' CASCADE';
    EXECUTE IMMEDIATE stmt;

    stmt := 'DROP WAREHOUSE IF EXISTS ' || $warehouse_name;
    EXECUTE IMMEDIATE stmt;

    stmt := 'DROP GIT REPOSITORY IF EXISTS ' || $demo_db || '.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO';
    EXECUTE IMMEDIATE stmt;
END;

-- NOTE: shared objects are intentionally left in place:
-- - SNOWFLAKE_EXAMPLE database
-- - SNOWFLAKE_EXAMPLE.TOOLS schema
-- - SFE_GITHUB_API_INTEGRATION
-- - (other demos may reuse the API integration)

SELECT
  'CLEANUP_COMPLETE' AS status,
  CURRENT_TIMESTAMP()::VARCHAR AS cleaned_at;


