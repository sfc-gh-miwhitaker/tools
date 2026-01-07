# Network Flow - Wallmonitor
Author: SE Community
Last Updated: 2026-01-07
Expires: 2026-02-06 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows the network interactions between the user in Snowsight, the Streamlit runtime in Snowflake, and Snowflake's internal services used to fetch Cortex Agent observability events. No external services are required by default.

```mermaid
graph TB
  user[User]
  snowsight[Snowsight_UI]
  streamlitRuntime[Streamlit_Runtime]
  queryWh[SFE_WALLMONITOR_WH]
  wallmonitorSchema[SNOWFLAKE_EXAMPLE_WALLMONITOR]
  obsFn[GET_AI_OBSERVABILITY_EVENTS]
  obsTable[AI_OBSERVABILITY_EVENTS_table]
  acctMetadata[Account_Metadata]

  user -->|HTTPS_443| snowsight
  snowsight -->|Internal| streamlitRuntime
  streamlitRuntime -->|SQL_HTTPS| queryWh
  queryWh -->|SQL| wallmonitorSchema

  queryWh -->|Internal_Call| obsFn
  queryWh -->|SQL| obsTable[AI_OBSERVABILITY_EVENTS_table]
  acctMetadata -->|SHOW_AGENTS| wallmonitorSchema
```

## Component Descriptions
- Purpose: User interaction and app hosting
  Technology: Snowsight + Streamlit in Snowflake
  Location: Snowflake UI, `tools/wallmonitor/deploy.sql` (creates Streamlit object)
  Deps: User role access to the Streamlit object and query warehouse
- Purpose: Query execution
  Technology: Snowflake warehouse
  Location: `SFE_WALLMONITOR_WH` (created by `tools/wallmonitor/deploy.sql`)
  Deps: Warehouse usage grants for dashboard users (customer-specific)
- Purpose: Observability data retrieval
  Technology: `SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS`
  Location: Snowflake internal function
  Deps: `SNOWFLAKE.CORTEX_USER` database role
- Purpose: Optional usage analytics source
  Technology: `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`
  Location: Snowflake internal event table
  Deps: AI Observability lookup privileges (account-specific)

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
