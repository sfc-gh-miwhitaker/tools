-- =============================================================================
-- MCP Snowflake Bridge - Setup
-- =============================================================================
-- Purpose:
--   Create the project schema, warehouse, and helper function used by the MCP server.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Context (variables set by sql/00_config.sql)
DO $$
DECLARE
    stmt STRING;
BEGIN
    stmt := 'CREATE DATABASE IF NOT EXISTS ' || :demo_db ||
            ' COMMENT = ''DEMO: Shared demo database for SE Community reference implementations.''';
    EXECUTE IMMEDIATE stmt;

    stmt := 'CREATE SCHEMA IF NOT EXISTS ' || :demo_db || '.' || :project_schema ||
            ' COMMENT = ''DEMO: MCP Snowflake Bridge (VS Code). Expires: ' || :demo_expires_on || '''';
    EXECUTE IMMEDIATE stmt;

    stmt := 'CREATE OR REPLACE WAREHOUSE ' || :warehouse_name || ' WITH ' ||
            'WAREHOUSE_SIZE = ''X-SMALL'' ' ||
            'AUTO_SUSPEND = 60 ' ||
            'AUTO_RESUME = TRUE ' ||
            'INITIALLY_SUSPENDED = TRUE ' ||
            'COMMENT = ''DEMO: MCP Snowflake Bridge warehouse. Expires: ' || :demo_expires_on || '''';
    EXECUTE IMMEDIATE stmt;

    EXECUTE IMMEDIATE 'USE DATABASE ' || :demo_db;
    EXECUTE IMMEDIATE 'USE SCHEMA ' || :demo_db || '.' || :project_schema;
    EXECUTE IMMEDIATE 'USE WAREHOUSE ' || :warehouse_name;
END;
$$;

-- -----------------------------------------------------------------------------
-- Helper function for MCP clients (GENERIC tool)
-- -----------------------------------------------------------------------------
-- This function intentionally does NOT call an LLM.
-- It provides structured metadata that an external client can use for routing.
CREATE OR REPLACE FUNCTION LIST_SCHEMA_OBJECTS(max_results NUMBER)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: Returns a JSON summary of tables/views in the current schema. Expires: 2026-02-04'
AS
$$
SELECT OBJECT_CONSTRUCT(
  'database', CURRENT_DATABASE(),
  'schema', CURRENT_SCHEMA(),
  'tables', (
    SELECT COALESCE(
      ARRAY_AGG(
        OBJECT_CONSTRUCT(
          'name', t.table_name,
          'type', t.table_type,
          'comment', t.comment
        )
      ),
      ARRAY_CONSTRUCT()
    )
    FROM (
      SELECT
        table_name,
        table_type,
        comment
      FROM INFORMATION_SCHEMA.TABLES
      WHERE table_schema = CURRENT_SCHEMA()
      ORDER BY table_name
      LIMIT max_results
    ) t
  )
);
$$;


