# Getting Started - MCP Snowflake Bridge (VS Code)

Author: SE Community  
Created: 2026-01-05  
Expires: 2026-02-04 (30 days)  
Status: Reference Implementation

## Overview
This guide deploys a minimal Snowflake-managed MCP server and connects to it from VS Code using a local stdio-to-HTTP bridge.

## Prerequisites
- Access to a Snowflake account with permission to run deployments (this demo assumes `ACCOUNTADMIN`).
- Access to GitHub via HTTPS from Snowflake (for the Git repository object created by the deploy script).
- VS Code installed.

## Step 1: Deploy

1. In Snowsight, open a new SQL worksheet.
2. Copy/paste the contents of `tools/mcp-catalog-concierge/deploy_all.sql`.
3. Click **Run All**.
4. When finished, the final result set includes the MCP server API path.

## Step 2: Create a Programmatic Access Token (PAT)
In Snowsight, create a PAT for the role you want VS Code to use.

Important notes:
- Use a least-privileged role (not `ACCOUNTADMIN`) for the PAT.
- If you plan to use the `ask_snowflake` tool, the role needs `USAGE` on the helper function and warehouse.

## Step 3: Connect from VS Code
Follow `docs/02-VSCODE-SETUP.md`.

## Cleanup
Run `tools/mcp-catalog-concierge/sql/99_cleanup.sql` in Snowsight.

