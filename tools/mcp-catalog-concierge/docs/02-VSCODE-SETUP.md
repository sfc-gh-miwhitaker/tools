# VS Code Setup - MCP Snowflake Bridge

Author: SE Community  
Created: 2026-01-05  
Expires: 2026-02-04 (30 days)  
Status: Reference Implementation

## Overview
Snowflake-managed MCP servers are exposed over HTTP. Many VS Code MCP clients talk to MCP servers over stdio.

This demo ships a small Python bridge (`python/mcp_bridge.py`) that:
- Reads MCP JSON-RPC from stdio
- Proxies requests to Snowflake over HTTPS (Bearer PAT)
- Returns responses back to stdio

## Step 1: Install an MCP-capable VS Code client
Choose one:
- Continue (recommended): [VS Code extension](https://marketplace.visualstudio.com/items?itemName=Continue.continue) | [Docs](https://docs.continue.dev/)
- Cline: [VS Code extension](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)
- GitHub Copilot (paid) if your org already uses it

## Step 2: Create a PAT in Snowsight
Create a **Programmatic Access Token** with a least-privileged role. You’ll paste it into VS Code extension settings or into the MCP server environment config.

## Step 3: Install the bridge dependencies
From the repo root:

```bash
cd tools/mcp-catalog-concierge
python3 -m venv .venv
./.venv/bin/pip install -r python/requirements.txt
```

## Step 4: Configure your VS Code MCP client to launch the bridge (stdio)
In your VS Code MCP client configuration, add a stdio MCP server with:

- **command**: `./.venv/bin/python`
- **args**: `python/mcp_bridge.py`
- **env**:
  - `SNOWFLAKE_ACCOUNT_URL`: your account URL (for example: `https://abc12345.us-east-1.snowflakecomputing.com`)
  - `SNOWFLAKE_PAT`: the PAT created in Step 2

Optional (only if you changed defaults in SQL):
- `SNOWFLAKE_MCP_DATABASE` (default `SNOWFLAKE_EXAMPLE`)
- `SNOWFLAKE_MCP_SCHEMA` (default `MCP_SNOWFLAKE_BRIDGE`)
- `SNOWFLAKE_MCP_SERVER` (default `MCP_SNOWFLAKE_BRIDGE`)

## Step 5: Validate
In your VS Code client, confirm the tool list includes:
- `execute_sql`
- `ask_snowflake`

Try prompts like:
- “List the tables in the schema.”
- “Run a query that returns the first 10 tables in INFORMATION_SCHEMA.TABLES (explicit columns only).”

## Troubleshooting
- **401/403 from Snowflake**: PAT role is missing grants (`USAGE` on MCP server, `USAGE` on warehouse, `USAGE` on helper function).
- **Tool list fails**: ensure you deployed via `deploy_all.sql` and the MCP server exists at the expected path.
- **Client calls unsupported MCP methods**: this bridge returns empty results for `resources/list`, `prompts/list`, and `roots/list` because Snowflake-managed MCP servers only support tools.


