# Auth Flow - Cortex Agent Chat (React UI)

Author: SE Community  
Last Updated: 2025-12-15  
Expires: 2026-01-14 (30 days from creation)  
Status: Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

Reference Implementation: This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows the authentication and authorization flow for the React chat application using key-pair JWT authentication, from key generation through token validation to agent access control.

```mermaid
sequenceDiagram
    actor Admin as Snowflake Admin
    actor User as Application User
    participant LocalMachine as Local Machine
    participant OpenSSL as OpenSSL
    participant React as React App
    participant JWT as JWT Generator
    participant Env as .env.local
    participant SF as Snowflake API
    participant Auth as Auth Service
    participant RBAC as RBAC Engine
    participant Agent as Cortex Agent
    
    Note over Admin,SF: Key-Pair Generation Phase (One-Time Setup)
    
    Admin->>LocalMachine: Generate key-pair
    LocalMachine->>OpenSSL: openssl genrsa -out rsa_key.pem 2048
    OpenSSL-->>LocalMachine: Private key created
    
    LocalMachine->>OpenSSL: openssl rsa -in rsa_key.pem -pubout
    OpenSSL-->>LocalMachine: Public key extracted
    
    Admin->>Env: Store private key in .env.local
    Note over Env: REACT_APP_SNOWFLAKE_PRIVATE_KEY=<br/>-----BEGIN PRIVATE KEY-----<br/>...
    
    Admin->>SF: ALTER USER SET RSA_PUBLIC_KEY
    SF-->>Admin: Public key assigned
    
    Admin->>SF: GRANT USAGE ON AGENT<br/>TO ROLE SYSADMIN
    SF-->>Admin: Grant successful
    
    Note over User,Agent: Runtime Authentication Flow (Each Request)
    
    User->>React: Open http://localhost:3000
    React->>Env: Read configuration
    Env-->>React: Private key + account + user + agent details
    
    User->>React: Type message: "Hello"
    React->>React: Build JSON payload
    
    React->>JWT: Generate JWT token
    Note over JWT: Uses jsrsasign library
    JWT->>JWT: Create header {alg: RS256, typ: JWT}
    JWT->>JWT: Create payload {iss, sub, iat, exp}
    JWT->>JWT: Sign with private key (RSA-SHA256)
    JWT-->>React: Signed JWT token (valid 1 hour)
    
    React->>SF: POST /api/v2/.../agents/:run<br/>Header: Authorization: Bearer {JWT}<br/>Header: X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT<br/>Body: {"messages": [...]}
    
    SF->>Auth: Validate JWT token
    Auth->>Auth: Verify token signature with public key
    Auth->>Auth: Check token expiration (exp claim)
    Auth->>Auth: Verify issuer/subject (iss/sub claims)
    Auth->>Auth: Lookup user from qualified username
    
    alt JWT Invalid or Expired
        Auth-->>SF: 401 Unauthorized
        SF-->>React: Error: Invalid token
        React-->>User: Display error message
    end
    
    alt Public Key Mismatch
        Auth-->>SF: 401 Unauthorized
        SF-->>React: Error: Key verification failed
        React-->>User: Display error message
    end
    
    Auth->>RBAC: Check permissions
    RBAC->>RBAC: Verify USAGE grant on agent
    RBAC->>RBAC: Verify role has access
    
    alt Permission Denied
        RBAC-->>SF: 403 Forbidden
        SF-->>React: Error: Permission denied
        React-->>User: Display error message
    end
    
    RBAC-->>SF: Authorization successful
    SF->>Agent: Invoke agent with message
    Agent->>Agent: Process with Cortex AI
    Agent-->>SF: Return response
    SF-->>React: 200 OK<br/>{"message": {"role": "assistant", ...}}
    React-->>User: Display agent response
    
    Note over React,JWT: Token expires after 1 hour, auto-refreshed on next request
```

## Component Descriptions

### Key-Pair Generation Phase (One-Time Setup)

**Snowflake Admin**
- Purpose: Administrator configuring authentication
- Technology: Snowflake user with ACCOUNTADMIN or SECURITYADMIN role
- Location: Snowsight or SQL client
- Dependencies: Appropriate administrative privileges

**Local Machine**
- Purpose: Development environment for key generation
- Technology: macOS/Linux/Windows with OpenSSL
- Location: Developer's workstation
- Dependencies: OpenSSL installed (typically pre-installed on macOS/Linux)

**OpenSSL**
- Purpose: Cryptographic toolkit for key generation
- Technology: OpenSSL 1.1.1+ or LibreSSL
- Location: System utility
- Commands:
  - `openssl genrsa -out rsa_key.pem 2048` - Generate private key
  - `openssl rsa -in rsa_key.pem -pubout` - Extract public key

**Public Key Assignment**
- Purpose: Associates public key with Snowflake user
- Technology: Snowflake user management
- Location: User metadata
- Command: `ALTER USER <username> SET RSA_PUBLIC_KEY='...'`
- Verification: `DESC USER <username>` - Check RSA_PUBLIC_KEY_FP

**Permission Grants**
- Purpose: Authorizes agent usage for specific roles
- Technology: Snowflake RBAC system
- Location: Access control metadata
- Required: `GRANT USAGE ON CORTEX AGENT ... TO ROLE`

### Runtime Authentication (Each Request)

**React Application**
- Purpose: Single-page chat interface
- Technology: React 18, Create React App
- Location: localhost:3000 (development)
- Dependencies: Node.js runtime, npm packages
- Storage: Configuration in `.env.local`

**JWT Generator (jsrsasign)**
- Purpose: Client-side JWT token generation
- Technology: jsrsasign library (browser-compatible)
- Location: `src/services/jwtGenerator.js`
- Algorithm: RS256 (RSA-SHA256)
- Token Lifetime: 1 hour (configurable)
- Auto-refresh: Generates new token when expired

**JWT Token Structure**
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT"
  },
  "payload": {
    "iss": "account.USERNAME",
    "sub": "account.USERNAME",
    "iat": 1702648800,
    "exp": 1702652400
  },
  "signature": "..." 
}
```

**.env.local Configuration**
- Purpose: Stores credentials and connection details
- Technology: Environment variables file
- Location: Project root (gitignored)
- Security: NEVER commit to version control
- Contains: Private key (PEM format)

**Snowflake REST API**
- Purpose: API gateway for programmatic access
- Technology: Snowflake REST API v2
- Location: `https://{account}.snowflakecomputing.com/api/v2/`
- Protocol: HTTPS with TLS 1.2+
- Auth Header: `X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT`

**Authentication Service**
- Purpose: Validates JWT tokens using public key
- Technology: Snowflake identity platform
- Location: Snowflake managed service
- Validation Steps:
  1. Verify signature with user's public key
  2. Check token expiration (exp claim)
  3. Verify issuer matches account.user format
  4. Lookup user from qualified username

**RBAC Engine**
- Purpose: Enforces role-based permissions
- Technology: Snowflake access control system
- Location: Metadata services
- Validation: User role has USAGE grant on agent

**Cortex Agent**
- Purpose: AI agent processing user requests
- Technology: Snowflake Cortex Agent
- Location: `SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT.SFE_DEMO_AGENT`
- Dependencies: Authorization passed, Cortex service available

## Authentication Methods Comparison

| Method | Use Case | Complexity | Security | This Tool |
|--------|----------|------------|----------|-----------|
| Username/Password | Interactive login | Low | Medium | ❌ Not used |
| **Key-Pair JWT** | **Service accounts** | **Medium** | **Very High** | **✅ Primary** |
| OAuth | Third-party apps | High | High | ❌ Not used |
| PAT | Programmatic access | Medium | High | ❌ Replaced |

## Key-Pair Security Properties

### Private Key Format (PEM)
```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
...
-----END PRIVATE KEY-----
```
- Format: PKCS#8 or PKCS#1
- Encryption: RSA 2048-bit minimum
- Storage: `.env.local` (gitignored), file permissions 0600

### Public Key Format (PEM)
```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----
```
- Format: X.509 SubjectPublicKeyInfo
- Distribution: Assigned to Snowflake user (safe to share)
- Verification: Fingerprint (RSA_PUBLIC_KEY_FP)

### JWT Token Lifecycle

1. **Key Generation**: Admin generates RSA key-pair with OpenSSL
2. **Public Key Assignment**: Admin assigns public key to Snowflake user
3. **Private Key Storage**: Developer stores private key in `.env.local`
4. **Token Generation**: React app generates JWT client-side on demand
5. **Token Signing**: JWT signed with private key using RS256
6. **Token Usage**: React app sends JWT as Bearer token in API calls
7. **Token Validation**: Snowflake validates signature with public key
8. **Auto-Refresh**: New token generated when expired (1 hour lifetime)

### Key Advantages Over PATs

✅ **No Token Expiration Management**
- PATs expire after max 90 days, require manual rotation
- JWTs auto-refresh client-side, no expiration management needed

✅ **No Network Policy Required**
- PATs require network policies with IP restrictions
- Key-pair auth works from any IP without policy

✅ **Private Key Never Transmitted**
- PATs are transmitted as-is (bearer tokens)
- Private key stays local, only JWT signatures sent

✅ **Stronger Cryptographic Foundation**
- PATs are opaque tokens with server-side validation
- JWTs use asymmetric cryptography (RSA-2048+)

✅ **Better Security Posture**
- Compromised PAT grants immediate access
- Compromised public key useless without private key

## Security Boundaries

### Credential Storage

```
┌─────────────────────────────────────────────┐
│ Secure Zone (Never Committed)              │
│                                             │
│  .env.local                                 │
│  ├── REACT_APP_SNOWFLAKE_PRIVATE_KEY      │
│  │   -----BEGIN PRIVATE KEY-----           │
│  │   ...                                    │
│  │   -----END PRIVATE KEY-----             │
│  └── [Other connection details]            │
│                                             │
│  rsa_key.pem (local file)                  │
│  ├── File permissions: 0600                │
│  └── Never commit to git                   │
│                                             │
│  Security: Global .gitignore               │
│            *.pem, *.key, .env.local        │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Snowflake (Safe to Store)                  │
│                                             │
│  User Metadata                              │
│  ├── RSA_PUBLIC_KEY (public key content)  │
│  └── RSA_PUBLIC_KEY_FP (fingerprint)      │
│                                             │
│  Security: Public key cannot be used       │
│            without private key             │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ Version Control (Safe to Commit)           │
│                                             │
│  env.example                                │
│  ├── REACT_APP_SNOWFLAKE_PRIVATE_KEY=     │
│  │   "-----BEGIN PRIVATE KEY-----\n..."   │
│  └── [Template values only]                │
│                                             │
│  Security: No real credentials             │
└─────────────────────────────────────────────┘
```

### Network Boundaries

```
┌──────────────────────────────────────────────┐
│ Trusted Zone - Developer Machine           │
│  - localhost:3000                           │
│  - .env.local with private key              │
│  - JWT generation happens here              │
│  - No external access                       │
└────────────────┬─────────────────────────────┘
                 │
                 │ HTTPS :443 (Encrypted)
                 │ JWT Token in Header (not private key)
                 │
┌────────────────▼─────────────────────────────┐
│ Snowflake Cloud - Public Internet          │
│  - TLS 1.2+ required                        │
│  - JWT signature validation                 │
│  - Public key stored in user metadata       │
│  - No network policy required               │
└──────────────────────────────────────────────┘
```

### Permission Boundaries

```
User (with public key assigned)
  └─> JWT Token (signed with private key)
       └─> Role: SYSADMIN
            └─> USAGE on CORTEX AGENT SFE_DEMO_AGENT
                 └─> Agent Invocation Allowed ✓
```

## Error Handling

### 401 Unauthorized (Invalid JWT)

**Cause:** JWT signature verification failed  
**Response:**
```json
{
  "error": "Authentication failed",
  "message": "Invalid token signature"
}
```
**Resolution:**
1. Verify private/public key pair matches
2. Check public key assigned to correct user
3. Regenerate key-pair if keys corrupted

### 401 Unauthorized (Expired JWT)

**Cause:** JWT token expired (> 1 hour old)  
**Response:**
```json
{
  "error": "Authentication failed",
  "message": "Token expired"
}
```
**Resolution:**
- Auto-handled by application (generates new JWT)
- Check system clock if persistent issues

### 401 Unauthorized (Public Key Not Found)

**Cause:** Public key not assigned to user  
**Response:**
```json
{
  "error": "Authentication failed",
  "message": "Public key not found for user"
}
```
**Resolution:**
```sql
-- Assign public key to user
ALTER USER <username> SET RSA_PUBLIC_KEY='<public_key_content>';

-- Verify assignment
DESC USER <username>;
```

### 403 Forbidden (Permissions)

**Cause:** Role lacks USAGE grant on agent  
**Response:**
```json
{
  "error": "Forbidden",
  "message": "Insufficient privileges to access agent"
}
```
**Resolution:**
```sql
GRANT USAGE ON CORTEX AGENT 
  SNOWFLAKE_EXAMPLE.SFE_CORTEX_AGENT_CHAT.SFE_DEMO_AGENT 
TO ROLE SYSADMIN;
```

## Best Practices

### DO ✅

- Generate strong RSA keys (2048-bit minimum, 4096-bit recommended)
- Store private keys in `.env.local` (gitignored)
- Set file permissions on private key files (0600)
- Rotate key-pairs periodically (annually recommended)
- Use separate key-pairs for different environments
- Monitor JWT usage via ACCOUNT_USAGE
- Test key-pair with snow CLI before React app
- Keep private keys in secure password manager

### DON'T ❌

- Commit private keys to version control
- Share private keys via email or Slack
- Use weak key sizes (< 2048-bit)
- Reuse same key-pair across multiple users
- Store private keys in plaintext notes
- Hardcode private keys in source code
- Copy private keys to shared drives
- Use same key-pair for production and development

## Monitoring and Auditing

### Track JWT Usage

```sql
-- View REST API calls using key-pair authentication
SELECT
    user_name,
    client_ip,
    request_path,
    response_status_code,
    execution_time,
    error_message,
    authentication_method
FROM SNOWFLAKE.ACCOUNT_USAGE.REST_EVENT_HISTORY
WHERE user_name = '<your_username>'
    AND authentication_method = 'KEYPAIR'
    AND request_path LIKE '%/agents/%:run'
ORDER BY start_time DESC
LIMIT 100;
```

### Monitor Failed Authentication

```sql
-- View failed key-pair authentication attempts
SELECT
    event_timestamp,
    user_name,
    client_ip,
    reported_client_type,
    error_code,
    error_message,
    authentication_method
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE is_success = FALSE
    AND authentication_method = 'KEYPAIR'
    AND reported_client_type = 'REST_API'
ORDER BY event_timestamp DESC
LIMIT 50;
```

### Check Public Key Assignment

```sql
-- Verify public key assigned to user
DESC USER <your_username>;

-- Look for:
-- RSA_PUBLIC_KEY: <public key content>
-- RSA_PUBLIC_KEY_FP: <fingerprint hash>
```

## Key Generation Reference

### Generate New Key-Pair

```bash
# Generate 2048-bit RSA private key
openssl genrsa -out rsa_key.pem 2048

# Generate 4096-bit RSA private key (more secure)
openssl genrsa -out rsa_key.pem 4096

# Extract public key
openssl rsa -in rsa_key.pem -pubout -out rsa_key.pub

# Set secure file permissions
chmod 600 rsa_key.pem
chmod 644 rsa_key.pub

# View private key
cat rsa_key.pem

# View public key (for Snowflake)
cat rsa_key.pub | grep -v "BEGIN PUBLIC KEY" | grep -v "END PUBLIC KEY" | tr -d '\n'
```

### Verify Key-Pair

```bash
# Test with snow CLI
snow connection test --account <account> --user <user> --private-key-path rsa_key.pem

# Generate JWT manually (for debugging)
snow connection generate-jwt --account <account> --user <user> --private-key-path rsa_key.pem
```

## Change History

See `.cursor/DIAGRAM_CHANGELOG.md` for version history.

---

*SE Community • Cortex Agent Chat Tool • Created: 2025-12-15 • Expires: 2026-01-14*
