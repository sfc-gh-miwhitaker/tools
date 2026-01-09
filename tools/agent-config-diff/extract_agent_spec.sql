-- =============================================================================
-- Extract Cortex Agent Specification for Configuration Management
-- =============================================================================
-- Author: SE Community
-- Purpose: Reliably extract agent specs for comparison and version control
--
-- DESCRIBE AGENT Output Columns (per Snowflake docs):
--   name, database_name, schema_name, owner, comment, profile, agent_spec, created_on
--
-- Note: agent_spec is returned as YAML text, not JSON
-- =============================================================================

-- Set the agent name (modify this for your agent)
SET agent_fqn = 'SNOWFLAKE_EXAMPLE.SAM_THE_SNOWMAN.SAM_THE_SNOWMAN';

-- =============================================================================
-- Option 1: Full Agent Metadata (recommended for config management)
-- =============================================================================
-- Returns all agent properties as a structured object
DESC AGENT IDENTIFIER($agent_fqn);

SELECT
    "name" AS agent_name,
    "database_name" || '.' || "schema_name" || '.' || "name" AS agent_fqn,
    "owner",
    "comment",
    TRY_PARSE_JSON("profile") AS profile_json,
    "agent_spec" AS spec_yaml,
    "created_on"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Option 2: Spec YAML Only (for diff/comparison tools)
-- =============================================================================
-- Run DESC again to get fresh result for RESULT_SCAN
DESC AGENT IDENTIFIER($agent_fqn);

SELECT "agent_spec" AS spec_yaml
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- =============================================================================
-- Option 3: Export-Ready Format (for version control)
-- =============================================================================
-- Creates a single JSON document with all config data
DESC AGENT IDENTIFIER($agent_fqn);

SELECT OBJECT_CONSTRUCT(
    'extracted_at', CURRENT_TIMESTAMP(),
    'agent_fqn', "database_name" || '.' || "schema_name" || '.' || "name",
    'metadata', OBJECT_CONSTRUCT(
        'name', "name",
        'database', "database_name",
        'schema', "schema_name",
        'owner', "owner",
        'comment', "comment",
        'created_on', "created_on"
    ),
    'profile', TRY_PARSE_JSON("profile"),
    'spec_yaml', "agent_spec"
) AS agent_config_export
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
