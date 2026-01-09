# dbt-patterns

## Purpose
Team-specific dbt best practices for Snowflake projects, covering naming conventions, version control workflows, testing requirements, and performance patterns.

## When to Use
- Creating new dbt projects or models
- Reviewing dbt code for standards compliance
- Setting up CI/CD pipelines for dbt
- Optimizing dbt model performance

## Complements (Not Replaces)
- Use `system_instructions("dbt")` for dbt syntax and Snowflake integration details
- This skill adds: YOUR team's specific conventions and patterns

## Guidelines

### Database & Schema Standards

**Required Database:** Always use `SNOWFLAKE_EXAMPLE` for all team-created objects.

**Schema Naming (Least Privilege):**
| Layer | Schema Pattern | Purpose |
|-------|----------------|---------|
| Sources | `RAW_<SOURCE>` | Raw data landing zone |
| Staging | `STG_<PROJECT>` | Cleaned, typed source data |
| Intermediate | `INT_<PROJECT>` | Transformation logic |
| Marts | `MART_<DOMAIN>` | Business-ready dimensions/facts |

**Example:**
```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +schema: STG_CHURN
    intermediate:
      +schema: INT_CHURN
    marts:
      +schema: MART_ANALYTICS
```

### Model Naming Conventions

**Prefix Rules:**
| Prefix | Layer | Example |
|--------|-------|---------|
| `stg_` | Staging | `stg_salesforce__accounts` |
| `int_` | Intermediate | `int_customer_orders_joined` |
| `dim_` | Dimension | `dim_customer` |
| `fct_` | Fact | `fct_order_items` |
| `rpt_` | Report/aggregate | `rpt_daily_sales` |

**Folder Structure:**
```
models/
├── staging/
│   └── salesforce/
│       ├── _salesforce__sources.yml
│       ├── _salesforce__models.yml
│       └── stg_salesforce__accounts.sql
├── intermediate/
│   └── int_customer_orders_joined.sql
└── marts/
    ├── core/
    │   ├── dim_customer.sql
    │   └── fct_orders.sql
    └── marketing/
        └── rpt_campaign_performance.sql
```

### Version Control Workflow

**Branch Naming:**
```
feature/add-customer-churn-model
fix/stg-accounts-null-handling
refactor/optimize-fct-orders
```

**Commit Messages (Conventional):**
```bash
feat(models): add customer churn prediction mart
fix(staging): handle null customer_id in accounts
refactor(intermediate): optimize join order for performance
test(marts): add uniqueness tests for dim_customer
docs(readme): update setup instructions
```

**PR Requirements:**
- [ ] All models compile: `dbt compile --select state:modified+`
- [ ] Tests pass: `dbt test --select state:modified+`
- [ ] Documentation updated: `dbt docs generate`
- [ ] No hardcoded values (use variables/macros)

### Testing Requirements

**Minimum Test Coverage:**
| Model Type | Required Tests |
|------------|----------------|
| All models | `unique`, `not_null` on primary key |
| Staging | `accepted_values` on status/type columns |
| Dimensions | `relationships` to source |
| Facts | `dbt_utils.at_least_one`, freshness |

**Test Organization:**
```yaml
# models/marts/core/_core__models.yml
models:
  - name: dim_customer
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
      - name: customer_status
        tests:
          - accepted_values:
              values: ['active', 'churned', 'pending']
```

**Source Freshness:**
```yaml
sources:
  - name: salesforce
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
```

### Performance Patterns

**Incremental Models (Large Tables):**
```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        cluster_by=['order_date']
    )
}}

SELECT ...
FROM {{ ref('stg_orders') }}
{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

**Clustering Keys:** Apply to tables > 1TB or frequently filtered columns.

**Warehouse Sizing:**
| Model Complexity | Warehouse Size |
|------------------|----------------|
| Staging/simple transforms | X-SMALL |
| Intermediate joins | SMALL |
| Large aggregations | MEDIUM |
| Full refreshes | LARGE (with auto-suspend) |

**Anti-Patterns to Avoid:**
- ❌ `SELECT *` in any model
- ❌ Cross-joins without explicit intent
- ❌ Unpruned date ranges on large tables
- ❌ Multiple scans of same source (consolidate filters)

### Least Privilege Principles

**Role-Based Access:**
```sql
-- Transformer role: read sources, write to marts
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE DBT_TRANSFORMER;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.RAW_SALESFORCE TO ROLE DBT_TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA SNOWFLAKE_EXAMPLE.RAW_SALESFORCE TO ROLE DBT_TRANSFORMER;
GRANT ALL ON SCHEMA SNOWFLAKE_EXAMPLE.MART_ANALYTICS TO ROLE DBT_TRANSFORMER;
```

**Environment Variables:** Never hardcode credentials in profiles.yml.

## Cross-References
- `sfe-demo-standards` - Project naming and expiration patterns
- `sql-excellence` - SQL quality standards beyond dbt
- `system_instructions("dbt")` - dbt syntax and Snowflake integration
