-- =============================================================================
-- MCP Snowflake Bridge - Setup
-- =============================================================================
-- Purpose:
--   Create the project schema and warehouse used by the MCP server.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Context (variables set by sql/00_config.sql)
--
-- Prefer IDENTIFIER() over EXECUTE IMMEDIATE wherever possible:
-- - clearer code
-- - fewer quoting pitfalls
-- - reduces SQL injection risk when code is generalized
CREATE DATABASE IF NOT EXISTS IDENTIFIER($demo_db)
  COMMENT = 'DEMO: Shared demo database for SE Community reference implementations.';

CREATE SCHEMA IF NOT EXISTS IDENTIFIER($demo_db || '.' || $project_schema)
  COMMENT = 'DEMO: MCP Snowflake Bridge (VS Code). Expires: 2026-02-04';

CREATE OR REPLACE WAREHOUSE IDENTIFIER($warehouse_name)
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'DEMO: MCP Snowflake Bridge warehouse. Expires: 2026-02-04';

USE DATABASE IDENTIFIER($demo_db);
USE SCHEMA IDENTIFIER($demo_db || '.' || $project_schema);
USE WAREHOUSE IDENTIFIER($warehouse_name);
