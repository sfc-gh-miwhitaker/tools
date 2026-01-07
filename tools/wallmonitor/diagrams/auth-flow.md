# Auth Flow - Wallmonitor
Author: SE Community
Last Updated: 2026-01-07
Expires: 2026-02-06 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows the privilege boundaries for deploying Wallmonitor, running ingestion, and viewing the Streamlit dashboard. Deployment bootstraps RBAC, then the owner role runs ingestion and owns objects while viewer roles have read-only access to the Streamlit app, views, and warehouse.

```mermaid
sequenceDiagram
  actor Deployer
  actor Viewer
  participant SF as Snowflake
  participant Task as REFRESH_AGENT_EVENTS_TASK
  participant Obs as GET_AI_OBSERVABILITY_EVENTS
  participant App as WALLMONITOR_DASHBOARD

  Deployer->>SF: Run deploy_sql (ACCOUNTADMIN bootstrap)
  SF-->>Deployer: Create roles and warehouse
  Deployer->>SF: Grant CORTEX_USER and EXECUTE_MANAGED_TASK to SFE_WALLMONITOR_OWNER
  SF-->>Deployer: Create schema objects owned by SFE_WALLMONITOR_OWNER

  Task->>SF: Run REFRESH_AGENT_EVENTS_proc
  Task->>Obs: Read observability events
  Obs-->>Task: Events
  Task-->>SF: Write AGENT_EVENTS_HISTORY and AGENT_EVENTS_SNAPSHOT

  Viewer->>SF: Open Snowsight Streamlit app
  Viewer->>App: Load dashboard
  App->>SF: Query views and dynamic tables
  SF-->>App: Results
  App-->>Viewer: Render KPIs tables charts
```

## Component Descriptions
- Purpose: Deployment and privilege setup
  Technology: Snowflake RBAC
  Location: `tools/wallmonitor/deploy.sql`
  Deps: Bootstrap role with ability to create roles/warehouse and grant privileges (demo uses `ACCOUNTADMIN`)
- Purpose: Observability event access
  Technology: Snowflake database role
  Location: `SNOWFLAKE.CORTEX_USER`
  Deps: Granted to the role running the ingestion task/procedure
- Purpose: Optional AI Observability event-table analytics access
  Technology: Snowflake application role
  Location: `SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP`
  Deps: Account-specific; required if enabling `SETUP_USAGE_ANALYTICS()`
- Purpose: Dashboard access
  Technology: Snowflake RBAC + Streamlit object privileges
  Location: Streamlit object in `SNOWFLAKE_EXAMPLE.WALLMONITOR`
  Deps: USAGE on database/schema/warehouse/streamlit + SELECT on views/tables (provided via `SFE_WALLMONITOR_VIEWER`)

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
