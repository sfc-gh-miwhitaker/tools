# Cortex Agent Chat (React UI)

> **Expires:** 2026-01-14 (30 days from creation)

A modern React application providing a chat interface for interacting with Snowflake Cortex Agents via REST API. This tool demonstrates how to build web applications that consume Cortex Agent capabilities.

---

## What It Does

- Provides a modern chat UI for Cortex Agent interactions
- Connects directly to Snowflake Cortex Agents via REST API
- Supports programmatic access token (PAT) authentication
- Enables real-time conversation with AI agents
- Demonstrates React integration patterns for Snowflake

---

## Snowflake Features Demonstrated

- **Cortex Agents** - AI-powered conversational agents
- **REST API** - Programmatic access to Snowflake services
- **Key-Pair JWT Authentication** - Secure, long-term API authentication
- **External Integration** - React web app consuming Snowflake services

---

## Quick Start

### 1. Run Shared Setup (First Time Only)

```sql
-- Copy shared/sql/00_shared_setup.sql into Snowsight, Run All
```

### 2. Deploy Cortex Agent Infrastructure

```sql
-- Copy deploy.sql into Snowsight, Run All
-- This creates a sample Cortex Agent for testing
```

### 3. Generate Key-Pair for Authentication

**Generate RSA Key-Pair:**
```bash
# Generate private key (2048-bit RSA)
openssl genrsa -out rsa_key.pem 2048

# Extract public key from private key
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# View private key (for copying to .env.local)
cat rsa_key.pem
```

**Assign Public Key to Snowflake User:**
```sql
-- In Snowsight, run:
USE ROLE ACCOUNTADMIN;

-- Assign the public key to your user
-- Replace <your_username> and paste your public key content (without BEGIN/END lines)
ALTER USER <your_username> SET RSA_PUBLIC_KEY='MIIBIjANBgkqhki...your_key_here...';

-- Verify the key was assigned
DESC USER <your_username>;
-- Look for RSA_PUBLIC_KEY_FP property (fingerprint)
```

**Security Notes:**
- Store `rsa_key.pem` securely (never commit to version control)
- The private key stays on your machine - never sent over the network
- Public key is safe to assign to Snowflake user
- No network policy required for key-pair authentication

### 4. Install and Configure Local Application

```bash
# Navigate to tool directory
cd tools/cortex-agent-chat

# Install dependencies
npm install

# Configure environment
cp env.example .env.local

# Edit .env.local with your values:
# - REACT_APP_SNOWFLAKE_ACCOUNT=your-account
# - REACT_APP_SNOWFLAKE_USER=your_username
# - REACT_APP_SNOWFLAKE_DATABASE=SNOWFLAKE_EXAMPLE
# - REACT_APP_SNOWFLAKE_SCHEMA=SFE_CORTEX_AGENT_CHAT
# - REACT_APP_CORTEX_AGENT_NAME=SFE_DEMO_AGENT
# - REACT_APP_SNOWFLAKE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"

# Start application
npm start

# Open browser to http://localhost:3000
```

### 5. Use the Chat Interface

1. Application auto-loads configuration from `.env.local`
2. Type your message in the input field
3. Responses stream from the Cortex Agent
4. Use "Clear Chat" to start a new conversation

---

## Objects Created

| Object Type | Name | Purpose |
|-------------|------|---------|
| Schema | `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT` | Tool namespace |
| Cortex Agent | `SFE_DEMO_AGENT` | Sample conversational agent |

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│ User's Browser                                                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ React Application (localhost:3000)                       │  │
│  │                                                          │  │
│  │  ┌─────────────────┐    ┌─────────────────────────┐    │  │
│  │  │ ChatInterface   │───>│ snowflakeApi.js         │    │  │
│  │  │ Component       │    │ (REST Client)           │    │  │
│  │  └─────────────────┘    └──────────┬──────────────┘    │  │
│  └────────────────────────────────────┼───────────────────┘  │
└────────────────────────────────────────┼──────────────────────┘
                                         │
                                         │ HTTPS + Bearer Token
                                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ Snowflake Account                                               │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ REST API Endpoint                                        │  │
│  │ /api/v2/databases/.../schemas/.../agents/...:run        │  │
│  └──────────────────┬───────────────────────────────────────┘  │
│                     │                                           │
│                     ▼                                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Cortex Agent (SFE_DEMO_AGENT)                           │  │
│  │                                                          │  │
│  │  - Processes user messages                              │  │
│  │  - Generates AI responses                               │  │
│  │  - Returns conversation results                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

See `diagrams/` for detailed architecture diagrams.

---

## API Integration

### REST Endpoint

```
POST /api/v2/databases/{database}/schemas/{schema}/agents/{agent}:run
```

### Request Format

```json
{
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Your message here"
        }
      ]
    }
  ]
}
```

### Authentication

```
Authorization: Bearer {JWT_TOKEN}
X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT
```

**JWT Token Generation:**
- Generated client-side from RSA private key
- Signed with RS256 (RSA-SHA256) algorithm
- Token expires after 1 hour (auto-refreshed)
- No manual token rotation required

---

## Local Development

### Available Scripts

- `npm install` - Install dependencies (including jsrsasign for JWT)
- `npm start` - Start development server (port 3000)
- `npm run build` - Create production build
- `npm test` - Run test suite

### Project Structure

```
cortex-agent-chat/
├── public/
│   └── index.html              # HTML template
├── src/
│   ├── components/
│   │   ├── ChatInterface.js    # Main chat container
│   │   ├── ConfigPanel.js      # Configuration panel
│   │   ├── MessageList.js      # Message display
│   │   ├── MessageInput.js     # Input field
│   │   └── Message.js          # Individual message
│   ├── services/
│   │   ├── jwtGenerator.js     # JWT token generator
│   │   └── snowflakeApi.js     # REST API client
│   ├── App.js                  # Root component
│   └── index.js                # Entry point
├── scripts/
│   └── describe-agent.sh       # CLI testing helper
├── deploy.sql                  # Snowflake setup
├── teardown.sql                # Cleanup script
└── README.md                   # This file
```

---

## Testing with CLI

Validate your setup outside the React app:

```bash
# Note: CLI testing currently uses PAT-based auth
# For key-pair testing, use the React application directly
# or implement JWT generation in the bash script

# Set environment variables
export SNOWFLAKE_ACCOUNT=your-account
export SNOWFLAKE_USER=your_username
export SNOWFLAKE_DATABASE=SNOWFLAKE_EXAMPLE
export SNOWFLAKE_SCHEMA=SFE_CORTEX_AGENT_CHAT
export SNOWFLAKE_AGENT=SFE_DEMO_AGENT

# For CLI testing, use snow CLI with key-pair:
snow connection test --account $SNOWFLAKE_ACCOUNT --user $SNOWFLAKE_USER --private-key-path rsa_key.pem
```

---

## Troubleshooting

### Common Issues

**401 Unauthorized**
- Invalid private key format
- Public key not assigned to user
- JWT token generation failed
- Wrong account identifier or username

**403 Forbidden**
- Role restrictions prevent access
- User lacks agent usage grants
- Public key fingerprint mismatch

**404 Not Found**
- Database/schema/agent name mismatch
- Agent does not exist
- Case sensitivity issue

**Invalid Private Key**
- Ensure key is in PEM format (PKCS#8 or PKCS#1)
- Key must include BEGIN/END markers
- Verify key file not corrupted

**JWT Token Errors**
- Check browser console for detailed JWT generation errors
- Verify public key assigned to correct user
- Ensure private/public key pair matches

### Verification Steps

1. Verify agent exists:
   ```sql
   SHOW CORTEX AGENTS IN SCHEMA SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT;
   ```

2. Verify public key assigned:
   ```sql
   DESC USER <your_username>;
   -- Check RSA_PUBLIC_KEY_FP is set
   ```

3. Test key-pair with snow CLI:
   ```bash
   snow connection test --account <account> --user <user> --private-key-path rsa_key.pem
   ```

4. Check browser console for JWT generation errors

4. Verify `.env.local` configuration matches your Snowflake setup

---

## Security Considerations

🚨 **Critical Security Rules:**

- **NEVER commit `.env.local`** - Contains private key
- **NEVER commit private keys** - Enables full account access
- **Store private keys securely** - Use password manager or vault
- **Use strong key encryption** - 2048-bit RSA minimum
- **Rotate keys periodically** - Best practice for long-term use
- **Restrict user roles** - Minimum required permissions
- **Monitor key usage** - Check Snowflake audit logs for suspicious activity

### Key-Pair Security Benefits

- Private key never sent over network (only JWT tokens)
- No token expiration management (auto-refreshed client-side)
- No network policy requirements
- Public key can be safely shared/stored in Snowflake
- Compromised public key doesn't grant access (need private key)

### .gitignore

The global ignore already excludes:
```
.env.local
.env
*.env
*.pem
*.key
node_modules/
build/
```

---

## Customization

### Change the Agent

Edit `.env.local`:
```env
REACT_APP_SNOWFLAKE_ACCOUNT=your-account
REACT_APP_SNOWFLAKE_USER=your-username
REACT_APP_CORTEX_AGENT_NAME=YOUR_CUSTOM_AGENT
REACT_APP_SNOWFLAKE_DATABASE=YOUR_DATABASE
REACT_APP_SNOWFLAKE_SCHEMA=YOUR_SCHEMA
REACT_APP_SNOWFLAKE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
```

### Styling

- Modify component CSS files in `src/components/`
- Update `src/App.css` for global styles
- Responsive design included

### Add Features

- Message history persistence (localStorage)
- Multi-agent switching (dropdown selector)
- File attachment support (document upload)
- Markdown rendering (code syntax highlighting)
- Conversation export (JSON/Markdown download)
- Dark mode theme toggle

---

## Cleanup

### Remove Application

```bash
# Stop the development server (Ctrl+C)
# Remove node_modules
rm -rf node_modules
```

### Remove Snowflake Objects

```sql
-- Copy teardown.sql into Snowsight, Run All
```

This removes:
- Schema `SFE_CORTEX_AGENT_CHAT` and all contained objects
- Demo Cortex Agent `SFE_DEMO_AGENT`
- Does NOT remove shared infrastructure (database, warehouse)
- Does NOT remove public key from user (manual cleanup optional)

### Remove Public Key (Optional)

```sql
-- Unset the public key from your user
ALTER USER <your_username> UNSET RSA_PUBLIC_KEY;

-- Verify removal
DESC USER <your_username>;
-- RSA_PUBLIC_KEY_FP should now be null
```

### Delete Private Key

```bash
# Securely delete private key file
shred -u rsa_key.pem  # Linux
rm -P rsa_key.pem     # macOS
# Or manually delete and clear clipboard
```

---

## References

- [Snowflake Cortex Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents)
- [Cortex Agent REST API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-rest-api)
- [Key-Pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)
- [Snowflake REST API Authentication](https://docs.snowflake.com/en/developer-guide/sql-api/authenticating)
- [React Documentation](https://reactjs.org/docs)
- [jsrsasign Library](https://kjur.github.io/jsrsasign/)

---

*SE Community • Cortex Agent Chat Tool • Created: 2025-12-15 • Expires: 2026-01-14*
