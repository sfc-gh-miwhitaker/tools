![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--02--04-orange)

# MCP Snowflake Bridge (VS Code)

> DEMONSTRATION PROJECT - EXPIRES: 2026-02-04  
> This demo uses Snowflake features current as of January 2026.  
> After expiration, this repository will be archived and made private.

**Author:** SE Community  
**Purpose:** Reference implementation for connecting VS Code MCP clients to Snowflake-managed MCP servers  
**Created:** 2026-01-05 | **Expires:** 2026-02-04 (30 days) | **Status:** ACTIVE

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices for Snowflake-managed MCP servers. Review and customize security, networking, and access controls for your organization's requirements before deployment.

## What This Demo Shows

Snowflake-managed MCP servers expose MCP over **HTTP**. Many VS Code MCP clients expect MCP over **stdio**.

This demo bridges the gap:
- Deploy a minimal Snowflake-managed MCP server (`deploy_all.sql`)
- Run a small local Python bridge (`python/mcp_bridge.py`) that proxies stdio MCP to Snowflake HTTP MCP
- Use VS Code (Continue/Cline/Copilot) as the client UI

## First Time Here?

Follow these steps in order:

1. `docs/01-GETTING-STARTED.md` - Deploy the Snowflake-managed MCP server (5 min)
2. `docs/02-VSCODE-SETUP.md` - Configure VS Code to launch the bridge (5 min)

**Total setup time:** ~10 minutes

## Quick Start

### Deployment

This project is designed to be deployed by copy/pasting a deploy script into a new Snowsight SQL worksheet.
The script will clone this repo into Snowflake as a Git repository object and deploy the remaining files from Git automatically.

1. In Snowsight, open a new SQL worksheet
2. Copy/paste `deploy_all.sql` and click **Run All**

See `docs/01-GETTING-STARTED.md`.

## Architecture

VS Code client → stdio MCP → local bridge → HTTPS MCP → Snowflake-managed MCP server → tools

## Example Queries

Try:
- “List the available tools.”
- “List the tables in the schema.”
- “Run a query showing 10 tables in INFORMATION_SCHEMA.TABLES (explicit columns only).”

## What's Included

| Component | Purpose | Demo Value |
|-----------|---------|------------|
| Snowflake-managed MCP server | Hosted MCP endpoint in your account | Standards-based tool interface |
| 2 MCP tools | SQL execution + schema snapshot | Simple, reliable demos |
| Python bridge | stdio↔HTTP proxy | Works with VS Code clients that don’t support HTTP MCP |

## Documentation

| Document | Purpose |
|----------|---------|
| `docs/01-GETTING-STARTED.md` | Detailed setup guide |
| `docs/02-VSCODE-SETUP.md` | VS Code configuration |

## Project Structure

```
tools/mcp-catalog-concierge/
├── README.md                    # This file
├── deploy_all.sql               # Deploy Snowflake-managed MCP server
├── python/                      # Local stdio-to-HTTP bridge for VS Code
├── sql/                         # All SQL scripts
│   ├── 00_config.sql            # Naming + expiration
│   ├── 01_setup.sql             # Schema + warehouse
│   ├── 02_helper_function.sql   # Helper function(s) for MCP tools
│   ├── 03_mcp_server.sql        # MCP server definition
│   ├── 04_agent.sql             # Optional agent (not required)
│   └── 99_cleanup.sql           # Teardown script
├── diagrams/                    # Architecture diagrams
└── docs/                        # User documentation
```

## Cleanup

Remove all demo objects:

```sql
-- Run sql/99_cleanup.sql in Snowsight
```

## Support

This is a reference implementation for demonstration purposes. For production use:
- Review and customize security settings
- Prefer OAuth over PATs
- Implement proper access controls
- Add monitoring and logging
- Test in your environment

## License

Reference implementation by SE Community. Use and modify as needed for your Snowflake demonstrations and customer engagements.

