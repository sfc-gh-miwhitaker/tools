# Data Model - Wallmonitor
Author: SE Community
Last Updated: 2026-01-07
Expires: 2026-02-06 (30 days from creation)
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview
This diagram describes the core relational objects in `SNOWFLAKE_EXAMPLE.WALLMONITOR` used to monitor Cortex Agent observability events. It covers the agent registry, incremental ingest state, retained event history, and the realtime snapshot window used by dashboard views.

```mermaid
erDiagram
  AGENT_REGISTRY ||--|| AGENT_INGEST_STATE : "tracks_watermark_for"
  AGENT_REGISTRY ||--o{ AGENT_EVENTS_HISTORY : "monitors"
  AGENT_REGISTRY ||--o{ AGENT_EVENTS_SNAPSHOT : "monitors"

  AGENT_REGISTRY {
    string agent_database PK
    string agent_schema PK
    string agent_name PK
    boolean is_active
    string include_pattern
    string exclude_pattern
    timestamp_ltz added_at
    timestamp_ltz last_discovered
    string notes
  }

  AGENT_INGEST_STATE {
    string agent_database PK
    string agent_schema PK
    string agent_name PK
    timestamp_ltz last_event_timestamp
    timestamp_ltz last_refresh_at
    string last_refresh_status
    string last_error_message
  }

  AGENT_EVENTS_HISTORY {
    string agent_database FK
    string agent_schema FK
    string agent_name FK
    timestamp_ltz event_timestamp
    string event_name
    string span_name
    string span_id
    string trace_id
    string agent_id
    string thread_id
    string user_id
    string model_name
    number prompt_tokens
    number completion_tokens
    number total_tokens
    number span_duration_ms
    string tool_name
    string retrieval_query
    string status
    string error_message
    variant raw_attributes
    timestamp_ltz loaded_at
  }

  AGENT_EVENTS_SNAPSHOT {
    string agent_database FK
    string agent_schema FK
    string agent_name FK
    timestamp_ltz event_timestamp
    string event_name
    string span_name
    string span_id
    string trace_id
    string agent_id
    string thread_id
    string user_id
    string model_name
    number prompt_tokens
    number completion_tokens
    number total_tokens
    number span_duration_ms
    string tool_name
    string retrieval_query
    string status
    string error_message
    variant raw_attributes
    timestamp_ltz loaded_at
  }
```

## Component Descriptions
- Purpose: Agent registry for monitoring scope
  Technology: Snowflake table
  Location: `tools/wallmonitor/deploy.sql`
  Deps: `SHOW AGENTS IN ACCOUNT` privileges for discovery
- Purpose: Incremental ingest watermark and status per agent
  Technology: Snowflake table
  Location: `tools/wallmonitor/deploy.sql`
  Deps: `REFRESH_AGENT_EVENTS()` procedure
- Purpose: Retained recent history used by dynamic tables (7-30 days)
  Technology: Snowflake table
  Location: `tools/wallmonitor/deploy.sql`
  Deps: `SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS()`
- Purpose: Realtime snapshot window used by realtime views
  Technology: Snowflake table
  Location: `tools/wallmonitor/deploy.sql`
  Deps: History retention window and refresh task

## Change History
See `.cursor/DIAGRAM_CHANGELOG.md` for vhistory.
