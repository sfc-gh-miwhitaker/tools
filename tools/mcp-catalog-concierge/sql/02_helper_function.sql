-- =============================================================================
-- MCP Snowflake Bridge - Helper Function
-- =============================================================================
-- Purpose:
--   Create helper functions used by MCP tools. These functions intentionally do
--   NOT call an LLM; they return structured metadata for external clients.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- Assumes variables were set by sql/00_config.sql and the schema/warehouse were
-- created by sql/01_setup.sql.
USE DATABASE IDENTIFIER($demo_db);
USE SCHEMA IDENTIFIER($demo_db || '.' || $project_schema);
USE WAREHOUSE IDENTIFIER($warehouse_name);

CREATE OR REPLACE FUNCTION LIST_SCHEMA_OBJECTS(max_results NUMBER)
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: Returns a JSON summary of tables/views in the current schema. Expires: 2026-02-04'
AS
$$
SELECT OBJECT_CONSTRUCT(
  'database', CURRENT_DATABASE(),
  'schema', CURRENT_SCHEMA(),
  'tables', COALESCE(
    ARRAY_AGG(
      OBJECT_CONSTRUCT(
        'name', t.table_name,
        'type', t.table_type,
        'comment', t.comment
      )
    ) WITHIN GROUP (ORDER BY t.table_name),
    ARRAY_CONSTRUCT()
  )
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
$$;


