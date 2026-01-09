curl --silent --show-error --no-buffer -X POST \
  "${SNOWFLAKE_ACCOUNT_BASE_URL%/}/api/v2/databases/${AGENT_DATABASE}/schemas/${AGENT_SCHEMA}/agents/${AGENT_NAME}:run" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -H "Authorization: Bearer ${SNOWFLAKE_PAT}" \
  ${SNOWFLAKE_ROLE:+-H "X-Snowflake-Role: ${SNOWFLAKE_ROLE}"} \
  ${SNOWFLAKE_WAREHOUSE:+-H "X-Snowflake-Warehouse: ${SNOWFLAKE_WAREHOUSE}"} \
  --data '{"thread_id":0,"parent_message_id":0,"messages":[{"role":"user","content":[{"type":"text","text":"YOUR_PROMPT_HERE"}]}],"tool_choice":{"type":"auto"}}'
