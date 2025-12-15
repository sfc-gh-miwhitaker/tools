/******************************************************************************
 * Tool: Cortex Agent Chat (React UI)
 * File: deploy.sql
 * Author: SE Community
 * Created: 2025-12-15
 * Expires: 2026-01-14 (30 days from creation)
 *
 * Purpose: Creates a sample Cortex Agent and supporting infrastructure for
 *          the React chat application to consume via REST API with key-pair JWT auth.
 *
 * Prerequisites:
 *   1. Run shared/sql/00_shared_setup.sql first (creates database and warehouse)
 *   2. SYSADMIN role access
 *   3. Cortex Agent feature enabled in your Snowflake account
 *   4. RSA key-pair generated (see README for instructions)
 *
 * How to Deploy:
 *   1. Generate RSA key-pair: openssl genrsa -out rsa_key.pem 2048
 *   2. Extract public key: openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
 *   3. Copy this ENTIRE script into Snowsight
 *   4. Click "Run All"
 *   5. Assign public key to your Snowflake user (see below)
 *   6. Configure local React app with .env.local
 *   7. Run npm install && npm start
 *
 * After Deployment:
 *   - Assign public key to Snowflake user (see instructions below)
 *   - Configure local React app with private key in .env.local
 *   - Run npm install && npm start
 ******************************************************************************/

-- ============================================================================
-- EXPIRATION CHECK (MANDATORY)
-- ============================================================================
EXECUTE IMMEDIATE
$$
DECLARE
    v_expiration_date DATE := '2026-01-14';
    demo_expired EXCEPTION (-20001, 'TOOL EXPIRED: This tool expired on 2026-01-14. Please check for an updated version.');
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
CREATE SCHEMA IF NOT EXISTS SFE_CORTEX_AGENT_CHAT
    COMMENT = 'TOOL: Cortex Agent Chat - React UI for Cortex Agent interaction | Author: SE Community | Expires: 2026-01-14';

USE SCHEMA SFE_CORTEX_AGENT_CHAT;

-- ============================================================================
-- CREATE SAMPLE CORTEX AGENT
-- ============================================================================
CREATE OR REPLACE CORTEX AGENT SFE_DEMO_AGENT
    LANGUAGE = 'ENGLISH'
    INSTRUCTIONS = 'You are a helpful assistant for Snowflake demonstrations. You can answer questions about:
    - Snowflake features and capabilities
    - Data warehousing concepts
    - SQL query optimization
    - Cortex AI features
    
    Be concise, accurate, and helpful. If you are unsure about something, say so clearly.
    Format your responses with clear structure and examples when appropriate.'
    COMMENT = 'DEMO: Sample Cortex Agent for React chat interface | Author: SE Community | Expires: 2026-01-14';

-- ============================================================================
-- GRANT USAGE TO CURRENT ROLE
-- ============================================================================
-- This allows the current user/role to interact with the agent
GRANT USAGE ON CORTEX AGENT SFE_DEMO_AGENT TO ROLE SYSADMIN;

-- ============================================================================
-- INSTRUCTIONS FOR KEY-PAIR AUTHENTICATION SETUP
-- ============================================================================
-- To use this agent with the React app, you need to set up key-pair authentication
-- 
-- Step 1: Generate RSA Key-Pair (on your local machine)
-- 
-- # Generate private key (2048-bit RSA)
-- openssl genrsa -out rsa_key.pem 2048
-- 
-- # Extract public key from private key
-- openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub
-- 
-- Step 2: Get Public Key Content (without BEGIN/END lines)
-- 
-- # View public key content
-- cat rsa_key.pub | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'
-- 
-- # This gives you a long string like: MIIBIjANBgkqhki...
-- 
-- Step 3: Assign Public Key to Your Snowflake User
-- 
-- Replace <your_username> with your actual Snowflake username
-- Replace <public_key_content> with the string from Step 2
--
-- USE ROLE ACCOUNTADMIN;  -- Required for ALTER USER
-- ALTER USER <your_username> SET RSA_PUBLIC_KEY='<public_key_content>';
--
-- Example:
-- ALTER USER DEMO_USER SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...';
--
-- Step 4: Verify Public Key Assignment
--
-- DESC USER <your_username>;
-- -- Look for RSA_PUBLIC_KEY_FP property (fingerprint should be set)
--
-- SECURITY NOTES:
-- - Keep rsa_key.pem (private key) secure - never commit to version control
-- - Public key is safe to assign to your Snowflake user
-- - Private key stays on your machine - never sent over network
-- - JWT tokens are generated client-side and expire after 1 hour
-- - No network policy required for key-pair authentication

-- ============================================================================
-- VERIFY AGENT CREATION
-- ============================================================================
SHOW CORTEX AGENTS IN SCHEMA SFE_CORTEX_AGENT_CHAT;

SELECT
    SYSTEM$DESCRIBE_CORTEX_AGENT(
        'SNOWFLAKE_EXAMPLE',
        'SFE_CORTEX_AGENT_CHAT',
        'SFE_DEMO_AGENT'
    ) AS agent_details;

-- ============================================================================
-- DEPLOYMENT COMPLETE
-- ============================================================================
SELECT
    '✅ DEPLOYMENT COMPLETE' AS status,
    CURRENT_TIMESTAMP() AS completed_at,
    'Cortex Agent Chat (React UI)' AS tool,
    '2026-01-14' AS expires,
    'Next steps:' AS next_step,
    '1. Generate RSA key-pair (see instructions above)' AS step_1,
    '2. Assign public key to your Snowflake user' AS step_2,
    '3. Configure .env.local with private key' AS step_3,
    '4. Run: npm install && npm start' AS step_4,
    '5. Open: http://localhost:3000' AS step_5;

