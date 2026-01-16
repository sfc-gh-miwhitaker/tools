/******************************************************************************
 * Tool: Cortex Cost Calculator - Quickstart Queries
 * File: quickstart_queries.sql
 * Author: SE Community
 * Created: 2026-01-16
 * Expires: 2026-02-15
 *
 * Purpose: 10 high-value ad-hoc queries for AI services cost breakdown
 *
 * Prerequisites:
 *   1. SYSADMIN role with IMPORTED PRIVILEGES on SNOWFLAKE database
 *   2. (Optional) Deploy the calculator first: deploy.sql
 *
 * How to Use:
 *   - Copy individual queries into Snowsight
 *   - Adjust date ranges as needed (default: 30 days)
 *   - All queries work standalone (no deploy.sql required)
 ******************************************************************************/

-- ============================================================================
-- QUERY 1: AI Services Total Spend Summary (Last 30 Days)
-- Quick overview of all AI services spend by service type
-- ============================================================================
SELECT
    service_type,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3.00, 2) AS estimated_cost_usd,  -- Adjust $/credit as needed
    MIN(usage_date) AS first_usage,
    MAX(usage_date) AS last_usage,
    COUNT(DISTINCT usage_date) AS active_days
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY service_type
ORDER BY total_credits DESC;


-- ============================================================================
-- QUERY 2: Top 10 Most Expensive Days (Identify Spending Spikes)
-- Find days with highest AI services consumption
-- ============================================================================
SELECT
    usage_date,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3.00, 2) AS estimated_cost_usd,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_credits,
    CASE
        WHEN DAYOFWEEK(usage_date) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY usage_date
ORDER BY total_credits DESC
LIMIT 10;


-- ============================================================================
-- QUERY 3: LLM Model Cost Comparison (Which Models Cost Most)
-- Compare spend across different LLM models (Claude, Llama, Mistral, etc.)
-- ============================================================================
SELECT
    model_name,
    function_name,
    COUNT(*) AS total_calls,
    SUM(tokens) AS total_tokens,
    SUM(token_credits) AS total_credits,
    ROUND(SUM(token_credits) * 3.00, 2) AS estimated_cost_usd,
    ROUND(
        CASE WHEN SUM(tokens) > 0
             THEN SUM(token_credits) / SUM(tokens) * 1000000
             ELSE 0
        END, 4
    ) AS credits_per_million_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY model_name, function_name
ORDER BY total_credits DESC;


-- ============================================================================
-- QUERY 4: Service-by-Service Breakdown (Analyst vs Search vs Functions)
-- Compare costs across different Cortex services
-- ============================================================================
WITH analyst AS (
    SELECT 'Cortex Analyst' AS service, SUM(credits) AS credits, SUM(request_count) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
),
search AS (
    SELECT 'Cortex Search' AS service, SUM(credits) AS credits, SUM(tokens) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
    WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE())
),
functions AS (
    SELECT 'Cortex Functions' AS service, SUM(token_credits) AS credits, SUM(tokens) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
),
doc_ai AS (
    SELECT 'Document AI' AS service, SUM(credits_used) AS credits, SUM(page_count) AS operations
    FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY
    WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
)
SELECT
    service,
    COALESCE(credits, 0) AS total_credits,
    ROUND(COALESCE(credits, 0) * 3.00, 2) AS estimated_cost_usd,
    COALESCE(operations, 0) AS total_operations,
    ROUND(
        CASE WHEN operations > 0 THEN credits / operations ELSE 0 END,
        6
    ) AS credits_per_operation
FROM (
    SELECT * FROM analyst UNION ALL
    SELECT * FROM search UNION ALL
    SELECT * FROM functions UNION ALL
    SELECT * FROM doc_ai
)
ORDER BY total_credits DESC;


-- ============================================================================
-- QUERY 5: Week-over-Week Trend Analysis (Spot Growth Patterns)
-- Compare this week vs last week spend
-- ============================================================================
WITH weekly_spend AS (
    SELECT
        DATE_TRUNC('week', usage_date) AS week_start,
        SUM(credits_used) AS weekly_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE service_type = 'AI_SERVICES'
        AND usage_date >= DATEADD('week', -8, CURRENT_DATE())
    GROUP BY DATE_TRUNC('week', usage_date)
)
SELECT
    week_start,
    weekly_credits,
    ROUND(weekly_credits * 3.00, 2) AS estimated_cost_usd,
    LAG(weekly_credits) OVER (ORDER BY week_start) AS prev_week_credits,
    ROUND(
        (weekly_credits - LAG(weekly_credits) OVER (ORDER BY week_start))
        / NULLIF(LAG(weekly_credits) OVER (ORDER BY week_start), 0) * 100,
        1
    ) AS wow_growth_pct
FROM weekly_spend
ORDER BY week_start DESC;


-- ============================================================================
-- QUERY 6: User-Level Cortex Analyst Consumption (Who's Using It Most)
-- Identify top Cortex Analyst users by credits consumed
-- ============================================================================
SELECT
    username,
    COUNT(*) AS total_requests,
    SUM(credits) AS total_credits,
    ROUND(SUM(credits) * 3.00, 2) AS estimated_cost_usd,
    MIN(DATE_TRUNC('day', start_time)) AS first_use,
    MAX(DATE_TRUNC('day', start_time)) AS last_use,
    COUNT(DISTINCT DATE_TRUNC('day', start_time)) AS active_days,
    ROUND(SUM(credits) / NULLIF(COUNT(DISTINCT DATE_TRUNC('day', start_time)), 0), 4) AS credits_per_day
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY username
ORDER BY total_credits DESC
LIMIT 20;


-- ============================================================================
-- QUERY 7: Cost Efficiency Ranking (Credits Per Million Tokens by Model)
-- Find the most cost-efficient models for your workloads
-- ============================================================================
SELECT
    model_name,
    SUM(tokens) AS total_tokens,
    SUM(token_credits) AS total_credits,
    ROUND(
        CASE WHEN SUM(tokens) > 0
             THEN SUM(token_credits) / SUM(tokens) * 1000000
             ELSE 0
        END, 4
    ) AS credits_per_million_tokens,
    ROUND(
        CASE WHEN SUM(tokens) > 0
             THEN SUM(token_credits) / SUM(tokens) * 1000000 * 3.00
             ELSE 0
        END, 2
    ) AS usd_per_million_tokens,
    COUNT(*) AS total_calls,
    ROUND(SUM(tokens) / NULLIF(COUNT(*), 0), 0) AS avg_tokens_per_call
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
    AND tokens > 0
GROUP BY model_name
HAVING SUM(tokens) > 1000  -- Filter out minimal usage
ORDER BY credits_per_million_tokens ASC;


-- ============================================================================
-- QUERY 8: Daily Run Rate and Monthly Projection (Forecasting)
-- Calculate current daily average and project monthly spend
-- ============================================================================
WITH daily_totals AS (
    SELECT
        usage_date,
        SUM(credits_used) AS daily_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE service_type = 'AI_SERVICES'
        AND usage_date >= DATEADD('day', -30, CURRENT_DATE())
        AND usage_date < CURRENT_DATE()  -- Exclude today (incomplete)
    GROUP BY usage_date
)
SELECT
    COUNT(*) AS days_analyzed,
    ROUND(AVG(daily_credits), 4) AS avg_daily_credits,
    ROUND(AVG(daily_credits) * 3.00, 2) AS avg_daily_cost_usd,
    ROUND(AVG(daily_credits) * 30, 2) AS projected_monthly_credits,
    ROUND(AVG(daily_credits) * 30 * 3.00, 2) AS projected_monthly_cost_usd,
    ROUND(AVG(daily_credits) * 365, 2) AS projected_annual_credits,
    ROUND(AVG(daily_credits) * 365 * 3.00, 2) AS projected_annual_cost_usd,
    ROUND(MIN(daily_credits), 4) AS min_daily_credits,
    ROUND(MAX(daily_credits), 4) AS max_daily_credits,
    ROUND(STDDEV(daily_credits), 4) AS stddev_daily_credits
FROM daily_totals;


-- ============================================================================
-- QUERY 9: Document AI Volume and Cost Analysis
-- Breakdown of Document AI usage by volume and cost
-- ============================================================================
SELECT
    DATE_TRUNC('day', start_time) AS usage_date,
    SUM(document_count) AS documents_processed,
    SUM(page_count) AS pages_processed,
    SUM(credits_used) AS total_credits,
    ROUND(SUM(credits_used) * 3.00, 2) AS estimated_cost_usd,
    ROUND(SUM(credits_used) / NULLIF(SUM(page_count), 0), 6) AS credits_per_page,
    ROUND(SUM(credits_used) / NULLIF(SUM(document_count), 0), 4) AS credits_per_document,
    ROUND(SUM(page_count) / NULLIF(SUM(document_count), 0), 1) AS avg_pages_per_doc
FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -30, CURRENT_DATE())
GROUP BY DATE_TRUNC('day', start_time)
HAVING SUM(credits_used) > 0
ORDER BY usage_date DESC;


-- ============================================================================
-- QUERY 10: Cost Anomaly Detection (Days with Unusual Spending)
-- Find days where spend was significantly above average
-- ============================================================================
WITH daily_stats AS (
    SELECT
        usage_date,
        SUM(credits_used) AS daily_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
    WHERE service_type = 'AI_SERVICES'
        AND usage_date >= DATEADD('day', -90, CURRENT_DATE())
    GROUP BY usage_date
),
stats AS (
    SELECT
        AVG(daily_credits) AS avg_credits,
        STDDEV(daily_credits) AS stddev_credits
    FROM daily_stats
)
SELECT
    d.usage_date,
    ROUND(d.daily_credits, 4) AS daily_credits,
    ROUND(d.daily_credits * 3.00, 2) AS estimated_cost_usd,
    ROUND(s.avg_credits, 4) AS avg_daily_credits,
    ROUND((d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0), 2) AS z_score,
    CASE
        WHEN (d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0) > 2 THEN 'HIGH ANOMALY'
        WHEN (d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0) > 1.5 THEN 'MODERATE ANOMALY'
        WHEN (d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0) < -1.5 THEN 'LOW ANOMALY'
        ELSE 'NORMAL'
    END AS anomaly_status,
    ROUND((d.daily_credits - s.avg_credits) / NULLIF(s.avg_credits, 0) * 100, 1) AS pct_above_avg
FROM daily_stats d
CROSS JOIN stats s
WHERE ABS((d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0)) > 1.5
ORDER BY ABS((d.daily_credits - s.avg_credits) / NULLIF(s.stddev_credits, 0)) DESC;


-- ============================================================================
-- BONUS: Quick Health Check (Run This First)
-- Verify you have access to the required ACCOUNT_USAGE views
-- ============================================================================
SELECT
    'METERING_DAILY_HISTORY' AS view_name,
    COUNT(*) AS row_count,
    MIN(usage_date) AS earliest_date,
    MAX(usage_date) AS latest_date
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
UNION ALL
SELECT
    'CORTEX_FUNCTIONS_USAGE_HISTORY',
    COUNT(*),
    MIN(DATE_TRUNC('day', start_time)),
    MAX(DATE_TRUNC('day', start_time))
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
UNION ALL
SELECT
    'CORTEX_ANALYST_USAGE_HISTORY',
    COUNT(*),
    MIN(DATE_TRUNC('day', start_time)),
    MAX(DATE_TRUNC('day', start_time))
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
UNION ALL
SELECT
    'CORTEX_SEARCH_DAILY_USAGE_HISTORY',
    COUNT(*),
    MIN(usage_date),
    MAX(usage_date)
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
UNION ALL
SELECT
    'DOCUMENT_AI_USAGE_HISTORY',
    COUNT(*),
    MIN(DATE_TRUNC('day', start_time)),
    MAX(DATE_TRUNC('day', start_time))
FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY
ORDER BY view_name;
