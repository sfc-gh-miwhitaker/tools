-- =============================================================================
-- MCP Snowflake Bridge - MCP Server
-- =============================================================================
-- Purpose:
--   Create a minimal Snowflake-managed MCP server intended for external clients.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Assumes context + variables already set by sql/00_config.sql, sql/01_setup.sql,
-- and sql/02_helper_function.sql.
DECLARE
    spec STRING;
    stmt STRING;
BEGIN
    spec := $$
tools:
  - name: "execute_sql"
    type: "SYSTEM_EXECUTE_SQL"
    title: "SQL Execution"
    description: "Execute SQL queries against Snowflake. Use explicit column projection; avoid SELECT *."

  - name: "ask_snowflake"
    type: "GENERIC"
    identifier: "__LIST_SCHEMA_OBJECTS_FQN__"
    title: "Schema Snapshot"
    description: "Return a structured JSON summary of tables/views in the current schema (no LLM calls)."
    config:
      type: "function"
      warehouse: "__WAREHOUSE__"
      input_schema:
        type: "object"
        properties:
          max_results:
            type: "number"
            description: "Maximum number of objects to return (e.g., 25, 100)."
        required: ["max_results"]
$$;

    spec := REPLACE(spec, '__LIST_SCHEMA_OBJECTS_FQN__', $demo_db || '.' || $project_schema || '.LIST_SCHEMA_OBJECTS');
    spec := REPLACE(spec, '__WAREHOUSE__', $warehouse_name);

    stmt := 'CREATE OR REPLACE MCP SERVER ' || $demo_db || '.' || $project_schema || '.' || $mcp_server_name || ' ' ||
            'FROM SPECIFICATION $$' || spec || '$$ ' ||
            'COMMENT = ''DEMO: Snowflake-managed MCP server for VS Code clients. Expires: ' || $demo_expires_on || '''';
    EXECUTE IMMEDIATE stmt;
END;


