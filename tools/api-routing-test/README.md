# API Routing Test - Cortex Agent `agent:run` (Generic)
Author: SE Community
Last Updated: 2026-01-08

This folder contains a `curl` command you can use to call **any** Snowflake Cortex Agent `agent:run` endpoint and optionally override the caller's **default role** and **default warehouse** per request.

## What this calls

- **Endpoint**: `POST /api/v2/databases/{database}/schemas/{schema}/agents/{name}:run`

## Required environment variables

- `SNOWFLAKE_ACCOUNT_BASE_URL` (example: `https://<account_identifier>.snowflakecomputing.com`)
- `SNOWFLAKE_PAT` (Programmatic Access Token)
- `AGENT_DATABASE`
- `AGENT_SCHEMA`
- `AGENT_NAME`

Optional (overrides caller defaults for this request):

- `SNOWFLAKE_ROLE`
- `SNOWFLAKE_WAREHOUSE`

## Usage

Run the command in `tools/api-routing-test/agent_run.sh` after setting env vars.

Example (no overrides; uses caller defaults):

```bash
export SNOWFLAKE_ACCOUNT_BASE_URL="https://<account_identifier>.snowflakecomputing.com"
export SNOWFLAKE_PAT="..."
export AGENT_DATABASE="SNOWFLAKE_EXAMPLE"
export AGENT_SCHEMA="SAM_THE_SNOWMAN"
export AGENT_NAME="SAM_THE_SNOWMAN"

bash tools/api-routing-test/agent_run.sh
```

Example (override role + warehouse for this request):

```bash
export SNOWFLAKE_ROLE="SYSADMIN"
export SNOWFLAKE_WAREHOUSE="SFE_SAM_SNOWMAN_WH"

bash tools/api-routing-test/agent_run.sh
```

## Notes / gotchas

- Role/warehouse override is done via request headers:
  - `X-Snowflake-Role`
  - `X-Snowflake-Warehouse`
- With PAT auth, the requested role must be allowed by the PAT's role restriction.
- The selected role must have:
  - `USAGE` on the agent `{database}.{schema}.{name}`
  - `USAGE` on the specified warehouse (if you pass `--warehouse`)
