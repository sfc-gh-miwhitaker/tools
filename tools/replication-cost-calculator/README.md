# Replication / DR Cost Calculator

> **Expires:** 2026-01-09

A simple Streamlit calculator for estimating Snowflake database replication and DR costs.

---

## What It Does

- Calculates replication costs between Snowflake regions/clouds
- Auto-detects your current region as source
- Shows your database sizes from ACCOUNT_USAGE
- Estimates daily, monthly, and annual costs
- Suggests lowest-cost destination regions

---

## Quick Start

```sql
-- Copy deploy.sql into Snowsight, Run All
-- Then: Projects -> Streamlit -> SFE_REPLICATION_CALCULATOR
```

**No ACCOUNTADMIN required!** Just SYSADMIN.

---

## Objects Created

| Object | Name | Purpose |
|--------|------|---------|
| Schema | `SFE_REPLICATION_CALC` | Tool namespace |
| Table | `SFE_PRICING` | Editable pricing rates |
| View | `SFE_DB_METADATA` | Database sizes |
| Streamlit | `SFE_REPLICATION_CALCULATOR` | Cost calculator |

Uses shared `SFE_TOOLS_WH` warehouse.

---

## Updating Pricing

Pricing is stored in a simple table. Update it directly:

```sql
-- View current rates
SELECT * FROM SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING 
ORDER BY CLOUD, REGION, SERVICE_TYPE;

-- Update a rate
UPDATE SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING 
SET RATE = 2.75, UPDATED_AT = CURRENT_TIMESTAMP()
WHERE SERVICE_TYPE = 'DATA_TRANSFER' AND CLOUD = 'AWS' AND REGION = 'us-east-1';

-- Add a new region
INSERT INTO SNOWFLAKE_EXAMPLE.SFE_REPLICATION_CALC.SFE_PRICING 
(SERVICE_TYPE, CLOUD, REGION, RATE, UNIT) VALUES
('DATA_TRANSFER', 'AWS', 'ap-northeast-1', 2.60, 'credits/TB'),
('REPLICATION_COMPUTE', 'AWS', 'ap-northeast-1', 1.00, 'credits/TB'),
('STORAGE', 'AWS', 'ap-northeast-1', 0.25, 'credits/TB/month'),
('SERVERLESS', 'AWS', 'ap-northeast-1', 0.10, 'credits/TB/month');
```

---

## Cleanup

```sql
-- Copy teardown.sql into Snowsight, Run All
```

---

## Cost Disclaimer

**Estimates only.** Actual costs vary based on compression, network conditions, change patterns, and contract terms. Monitor actual usage via ACCOUNT_USAGE views.

---

*SE Community • Replication Cost Calculator • 2025-12-10*
