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

-- Prefer IDENTIFIER() over EXECUTE IMMEDIATE wherever possible (clearer + safer).
DROP MCP SERVER IF EXISTS IDENTIFIER($demo_db || '.' || $project_schema || '.' || $mcp_server_name);

USE DATABASE IDENTIFIER($demo_db);
USE SCHEMA IDENTIFIER($demo_db || '.' || $project_schema);

DROP FUNCTION IF EXISTS LIST_SCHEMA_OBJECTS(NUMBER);
DROP AGENT IF EXISTS MCP_SQL_HELPER;

-- Drop the schema last so we can still reference in-schema objects above.
DROP SCHEMA IF EXISTS IDENTIFIER($demo_db || '.' || $project_schema) CASCADE;

DROP WAREHOUSE IF EXISTS IDENTIFIER($warehouse_name);

DROP GIT REPOSITORY IF EXISTS IDENTIFIER($demo_db || '.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO');

-- NOTE: shared objects are intentionally left in place:
-- - SNOWFLAKE_EXAMPLE database
-- - SNOWFLAKE_EXAMPLE.TOOLS schema
-- - SFE_GITHUB_API_INTEGRATION
-- - (other demos may reuse the API integration)

SELECT
  'CLEANUP_COMPLETE' AS status,
  CURRENT_TIMESTAMP()::VARCHAR AS cleaned_at;


