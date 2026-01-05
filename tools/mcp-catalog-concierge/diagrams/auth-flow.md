# Auth Flow - MCP Snowflake Bridge (VS Code)
Author: SE Community
Last Updated: 2026-01-05
Expires: 2026-02-04 (30 days)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows how authentication and authorization work for a VS Code MCP client connecting to Snowflake using a Programmatic Access Token (PAT). The PAT determines the Snowflake role used for RBAC checks on the MCP server and underlying tools.

```mermaid
sequenceDiagram
  actor User
  participant Snowsight
  participant VSCode
  participant Bridge
  participant SnowflakeApi as Snowflake_API
  participant RBAC
  participant Mcp as MCP_Server
  participant Wh as Warehouse

  User->>Snowsight: Create_PAT_for_role
  Snowsight->>RBAC: Validate_user_and_role
  RBAC-->>Snowsight: PAT_issued
  Snowsight-->>User: PAT_value

  User->>VSCode: Configure_MCP_client
  User->>VSCode: Provide_env(SNOWFLAKE_ACCOUNT_URL,SNOWFLAKE_PAT)

  VSCode->>Bridge: MCP_request_over_stdio
  Bridge->>SnowflakeApi: POST_MCP_request_with_Bearer_PAT
  SnowflakeApi->>RBAC: Validate_PAT_and_resolve_role
  RBAC-->>SnowflakeApi: Role_context

  SnowflakeApi->>Mcp: Dispatch_to_tool
  Mcp->>RBAC: Check_USAGE_on_MCP_SERVER
  RBAC-->>Mcp: Allowed_or_denied

  Mcp->>RBAC: Check_tool_privileges
  RBAC-->>Mcp: Allowed_or_denied

  Mcp->>Wh: Execute_tool_in_warehouse
  Wh-->>Mcp: Results
  Mcp-->>SnowflakeApi: MCP_response
  SnowflakeApi-->>Bridge: JSON_RPC_response
  Bridge-->>VSCode: MCP_response_over_stdio
```

## Component Descriptions
- Snowsight
  - Purpose: UI to create Programmatic Access Tokens (PAT)
  - Technology: Snowflake web UI
  - Location: Snowflake account
  - Deps: User privileges to create PATs

- Python_Bridge
  - Purpose: Forwards MCP calls from VS Code (stdio) to Snowflake (HTTPS)
  - Technology: Python
  - Location: `tools/mcp-catalog-concierge/python/mcp_bridge.py`
  - Deps: PAT stored outside the repo (env var)

- MCP_Server
  - Purpose: Defines MCP tool catalog and routes tool calls
  - Technology: Snowflake-managed MCP server object
  - Location: `SNOWFLAKE_EXAMPLE.MCP_SNOWFLAKE_BRIDGE.MCP_SNOWFLAKE_BRIDGE`
  - Deps: RBAC grants on MCP server + underlying tools

- RBAC
  - Purpose: Enforces authorization at MCP server and tool levels
  - Technology: Snowflake RBAC
  - Location: Snowflake control plane
  - Deps: Role grants for MCP server, warehouse, function, and queried objects

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.


