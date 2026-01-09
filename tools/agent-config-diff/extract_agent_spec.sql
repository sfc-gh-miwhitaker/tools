-- Extract and display a Cortex Agent specification
-- Usage: Replace <DATABASE>.<SCHEMA>.<AGENT_NAME> with your agent's fully qualified name

-- Set the agent name (modify this)
SET agent_fqn = '<DATABASE>.<SCHEMA>.<AGENT_NAME>';

-- Get agent metadata from SHOW AGENTS
SHOW AGENTS LIKE '%' IN ACCOUNT;

-- Describe the agent to get full specification
DESC AGENT IDENTIFIER($agent_fqn);

-- Alternative: Query the result directly and format as JSON
-- This creates a single JSON object with all agent properties
SELECT OBJECT_CONSTRUCT(
    'name', "name",
    'created_on', "created_on",
    'database_name', "database_name",
    'schema_name', "schema_name",
    'comment', "comment",
    'owner', "owner",
    'specification', TRY_PARSE_JSON("specification")
) AS agent_spec
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- To extract just the specification as formatted JSON:
SELECT "specification"::VARIANT AS spec
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)));
