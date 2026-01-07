# Data Flow - Wallmonitor
Author: SE Community
Last Updated: 2026-01-07
Expires: 2026-02-06 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram shows how Cortex Agent observability events are discovered and ingested into Snowflake tables, then transformed into realtime and recent-history rollups consumed by a Streamlit-in-Snowflake dashboard.

```mermaid
graph TB
  subgraph sources [Sources]
    showAgents[SHOW_AGENTS_IN_ACCOUNT]
    obsEvents[GET_AI_OBSERVABILITY_EVENTS]
    obsTable[AI_OBSERVABILITY_EVENTS_table]
  end

  subgraph controlPlane [Control_Plane]
    discoverProc[DISCOVER_AGENTS_proc]
    registry[(AGENT_REGISTRY)]
  end

  subgraph ingest [Ingest]
    refreshTask[REFRESH_AGENT_EVENTS_TASK]
    refreshProc[REFRESH_AGENT_EVENTS_proc]
    ingestState[(AGENT_INGEST_STATE)]
  end

  subgraph storage [Storage]
    hist[(AGENT_EVENTS_HISTORY)]
    snap[(AGENT_EVENTS_SNAPSHOT)]
  end

  subgraph rollups [Rollups]
    dtThreads[(DT_THREAD_ACTIVITY_RECENT)]
    dtAgents[(DT_AGENT_METRICS_RECENT)]
    dtHourly[(DT_HOURLY_THREAD_ACTIVITY_RECENT)]
    dtUsageUser[(DT_AGENT_USAGE_BY_USER)]
    dtUsageAgent[(DT_AGENT_USAGE_BY_AGENT)]
  end

  subgraph views [Views]
    realtimeViews[Realtime_Views]
    recentViews[Recent_Views]
    usageViews[Usage_Views]
  end

  subgraph ui [UI]
    streamlit[WALLMONITOR_DASHBOARD_Streamlit]
  end

  showAgents --> discoverProc --> registry
  registry --> refreshProc
  refreshTask --> refreshProc
  obsEvents --> refreshProc
  refreshProc --> ingestState
  refreshProc --> hist
  refreshProc --> snap

  hist --> dtThreads
  hist --> dtAgents
  hist --> dtHourly

  obsTable --> dtUsageUser
  dtUsageUser --> dtUsageAgent

  snap --> realtimeViews
  hist --> recentViews
  dtThreads --> recentViews
  dtAgents --> recentViews
  dtHourly --> recentViews

  dtUsageUser --> usageViews
  dtUsageAgent --> usageViews

  realtimeViews --> streamlit
  recentViews --> streamlit
  usageViews --> streamlit
```

## Component Descriptions
- Purpose: Agent discovery and registration
  Technology: `SHOW AGENTS` + SQL stored procedure
  Location: `tools/wallmonitor/deploy.sql` (`DISCOVER_AGENTS`)
  Deps: Privileges to enumerate agents and write registry table
- Purpose: Incremental ingest and snapshot rebuild
  Technology: Serverless task + SQL procedure
  Location: `tools/wallmonitor/deploy.sql` (`REFRESH_AGENT_EVENTS_TASK`, `REFRESH_AGENT_EVENTS`)
  Deps: `SNOWFLAKE.CORTEX_USER` database role
- Purpose: Recent-history rollups for dashboards
  Technology: Dynamic Tables
  Location: `tools/wallmonitor/deploy.sql` (`DT_*_RECENT`)
  Deps: `SFE_WALLMONITOR_WH` warehouse
- Purpose: Optional usage analytics (per-user / per-agent request metrics)
  Technology: Dynamic Tables derived from `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`
  Location: `tools/wallmonitor/deploy.sql` (`SETUP_USAGE_ANALYTICS`, `DT_AGENT_USAGE_*`)
  Deps: AI Observability lookup privileges (account-specific)
- Purpose: Dashboard UI
  Technology: Streamlit in Snowflake
  Location: `tools/wallmonitor/deploy.sql` (uploads multi-page Streamlit source to stage and creates `WALLMONITOR_DASHBOARD`)
  Deps: Query warehouse and SELECT on views

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
