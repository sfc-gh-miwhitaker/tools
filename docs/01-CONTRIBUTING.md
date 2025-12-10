# Contributing a New Tool

Author: SE Community  
Last Updated: 2025-12-10

---

## Overview

This guide explains how to add a new tool to the Snowflake Tools Collection. Each tool should be small, focused, and demonstrate a specific Snowflake capability.

---

## When to Add Here vs. Create a New Repo

### ✅ Add to this collection when:
- Tool demonstrates a single feature or pattern
- Setup takes < 5 minutes
- No complex dependencies or multi-step workflows
- Good for quick customer demos or learning
- Doesn't require ongoing maintenance

### ❌ Create a separate repository when:
- Multiple integrated components
- Complex business logic
- Requires CI/CD pipeline
- Needs version history tracking
- Customer-specific customization needed

---

## Step-by-Step Guide

### Step 1: Create Tool Directory

```bash
mkdir -p tools/<tool-name>/diagrams
```

Use lowercase with hyphens for the tool name:
- ✅ `api-data-fetcher`
- ✅ `contact-form-streamlit`
- ❌ `API_Data_Fetcher`
- ❌ `contactForm`

### Step 2: Create README.md

Every tool needs a README with this structure:

```markdown
# <Tool Name>

> **Expires:** YYYY-MM-DD (30 days from creation)

Brief description of what this tool does.

## What It Does

- Bullet points of capabilities
- Keep it concise

## Snowflake Features Demonstrated

- Feature 1 (e.g., Streamlit in Snowflake)
- Feature 2 (e.g., External Access Integration)

## Quick Start

1. Run shared setup (if not already done):
   \`\`\`sql
   -- Copy shared/sql/00_shared_setup.sql into Snowsight, Run All
   \`\`\`

2. Deploy this tool:
   \`\`\`sql
   -- Copy deploy.sql into Snowsight, Run All
   \`\`\`

3. Use the tool:
   - Step-by-step usage instructions

## Objects Created

| Object Type | Name | Purpose |
|-------------|------|---------|
| Schema | SNOWFLAKE_EXAMPLE.SFE_<TOOL> | Tool namespace |
| ... | ... | ... |

## Cleanup

\`\`\`sql
-- Copy teardown.sql into Snowsight, Run All
\`\`\`

## Architecture

See \`diagrams/\` for detailed architecture (if applicable).
```

### Step 3: Create deploy.sql

Use this template:

```sql
/******************************************************************************
 * Tool: <Tool Name>
 * File: deploy.sql
 * Author: SE Community
 * Created: YYYY-MM-DD
 * Expires: YYYY-MM-DD (30 days from creation)
 *
 * Prerequisites:
 *   1. Run shared/sql/00_shared_setup.sql first
 *   2. SYSADMIN role access
 *
 * How to Deploy:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := 'YYYY-MM-DD';
    demo_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired. Please check for an updated version.');
BEGIN
    IF (CURRENT_DATE() > v_expiration_date) THEN
        RAISE demo_expired;
    END IF;
    RETURN 'Expiration check passed. Tool valid until ' || v_expiration_date::STRING;
END;
$$;

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- CREATE TOOL SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS SFE_<TOOL_NAME>
    COMMENT = 'TOOL: <Description> | Author: SE Community | Expires: YYYY-MM-DD';

USE SCHEMA SFE_<TOOL_NAME>;

-- ============================================================================
-- TOOL-SPECIFIC OBJECTS
-- ============================================================================
-- Add your tables, procedures, Streamlit apps, etc. here
-- All objects should have COMMENT with expiration date

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    '<Tool Name>' AS tool,
    'YYYY-MM-DD' AS expires,
    '<Next step instruction>' AS next_step;
```

### Step 4: Create teardown.sql

Use this template:

```sql
/******************************************************************************
 * Tool: <Tool Name>
 * File: teardown.sql
 * Author: SE Community
 *
 * Purpose: Removes all objects created by this tool
 *
 * How to Use:
 *   1. Copy this ENTIRE script into Snowsight
 *   2. Click "Run All"
 ******************************************************************************/

-- ============================================================================
-- CONTEXT SETTING (MANDATORY)
-- ============================================================================
USE ROLE SYSADMIN;
USE WAREHOUSE SFE_TOOLS_WH;

-- ============================================================================
-- DROP TOOL SCHEMA (CASCADE removes all contained objects)
-- ============================================================================
DROP SCHEMA IF EXISTS SNOWFLAKE_EXAMPLE.SFE_<TOOL_NAME> CASCADE;

-- ============================================================================
-- DROP TOOL-SPECIFIC ACCOUNT-LEVEL OBJECTS (if any)
-- ============================================================================
-- DROP INTEGRATION IF EXISTS SFE_<TOOL>_INTEGRATION;
-- DROP NETWORK RULE IF EXISTS ...;

-- ============================================================================
-- CLEANUP COMPLETE
-- ============================================================================
SELECT
    '✅ TEARDOWN COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    '<Tool Name>' AS tool,
    'All tool objects removed' AS message;
```

### Step 5: Add Diagrams (If Applicable)

If your tool has non-trivial architecture, add diagrams:

```
tools/<tool-name>/diagrams/
├── data-flow.md      # How data moves through the tool
└── architecture.md   # Overall architecture (if complex)
```

Use Mermaid format. See existing tools for examples.

### Step 6: Update Main README

Add your tool to the tools table in the root `README.md`:

```markdown
| [Your Tool Name](/tools/<tool-name>/) | Brief description | Features used | ✅ Active |
```

---

## Naming Conventions

### Tool Directory
- Lowercase with hyphens: `api-data-fetcher`

### Snowflake Schema
- Pattern: `SNOWFLAKE_EXAMPLE.SFE_<TOOL_NAME>`
- Use underscores: `SFE_API_DATA_FETCHER`

### Snowflake Objects
- All objects use `SFE_` prefix
- Descriptive names: `SFE_CONTACT_SUBMISSIONS` not `SFE_TABLE1`

---

## Checklist Before Committing

- [ ] Tool directory created with proper naming
- [ ] README.md with all required sections
- [ ] deploy.sql with expiration check and context setup
- [ ] teardown.sql for complete cleanup
- [ ] All objects have COMMENT with expiration
- [ ] Main README updated with new tool
- [ ] Tested deploy and teardown in Snowsight
- [ ] No hardcoded credentials or personal data
- [ ] No personal names (use "SE Community")

---

## Example Tools

Reference these existing tools for patterns:

1. **contact-form-streamlit** - Streamlit app example
2. **api-data-fetcher** - External Access Integration example

---

## Questions?

If you're unsure whether your tool fits this collection or need help with patterns, check the existing tools or reach out to the SE Community.

