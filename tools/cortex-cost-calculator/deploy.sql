/******************************************************************************
 * Tool: Cortex Cost Calculator
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-10
 * Expires: 2026-01-09
 *
 * Purpose: Monitor Cortex AI service costs and forecast future spend
 *
 * Prerequisites:
 *   1. SYSADMIN role (ACCOUNTADMIN not required!)
 *   2. IMPORTED PRIVILEGES on SNOWFLAKE database (for ACCOUNT_USAGE)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *   3. Navigate to: Projects -> Streamlit -> SFE_CORTEX_CALCULATOR
 *
 * Objects Created:
 *   - Schema: SFE_CORTEX_CALC
 *   - 8 monitoring views (V_CORTEX_*)
 *   - 1 snapshot table
 *   - 1 serverless task (daily 3AM)
 *   - 1 Streamlit app
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK
-- ============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-01-09';
    tool_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-01-09. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE tool_expired;
    END IF;
    RETURN 'Expiration check passed. Tool valid until ' || v_expiration_date::STRING;
END;
$$;

-- ============================================================================
-- CONTEXT SETTING
-- ============================================================================
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects | Author: SE Community';

USE DATABASE SNOWFLAKE_EXAMPLE;

CREATE SCHEMA IF NOT EXISTS SFE_CORTEX_CALC
    COMMENT = 'TOOL: Cortex AI cost monitoring and forecasting (Expires: 2026-01-09)';

USE SCHEMA SFE_CORTEX_CALC;

-- ============================================================================
-- MONITORING VIEWS (Query ACCOUNT_USAGE)
-- ============================================================================

-- View 1: Cortex Analyst Usage
CREATE OR REPLACE VIEW V_CORTEX_ANALYST_DETAIL
    COMMENT = 'TOOL: Cortex Analyst per-request usage | Expires: 2026-01-09'
AS
SELECT 
    'Cortex Analyst' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    username,
    credits,
    request_count
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_ANALYST_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 2: Cortex Search Usage
CREATE OR REPLACE VIEW V_CORTEX_SEARCH_DETAIL
    COMMENT = 'TOOL: Cortex Search daily usage | Expires: 2026-01-09'
AS
SELECT 
    'Cortex Search' AS service_type,
    usage_date,
    service_name,
    credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_SEARCH_DAILY_USAGE_HISTORY
WHERE usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 3: Cortex Functions Usage (LLM calls)
CREATE OR REPLACE VIEW V_CORTEX_FUNCTIONS_DETAIL
    COMMENT = 'TOOL: Cortex LLM functions hourly usage | Expires: 2026-01-09'
AS
SELECT 
    'Cortex Functions' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    function_name,
    model_name,
    token_credits,
    tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 4: Document AI Usage
CREATE OR REPLACE VIEW V_DOCUMENT_AI_DETAIL
    COMMENT = 'TOOL: Document AI processing usage | Expires: 2026-01-09'
AS
SELECT 
    'Document AI' AS service_type,
    DATE_TRUNC('day', start_time) AS usage_date,
    credits_used,
    page_count,
    document_count
FROM SNOWFLAKE.ACCOUNT_USAGE.DOCUMENT_AI_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP());

-- View 5: Function Summary (for model comparison)
CREATE OR REPLACE VIEW V_CORTEX_FUNCTION_SUMMARY
    COMMENT = 'TOOL: LLM function/model cost analysis | Expires: 2026-01-09'
AS
SELECT 
    function_name,
    model_name,
    COUNT(*) AS call_count,
    SUM(token_credits) AS total_credits,
    SUM(tokens) AS total_tokens,
    CASE WHEN SUM(tokens) > 0 THEN SUM(token_credits) / SUM(tokens) * 1000000 ELSE 0 END AS cost_per_million_tokens
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_FUNCTIONS_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -90, CURRENT_TIMESTAMP())
GROUP BY function_name, model_name
ORDER BY total_credits DESC;

-- View 6: Daily Summary (Master Rollup)
CREATE OR REPLACE VIEW V_CORTEX_DAILY_SUMMARY
    COMMENT = 'TOOL: Master daily rollup across all Cortex services | Expires: 2026-01-09'
AS
WITH all_services AS (
    SELECT usage_date, service_type, COUNT(DISTINCT username) AS users, SUM(request_count) AS operations, SUM(credits) AS credits
    FROM V_CORTEX_ANALYST_DETAIL GROUP BY usage_date, service_type
    UNION ALL
    SELECT usage_date, service_type, 0 AS users, SUM(tokens) AS operations, SUM(credits) AS credits
    FROM V_CORTEX_SEARCH_DETAIL GROUP BY usage_date, service_type
    UNION ALL
    SELECT usage_date, service_type, 0 AS users, SUM(tokens) AS operations, SUM(token_credits) AS credits
    FROM V_CORTEX_FUNCTIONS_DETAIL GROUP BY usage_date, service_type
    UNION ALL
    SELECT usage_date, service_type, 0 AS users, SUM(page_count) AS operations, SUM(credits_used) AS credits
    FROM V_DOCUMENT_AI_DETAIL GROUP BY usage_date, service_type
)
SELECT 
    usage_date,
    service_type,
    SUM(users) AS daily_unique_users,
    SUM(operations) AS total_operations,
    SUM(credits) AS total_credits,
    CASE WHEN SUM(users) > 0 THEN SUM(credits) / SUM(users) ELSE 0 END AS credits_per_user
FROM all_services
GROUP BY usage_date, service_type
ORDER BY usage_date DESC, total_credits DESC;

-- View 7: Cost Export (Calculator format)
CREATE OR REPLACE VIEW V_CORTEX_COST_EXPORT
    COMMENT = 'TOOL: Export-ready format for cost calculator | Expires: 2026-01-09'
AS
SELECT 
    usage_date AS date,
    service_type,
    daily_unique_users,
    total_operations,
    total_credits,
    credits_per_user,
    ROUND(credits_per_user * 30, 2) AS projected_monthly_credits
FROM V_CORTEX_DAILY_SUMMARY
ORDER BY date DESC;

-- View 8: AI Services Metering
CREATE OR REPLACE VIEW V_METERING_AI_SERVICES
    COMMENT = 'TOOL: High-level AI services metering | Expires: 2026-01-09'
AS
SELECT 
    usage_date,
    SUM(credits_used) AS total_credits,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE service_type = 'AI_SERVICES'
    AND usage_date >= DATEADD('day', -90, CURRENT_TIMESTAMP())
GROUP BY usage_date
ORDER BY usage_date DESC;

-- ============================================================================
-- SNAPSHOT TABLE (For faster queries)
-- ============================================================================
CREATE TABLE IF NOT EXISTS SFE_CORTEX_SNAPSHOTS (
    snapshot_date DATE,
    service_type VARCHAR(50),
    usage_date DATE,
    daily_unique_users NUMBER,
    total_operations NUMBER,
    total_credits NUMBER(38,6),
    inserted_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'TOOL: Daily usage snapshots for fast queries | Expires: 2026-01-09';

-- ============================================================================
-- SERVERLESS TASK (Daily snapshot at 3AM)
-- ============================================================================
CREATE OR REPLACE TASK SFE_DAILY_SNAPSHOT_TASK
    SCHEDULE = 'USING CRON 0 3 * * * America/Los_Angeles'
    USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
    COMMENT = 'TOOL: Daily Cortex usage snapshot (3AM Pacific) | Expires: 2026-01-09'
AS
MERGE INTO SFE_CORTEX_SNAPSHOTS AS target
USING (
    SELECT CURRENT_DATE() AS snapshot_date, service_type, usage_date, daily_unique_users, total_operations, total_credits
    FROM V_CORTEX_DAILY_SUMMARY WHERE usage_date >= DATEADD('day', -2, CURRENT_DATE())
) AS source
ON target.snapshot_date = source.snapshot_date AND target.service_type = source.service_type AND target.usage_date = source.usage_date
WHEN MATCHED THEN UPDATE SET total_credits = source.total_credits, inserted_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (snapshot_date, service_type, usage_date, daily_unique_users, total_operations, total_credits)
    VALUES (source.snapshot_date, source.service_type, source.usage_date, source.daily_unique_users, source.total_operations, source.total_credits);

ALTER TASK SFE_DAILY_SNAPSHOT_TASK RESUME;

-- ============================================================================
-- STREAMLIT APP
-- ============================================================================
CREATE OR REPLACE STAGE SFE_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'TOOL: Streamlit app files | Expires: 2026-01-09';

CREATE OR REPLACE STREAMLIT SFE_CORTEX_CALCULATOR
    ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC.SFE_STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    TITLE = 'Cortex Cost Calculator'
    PACKAGES = ('snowflake-snowpark-python', 'plotly', 'pandas', 'numpy')
    COMMENT = 'TOOL: Cortex Cost Calculator | Expires: 2026-01-09';

-- Upload Streamlit app
CREATE OR REPLACE PROCEDURE SFE_SETUP_CALCULATOR()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'setup'
AS
$$
from io import BytesIO

def setup(session):
    code = '''
import streamlit as st
import pandas as pd
import numpy as np
from datetime import datetime
from snowflake.snowpark.context import get_active_session
import plotly.express as px
import plotly.graph_objects as go

session = get_active_session()

st.set_page_config(page_title="Cortex Cost Calculator", page_icon="📊", layout="wide")

st.title("📊 Cortex Cost Calculator")
st.caption("Monitor Cortex AI costs and forecast future spend | SE Community")

# Sidebar
with st.sidebar:
    st.header("Settings")
    credit_cost = st.number_input("$/credit", 1.0, 10.0, 3.0, 0.5)
    lookback = st.slider("Days of history", 7, 90, 30)
    
    if st.button("Refresh Data"):
        st.cache_data.clear()

# Load data
@st.cache_data(ttl=300)
def load_data(days):
    query = f"""
    SELECT date, service_type, daily_unique_users, total_operations, total_credits, credits_per_user
    FROM SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC.V_CORTEX_COST_EXPORT
    WHERE date >= DATEADD(day, -{days}, CURRENT_DATE())
    """
    return session.sql(query).to_pandas()

@st.cache_data(ttl=300)
def load_function_summary():
    return session.sql("SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_CORTEX_CALC.V_CORTEX_FUNCTION_SUMMARY").to_pandas()

df = load_data(lookback)
func_df = load_function_summary()

if df.empty:
    st.warning("No Cortex usage data found. Start using Cortex services to see data here!")
    st.stop()

df.columns = df.columns.str.upper()

# Tab layout
tab1, tab2, tab3 = st.tabs(["📈 Historical Analysis", "🤖 Model Costs", "🔮 Projections"])

with tab1:
    st.header("Historical Usage")
    
    total_credits = df["TOTAL_CREDITS"].sum()
    total_cost = total_credits * credit_cost
    avg_daily = df.groupby("DATE")["TOTAL_CREDITS"].sum().mean()
    
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Credits", f"{total_credits:,.0f}")
    c2.metric("Total Cost", f"${total_cost:,.2f}")
    c3.metric("Avg Daily Credits", f"{avg_daily:,.1f}")
    c4.metric("Services Active", df["SERVICE_TYPE"].nunique())
    
    st.divider()
    
    # Service breakdown
    service_agg = df.groupby("SERVICE_TYPE").agg({"TOTAL_CREDITS": "sum"}).reset_index()
    service_agg["COST_USD"] = service_agg["TOTAL_CREDITS"] * credit_cost
    
    c1, c2 = st.columns([2, 1])
    with c1:
        fig = px.line(df.groupby(["DATE", "SERVICE_TYPE"])["TOTAL_CREDITS"].sum().reset_index(),
                      x="DATE", y="TOTAL_CREDITS", color="SERVICE_TYPE", title="Daily Credits by Service")
        st.plotly_chart(fig, use_container_width=True)
    with c2:
        fig = px.pie(service_agg, values="TOTAL_CREDITS", names="SERVICE_TYPE", title="Credit Distribution")
        st.plotly_chart(fig, use_container_width=True)
    
    st.dataframe(service_agg.style.format({"TOTAL_CREDITS": "{:,.0f}", "COST_USD": "${:,.2f}"}), use_container_width=True)

with tab2:
    st.header("LLM Model Costs")
    
    if func_df.empty:
        st.info("No LLM function usage found yet.")
    else:
        func_df.columns = func_df.columns.str.upper()
        func_df["COST_USD"] = func_df["TOTAL_CREDITS"] * credit_cost
        
        c1, c2 = st.columns(4)[:2]
        c1.metric("Models Used", func_df["MODEL_NAME"].nunique())
        c2.metric("Total LLM Calls", f"{func_df['CALL_COUNT'].sum():,.0f}")
        
        st.divider()
        
        # Model comparison
        model_agg = func_df.groupby("MODEL_NAME").agg({
            "CALL_COUNT": "sum", "TOTAL_CREDITS": "sum", "TOTAL_TOKENS": "sum"
        }).reset_index()
        model_agg["COST_USD"] = model_agg["TOTAL_CREDITS"] * credit_cost
        model_agg["$/M TOKENS"] = model_agg.apply(
            lambda r: (r["TOTAL_CREDITS"] / r["TOTAL_TOKENS"] * 1e6 * credit_cost) if r["TOTAL_TOKENS"] > 0 else 0, axis=1
        )
        
        fig = px.bar(model_agg.sort_values("TOTAL_CREDITS", ascending=False).head(10),
                     x="MODEL_NAME", y="TOTAL_CREDITS", title="Top Models by Credit Usage")
        st.plotly_chart(fig, use_container_width=True)
        
        st.dataframe(model_agg.sort_values("TOTAL_CREDITS", ascending=False).style.format({
            "CALL_COUNT": "{:,.0f}", "TOTAL_CREDITS": "{:.4f}", "COST_USD": "${:,.2f}",
            "TOTAL_TOKENS": "{:,.0f}", "$/M TOKENS": "${:,.2f}"
        }), use_container_width=True)

with tab3:
    st.header("Cost Projections")
    
    c1, c2 = st.columns(2)
    months = c1.slider("Projection months", 3, 24, 12)
    growth = c2.slider("Monthly growth %", 0, 100, 25) / 100
    
    baseline = df.groupby("DATE")["TOTAL_CREDITS"].sum().mean()
    
    projections = []
    for m in range(1, months + 1):
        monthly = baseline * 30 * ((1 + growth) ** m)
        projections.append({"Month": m, "Credits": monthly, "Cost": monthly * credit_cost})
    
    proj_df = pd.DataFrame(projections)
    total_year = proj_df[proj_df["Month"] <= 12]["Cost"].sum()
    
    c1, c2, c3 = st.columns(3)
    c1.metric("Month 1 Cost", f"${proj_df.iloc[0]['Cost']:,.0f}")
    c2.metric("Month 12 Cost", f"${proj_df[proj_df['Month']==12]['Cost'].iloc[0]:,.0f}" if len(proj_df) >= 12 else "N/A")
    c3.metric("Year 1 Total", f"${total_year:,.0f}")
    
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=proj_df["Month"], y=proj_df["Cost"], mode="lines+markers", name="Projected"))
    fig.add_trace(go.Scatter(x=proj_df["Month"], y=proj_df["Cost"] * 0.9, mode="lines", name="Low (-10%)", line=dict(dash="dot")))
    fig.add_trace(go.Scatter(x=proj_df["Month"], y=proj_df["Cost"] * 1.1, mode="lines", name="High (+10%)", line=dict(dash="dot")))
    fig.update_layout(title="Cost Projection", xaxis_title="Month", yaxis_title="Cost (USD)")
    st.plotly_chart(fig, use_container_width=True)
    
    st.dataframe(proj_df.style.format({"Credits": "{:,.0f}", "Cost": "${:,.2f}"}), use_container_width=True)

st.divider()
st.caption("Cortex Cost Calculator | SE Community | Data from ACCOUNT_USAGE (45min-3hr latency)")
'''
    
    session.file.put_stream(BytesIO(code.encode('utf-8')), '@SFE_STREAMLIT_STAGE/app.py', auto_compress=False, overwrite=True)
    return "Calculator app uploaded"
$$;

CALL SFE_SETUP_CALCULATOR();
ALTER STAGE SFE_STREAMLIT_STAGE REFRESH;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Cost Calculator' AS tool,
    '2026-01-09' AS expires,
    'Navigate to Projects -> Streamlit -> SFE_CORTEX_CALCULATOR' AS next_step;

