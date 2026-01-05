/*******************************************************************************
 * Script: MCP Snowflake Bridge - Deploy
 * Author: SE Community
 * Created: 2026-01-05
 * Expires: 2026-02-04 (30 days)
 *
 * Purpose:
 *   Deploy a minimal Snowflake-managed MCP server intended to be consumed by
 *   external MCP clients (for example, VS Code extensions).
 *
 * Execution:
 *   Copy/paste into a Snowsight SQL worksheet and click Run All.
 *
 * What gets created:
 *   - SNOWFLAKE_EXAMPLE.MCP_SNOWFLAKE_BRIDGE schema (or configured schema)
 *   - SFE_MCP_SNOWFLAKE_BRIDGE_WH warehouse
 *   - MCP server with:
 *       1) execute_sql (SYSTEM_EXECUTE_SQL)
 *       2) ask_snowflake (GENERIC) - lightweight helper function
 ******************************************************************************/

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- Step 0: Bootstrap Git repo stage (idempotent)
-- ============================================================================
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
  COMMENT = 'DEMO: Shared demo database for SE Community reference implementations.';

CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.TOOLS
  COMMENT = 'DEMO: Shared tooling schema for Git repos and reusable infra.';

CREATE API INTEGRATION IF NOT EXISTS SFE_GITHUB_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ALLOWED_AUTHENTICATION_SECRETS = ALL
  ENABLED = TRUE
  COMMENT = 'DEMO: Generic GitHub API integration for SE Community demos.';

CREATE OR REPLACE GIT REPOSITORY SNOWFLAKE_EXAMPLE.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO
  API_INTEGRATION = SFE_GITHUB_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/tools.git'
  COMMENT = 'DEMO: Git repo clone for MCP Snowflake Bridge. Expires: 2026-02-04';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO FETCH;

-- ============================================================================
-- Step 1: Config + setup + MCP server (executed from Git)
-- ============================================================================
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO/branches/main/tools/mcp-catalog-concierge/sql/00_config.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO/branches/main/tools/mcp-catalog-concierge/sql/01_setup.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.TOOLS.SFE_MCP_SNOWFLAKE_BRIDGE_REPO/branches/main/tools/mcp-catalog-concierge/sql/02_mcp_server.sql';

-- ============================================================================
-- Final summary (single result set)
-- ============================================================================
SELECT
    'DEPLOYMENT_COMPLETE' AS status,
    CURRENT_TIMESTAMP()::VARCHAR AS deployed_at,
    $demo_db AS database_name,
    $project_schema AS project_schema,
    $warehouse_name AS warehouse_name,
    $mcp_server_name AS mcp_server_name,
    '/api/v2/databases/' || $demo_db || '/schemas/' || $project_schema || '/mcp-servers/' || $mcp_server_name AS mcp_server_api_path,
    $demo_expires_on AS expires_on,
    'Next: Configure VS Code (see docs/02-VSCODE-SETUP.md)' AS next_step;


