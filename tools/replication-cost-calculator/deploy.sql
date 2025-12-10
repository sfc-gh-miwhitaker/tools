/******************************************************************************
 * Tool: Replication / DR Cost Calculator
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-10
 * Expires: 2026-01-09
 *
 * Prerequisites:
 *   1. SYSADMIN role access
 *   2. Access to ACCOUNT_USAGE views (for database sizes)
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 *
 * Updating Pricing:
 *   To update rates, modify the SFE_PRICING table directly:
 *   UPDATE SFE_PRICING SET RATE = 2.75 WHERE SERVICE_TYPE = 'DATA_TRANSFER' AND CLOUD = 'AWS';
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

-- Create shared warehouse if needed
CREATE WAREHOUSE IF NOT EXISTS SFE_TOOLS_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE
    COMMENT = 'Shared warehouse for Snowflake Tools Collection | Author: SE Community';

USE WAREHOUSE SFE_TOOLS_WH;

-- Create database if needed
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE
    COMMENT = 'Shared database for SE demonstration projects | Author: SE Community';

USE DATABASE SNOWFLAKE_EXAMPLE;

-- Create schema
CREATE SCHEMA IF NOT EXISTS SFE_REPLICATION_CALC
    COMMENT = 'TOOL: Replication/DR cost calculator (Expires: 2026-01-09)';

USE SCHEMA SFE_REPLICATION_CALC;

-- ============================================================================
-- PRICING TABLE (Edit this table to update rates)
-- ============================================================================
CREATE OR REPLACE TABLE SFE_PRICING (
    SERVICE_TYPE STRING,
    CLOUD STRING,
    REGION STRING,
    RATE NUMBER(10,4),
    UNIT STRING,
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'TOOL: Replication pricing rates - edit directly to update | Expires: 2026-01-09';

-- Seed pricing data (Business Critical rates as of Dec 2025)
INSERT INTO SFE_PRICING (SERVICE_TYPE, CLOUD, REGION, RATE, UNIT) VALUES
    -- AWS
    ('DATA_TRANSFER', 'AWS', 'us-east-1', 2.50, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AWS', 'us-east-1', 1.00, 'credits/TB'),
    ('STORAGE', 'AWS', 'us-east-1', 0.25, 'credits/TB/month'),
    ('SERVERLESS', 'AWS', 'us-east-1', 0.10, 'credits/TB/month'),
    ('DATA_TRANSFER', 'AWS', 'us-west-2', 2.50, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AWS', 'us-west-2', 1.00, 'credits/TB'),
    ('STORAGE', 'AWS', 'us-west-2', 0.25, 'credits/TB/month'),
    ('SERVERLESS', 'AWS', 'us-west-2', 0.10, 'credits/TB/month'),
    ('DATA_TRANSFER', 'AWS', 'eu-west-1', 2.50, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AWS', 'eu-west-1', 1.00, 'credits/TB'),
    ('STORAGE', 'AWS', 'eu-west-1', 0.25, 'credits/TB/month'),
    ('SERVERLESS', 'AWS', 'eu-west-1', 0.10, 'credits/TB/month'),
    ('DATA_TRANSFER', 'AWS', 'ap-southeast-1', 2.50, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AWS', 'ap-southeast-1', 1.00, 'credits/TB'),
    ('STORAGE', 'AWS', 'ap-southeast-1', 0.25, 'credits/TB/month'),
    ('SERVERLESS', 'AWS', 'ap-southeast-1', 0.10, 'credits/TB/month'),
    -- Azure
    ('DATA_TRANSFER', 'AZURE', 'eastus2', 2.70, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AZURE', 'eastus2', 1.10, 'credits/TB'),
    ('STORAGE', 'AZURE', 'eastus2', 0.27, 'credits/TB/month'),
    ('SERVERLESS', 'AZURE', 'eastus2', 0.12, 'credits/TB/month'),
    ('DATA_TRANSFER', 'AZURE', 'westus2', 2.70, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westus2', 1.10, 'credits/TB'),
    ('STORAGE', 'AZURE', 'westus2', 0.27, 'credits/TB/month'),
    ('SERVERLESS', 'AZURE', 'westus2', 0.12, 'credits/TB/month'),
    ('DATA_TRANSFER', 'AZURE', 'westeurope', 2.70, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'AZURE', 'westeurope', 1.10, 'credits/TB'),
    ('STORAGE', 'AZURE', 'westeurope', 0.27, 'credits/TB/month'),
    ('SERVERLESS', 'AZURE', 'westeurope', 0.12, 'credits/TB/month'),
    -- GCP
    ('DATA_TRANSFER', 'GCP', 'us-central1', 2.60, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'GCP', 'us-central1', 1.05, 'credits/TB'),
    ('STORAGE', 'GCP', 'us-central1', 0.26, 'credits/TB/month'),
    ('SERVERLESS', 'GCP', 'us-central1', 0.11, 'credits/TB/month'),
    ('DATA_TRANSFER', 'GCP', 'europe-west1', 2.60, 'credits/TB'),
    ('REPLICATION_COMPUTE', 'GCP', 'europe-west1', 1.05, 'credits/TB'),
    ('STORAGE', 'GCP', 'europe-west1', 0.26, 'credits/TB/month'),
    ('SERVERLESS', 'GCP', 'europe-west1', 0.11, 'credits/TB/month');

-- ============================================================================
-- DATABASE METADATA VIEW
-- ============================================================================
CREATE OR REPLACE VIEW SFE_DB_METADATA
COMMENT = 'TOOL: Database sizes from ACCOUNT_USAGE | Expires: 2026-01-09'
AS
SELECT
    d.DATABASE_NAME,
    COALESCE(s.SIZE_TB, 0.001) AS SIZE_TB
FROM (
    SELECT DATABASE_NAME
    FROM SNOWFLAKE.INFORMATION_SCHEMA.DATABASES
    WHERE DATABASE_NAME NOT IN ('SNOWFLAKE', 'SNOWFLAKE_SAMPLE_DATA')
) d
LEFT JOIN (
    SELECT TABLE_CATALOG AS DATABASE_NAME, 
           SUM(ACTIVE_BYTES) / POWER(1024, 4) AS SIZE_TB
    FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
    GROUP BY TABLE_CATALOG
) s ON d.DATABASE_NAME = s.DATABASE_NAME
ORDER BY d.DATABASE_NAME;

-- ============================================================================
-- STREAMLIT APP
-- ============================================================================
CREATE OR REPLACE STAGE SFE_STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'TOOL: Streamlit app files | Expires: 2026-01-09';

CREATE OR REPLACE STREAMLIT SFE_REPLICATION_CALCULATOR
    ROOT_LOCATION = '@SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_STREAMLIT_STAGE'
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = SFE_TOOLS_WH
    COMMENT = 'TOOL: Replication/DR Cost Calculator | Expires: 2026-01-09';

-- Upload Streamlit app
CREATE OR REPLACE PROCEDURE SFE_SETUP_APP()
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
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.title("Replication / DR Cost Calculator")
st.caption("Business Critical Pricing | SE Community")
st.info("**Estimates only.** Actual costs vary. Monitor via ACCOUNT_USAGE views.")

# Config
st.sidebar.header("Settings")
price_per_credit = st.sidebar.number_input("$/credit", 0.5, 10.0, 4.0, 0.1)

# Load data
@st.cache_data(ttl=60)
def load_pricing():
    return session.table("SFE_PRICING").to_pandas()

@st.cache_data(ttl=60)
def load_dbs():
    return session.table("SFE_DB_METADATA").to_pandas()

def get_current_region():
    try:
        r = session.sql("SELECT CURRENT_REGION()").collect()[0][0]
        parts = r.split("_", 1)
        return parts[0], parts[1].lower().replace("_", "-") if len(parts) > 1 else "us-east-1"
    except:
        return "AWS", "us-east-1"

pricing = load_pricing()
dbs = load_dbs()
source_cloud, source_region = get_current_region()

# Database selection
selected = st.multiselect("Select databases to replicate", sorted(dbs["DATABASE_NAME"].tolist()))
total_tb = dbs[dbs["DATABASE_NAME"].isin(selected)]["SIZE_TB"].sum() if selected else 0.0

# Destination
st.subheader("Destination")
clouds = sorted(pricing["CLOUD"].unique())
dest_cloud = st.selectbox("Cloud", clouds, index=clouds.index(source_cloud) if source_cloud in clouds else 0)
regions = sorted(pricing[pricing["CLOUD"] == dest_cloud]["REGION"].unique())
dest_region = st.selectbox("Region", regions)

# Parameters
st.subheader("Replication Settings")
c1, c2 = st.columns(2)
change_pct = c1.slider("Daily change %", 0.0, 20.0, 5.0, 0.5)
refreshes = c2.slider("Refreshes/day", 0.0, 24.0, 1.0, 0.5)

daily_tb = total_tb * (change_pct / 100) * refreshes

# Get rates
def get_rate(svc, cloud, region):
    r = pricing[(pricing["SERVICE_TYPE"] == svc) & (pricing["CLOUD"] == cloud) & (pricing["REGION"] == region)]
    return float(r["RATE"].iloc[0]) if len(r) > 0 else 0.0

xfer = get_rate("DATA_TRANSFER", source_cloud, source_region)
compute = get_rate("REPLICATION_COMPUTE", source_cloud, source_region)
storage = get_rate("STORAGE", dest_cloud, dest_region)
serverless = get_rate("SERVERLESS", dest_cloud, dest_region)

# Calculate costs
daily_xfer = daily_tb * xfer
daily_compute = daily_tb * compute
monthly_storage = total_tb * storage
monthly_serverless = total_tb * serverless
monthly_total = (daily_xfer + daily_compute) * 30 + monthly_storage + monthly_serverless
annual_total = monthly_total * 12

# Display
st.subheader("Cost Summary")
st.write(f"**Source:** {source_cloud} / {source_region} → **Dest:** {dest_cloud} / {dest_region}")
st.write(f"**Total size:** {total_tb:.4f} TB | **Daily transfer:** {daily_tb:.4f} TB")

c1, c2 = st.columns(2)
with c1:
    st.metric("Monthly Credits", f"{monthly_total:.2f}")
    st.metric("Annual Credits", f"{annual_total:.2f}")
with c2:
    st.metric("Monthly USD", f"${monthly_total * price_per_credit:,.2f}")
    st.metric("Annual USD", f"${annual_total * price_per_credit:,.2f}")

with st.expander("Cost Breakdown"):
    st.table([
        {"Item": "Daily Transfer", "Credits": f"{daily_xfer:.4f}", "Rate": f"{xfer} /TB"},
        {"Item": "Daily Compute", "Credits": f"{daily_compute:.4f}", "Rate": f"{compute} /TB"},
        {"Item": "Monthly Storage", "Credits": f"{monthly_storage:.4f}", "Rate": f"{storage} /TB/mo"},
        {"Item": "Monthly Serverless", "Credits": f"{monthly_serverless:.4f}", "Rate": f"{serverless} /TB/mo"},
    ])

# Lowest cost regions
st.subheader("Lowest Cost Destinations")
totals = pricing.groupby(["CLOUD", "REGION"])["RATE"].sum().sort_values().head(5)
for (cloud, region), rate in totals.items():
    st.write(f"- {cloud} / {region}: {rate:.2f} credits/TB total")
'''
    
    session.file.put_stream(BytesIO(code.encode('utf-8')), '@SFE_STREAMLIT_STAGE/app.py', auto_compress=False, overwrite=True)
    return "App uploaded"
$$;

CALL SFE_SETUP_APP();
ALTER STAGE SFE_STREAMLIT_STAGE REFRESH;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Replication Cost Calculator' AS tool,
    '2026-01-09' AS expires,
    'Navigate to Projects -> Streamlit -> SFE_REPLICATION_CALCULATOR' AS next_step;

-- =============================================================================
-- HOW TO UPDATE PRICING
-- =============================================================================
/*
 * To update pricing rates, simply UPDATE the SFE_PRICING table:
 * 
 * -- Update a specific rate
 * UPDATE SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING 
 * SET RATE = 2.75, UPDATED_AT = CURRENT_TIMESTAMP()
 * WHERE SERVICE_TYPE = 'DATA_TRANSFER' AND CLOUD = 'AWS' AND REGION = 'us-east-1';
 * 
 * -- Add a new region
 * INSERT INTO SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING VALUES
 * ('DATA_TRANSFER', 'AWS', 'ap-northeast-1', 2.60, 'credits/TB', CURRENT_TIMESTAMP());
 * 
 * -- View current pricing
 * SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING ORDER BY CLOUD, REGION, SERVICE_TYPE;
 */
