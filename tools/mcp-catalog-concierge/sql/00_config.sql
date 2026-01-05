-- =============================================================================
-- MCP Snowflake Bridge - Shared Config
-- =============================================================================
-- Purpose:
--   Configure naming and enforce expiration for the VS Code-focused MCP demo.
--   This file is executed first by deploy_all.sql.
--
-- Author: SE Community
-- Created: 2026-01-05
-- Expires: 2026-02-04 (30 days)
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- Expiration (do not edit)
-- =============================================================================
SET demo_expires_on = '2026-02-04';

DO $$
DECLARE
    expires_on DATE DEFAULT TO_DATE(:demo_expires_on);
    demo_expired EXCEPTION (-20001, 'ERROR: This demo expired on 2026-02-04. Please get an updated version.');
BEGIN
    IF (CURRENT_DATE() > expires_on) THEN
        RAISE demo_expired;
    END IF;
    RETURN 'OK: Demo is current (' || :demo_expires_on || ').';
END;
$$;

-- =============================================================================
-- Configuration
-- =============================================================================
SET demo_db = 'SNOWFLAKE_EXAMPLE';

-- Stable, collision-proof enough for a single demo; easiest cleanup story.
SET project_schema = 'MCP_SNOWFLAKE_BRIDGE';

-- Account-level warehouse (SFE_ prefix required for account objects).
SET warehouse_name = 'SFE_MCP_SNOWFLAKE_BRIDGE_WH';

-- MCP server (lives in the project schema).
SET mcp_server_name = 'MCP_SNOWFLAKE_BRIDGE';



