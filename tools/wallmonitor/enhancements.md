# Wallmonitor: Roadmap and Enhancements

This document tracks future enhancements for Wallmonitor beyond the current reference implementation. It is intentionally concise and aligned with the current `deploy.sql` architecture.

## Current Implementation (Reference)
- **Realtime monitoring**: serverless task runs every 10 minutes and refreshes:
  - `AGENT_EVENTS_HISTORY` (recent history, default 30 days)
  - `AGENT_EVENTS_SNAPSHOT` (realtime snapshot window, default 24 hours)
- **Dashboards**:
  - Realtime views: `REALTIME_KPI`, `THREAD_ACTIVITY`, `AGENT_METRICS`, `HOURLY_THREAD_ACTIVITY`, `THREAD_TIMELINE`
  - Recent-history views: `*_RECENT` backed by dynamic tables (`DT_*_RECENT`)
- **Streamlit**: `WALLMONITOR_DASHBOARD` is a multi-page Streamlit-in-Snowflake app, deployed by `deploy.sql`
- **RBAC**:
  - `SFE_WALLMONITOR_OWNER` owns Wallmonitor objects and runs ingestion
  - `SFE_WALLMONITOR_VIEWER` has read-only dashboard access
- **Optional usage analytics**:
  - `SETUP_USAGE_ANALYTICS(DAYS_BACK)` can create request-level rollups derived from `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS` (requires AI Observability lookup privileges)

## Enhancement Backlog

### 1. Long-term analytics (90+ days) with aggregated tables
Goal: keep `AGENT_EVENTS_HISTORY` at 7-30 days for “recent” dashboards and store older history as low-cost aggregates.
- Add daily rollups (per agent, per user) in standard tables.
- Add tasks to refresh daily rollups and retain 12+ months.

### 2. Cost tracking and chargeback
Goal: show estimated cost/credits for agent traffic and enable chargeback by team/agent/user.
- Join request-level events to usage/cost sources where possible.
- Provide conservative estimation when exact joins are not possible.

### 3. Alerting and anomaly detection
Goal: proactive detection of regressions and operational issues.
- Add detection tasks for:
  - High error rate per agent
  - High latency per agent (p95/p99)
  - Token spikes / runaway threads
- Integrate with notification integrations (email/webhook) where appropriate.

### 4. Organization-wide monitoring (multi-account)
Goal: unify monitoring across multiple Snowflake accounts.
- Share rollups or recent history to a central monitoring account.
- Add a `source_account` dimension and unify via views.

### 5. Streamlit Git integration
Goal: improve day-2 operations for teams using Snowflake Git integration.
- Create Streamlit objects from a Snowflake Git repository path (no stage upload).
- Enable multi-file editing + version control workflows.

### 6. Direct ingest from AI observability event table (scale optimization)
Goal: reduce per-agent polling overhead for very large deployments.
- Ingest from `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS` when available instead of calling `GET_AI_OBSERVABILITY_EVENTS()` per agent.
- Reuse the usage-analytics parsing logic and retain the existing pipeline as a fallback.
