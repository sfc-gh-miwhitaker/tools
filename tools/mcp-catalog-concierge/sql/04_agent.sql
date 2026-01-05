-- =============================================================================
-- MCP Snowflake Bridge - Optional Cortex Agent (Not used by default)
-- =============================================================================
-- Purpose:
--   Optional: Create a lightweight agent that can help draft SQL and explain results.
--   This is NOT wired into the MCP server by default; external clients typically
--   provide their own LLM for reasoning and use the MCP tools for data access.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- NOTE: Agent creation is optional and may require Cortex feature availability.
-- If you do not need it, you can skip running this script.
CREATE OR REPLACE AGENT MCP_SQL_HELPER
  COMMENT = 'DEMO: Optional helper agent for SQL drafting guidance. Expires: 2026-02-04'
  FROM SPECIFICATION
  $$
  instructions:
    response: "Be concise. Prefer bullets. If suggesting SQL, avoid SELECT * and include explicit column lists."
    system: "You are a Snowflake SQL assistant. You do not have direct data access unless tools are provided."
  $$;


