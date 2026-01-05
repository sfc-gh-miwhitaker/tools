#!/usr/bin/env python3
"""
MCP Snowflake Bridge - stdio to Snowflake-managed MCP (HTTP)

Purpose:
  VS Code MCP clients commonly talk to MCP servers over stdio (JSON-RPC 2.0 with
  Content-Length framing). Snowflake-managed MCP servers speak MCP over HTTP.

  This bridge proxies MCP requests from stdio -> Snowflake HTTP endpoint, and
  proxies responses back to stdio.

Security:
  - Never hardcode tokens. Provide PAT via env var.
  - Prefer OAuth in production; PAT is OK for demos with least-privileged roles.

Environment variables:
  - SNOWFLAKE_ACCOUNT_URL: e.g. https://abc12345.us-east-1.snowflakecomputing.com
  - SNOWFLAKE_PAT: Programmatic Access Token (Bearer)
  - SNOWFLAKE_MCP_DATABASE: default SNOWFLAKE_EXAMPLE
  - SNOWFLAKE_MCP_SCHEMA: default MCP_SNOWFLAKE_BRIDGE
  - SNOWFLAKE_MCP_SERVER: default MCP_SNOWFLAKE_BRIDGE
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from typing import Any, Dict, Optional, Tuple

import requests


def _env(name: str, default: Optional[str] = None) -> str:
    v = os.getenv(name, default)
    if v is None or v.strip() == "":
        raise RuntimeError(f"Missing required environment variable: {name}")
    return v.strip()


@dataclass(frozen=True)
class SnowflakeMcpTarget:
    account_url: str
    database: str
    schema: str
    server: str
    pat: str

    @property
    def endpoint(self) -> str:
        base = self.account_url.rstrip("/")
        return f"{base}/api/v2/databases/{self.database}/schemas/{self.schema}/mcp-servers/{self.server}"


def _read_exact(stream, n: int) -> bytes:
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            raise EOFError("EOF while reading message body")
        buf.extend(chunk)
    return bytes(buf)


def _read_message(stdin) -> Optional[Dict[str, Any]]:
    """
    Read one MCP/JSON-RPC message from stdin using LSP-style Content-Length framing.
    Returns parsed JSON object or None on clean EOF.
    """
    # Read headers
    header_bytes = bytearray()
    while True:
        b = stdin.read(1)
        if not b:
            if not header_bytes:
                return None
            raise EOFError("EOF while reading headers")
        header_bytes.extend(b)
        if header_bytes.endswith(b"\r\n\r\n"):
            break

    header_text = header_bytes.decode("utf-8", errors="replace")
    headers: Dict[str, str] = {}
    for line in header_text.split("\r\n"):
        if not line or ":" not in line:
            continue
        k, v = line.split(":", 1)
        headers[k.strip().lower()] = v.strip()

    if "content-length" not in headers:
        raise ValueError("Missing Content-Length header")

    length = int(headers["content-length"])
    body = _read_exact(stdin, length)
    return json.loads(body.decode("utf-8"))


def _write_message(stdout, obj: Dict[str, Any]) -> None:
    payload = json.dumps(obj, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
    header = f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii")
    stdout.write(header)
    stdout.write(payload)
    stdout.flush()


def _jsonrpc_error(req: Dict[str, Any], code: int, message: str) -> Dict[str, Any]:
    return {
        "jsonrpc": "2.0",
        "id": req.get("id"),
        "error": {"code": code, "message": message},
    }


def _translate_initialize_result_if_needed(resp: Dict[str, Any]) -> Dict[str, Any]:
    """
    Snowflake docs show snake_case keys (proto_version/server_info). Some MCP clients
    expect the standard camelCase keys. Translate if present.
    """
    result = resp.get("result")
    if not isinstance(result, dict):
        return resp

    # Translate proto_version -> protocolVersion, server_info -> serverInfo
    if "proto_version" in result and "protocolVersion" not in result:
        result["protocolVersion"] = result.pop("proto_version")
    if "server_info" in result and "serverInfo" not in result:
        result["serverInfo"] = result.pop("server_info")
    resp["result"] = result
    return resp


def _handle_locally(req: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Snowflake-managed MCP servers (per docs) don't support resources/prompts/roots/etc.
    Intercept a few common calls so VS Code clients don't break.
    """
    method = req.get("method")
    if not isinstance(method, str):
        return None

    if method in ("resources/list", "prompts/list", "roots/list"):
        # Return empty list results in a best-effort compatible shape.
        key = method.split("/")[0]
        return {"jsonrpc": "2.0", "id": req.get("id"), "result": {key: []}}

    if method in ("resources/read", "prompts/get"):
        return _jsonrpc_error(req, -32601, f"Method not supported by Snowflake-managed MCP: {method}")

    if method == "initialize":
        # Ensure a protocolVersion is present.
        params = req.get("params") if isinstance(req.get("params"), dict) else {}
        params.setdefault("protocolVersion", "2025-06-18")
        req["params"] = params
        return None

    return None


def _call_snowflake(target: SnowflakeMcpTarget, req: Dict[str, Any]) -> Dict[str, Any]:
    r = requests.post(
        target.endpoint,
        headers={
            "Authorization": f"Bearer {target.pat}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        data=json.dumps(req, ensure_ascii=True),
        timeout=60,
    )
    try:
        out = r.json()
    except Exception:
        return {
            "jsonrpc": "2.0",
            "id": req.get("id"),
            "error": {"code": -32000, "message": f"Non-JSON response from Snowflake (HTTP {r.status_code})"},
        }

    if isinstance(out, dict) and req.get("method") == "initialize":
        out = _translate_initialize_result_if_needed(out)
    return out if isinstance(out, dict) else {"jsonrpc": "2.0", "id": req.get("id"), "result": out}


def main() -> int:
    try:
        target = SnowflakeMcpTarget(
            account_url=_env("SNOWFLAKE_ACCOUNT_URL"),
            pat=_env("SNOWFLAKE_PAT"),
            database=os.getenv("SNOWFLAKE_MCP_DATABASE", "SNOWFLAKE_EXAMPLE").strip(),
            schema=os.getenv("SNOWFLAKE_MCP_SCHEMA", "MCP_SNOWFLAKE_BRIDGE").strip(),
            server=os.getenv("SNOWFLAKE_MCP_SERVER", "MCP_SNOWFLAKE_BRIDGE").strip(),
        )
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer

    while True:
        try:
            req = _read_message(stdin)
            if req is None:
                return 0
        except Exception as e:
            print(f"ERROR reading MCP message: {e}", file=sys.stderr)
            return 2

        if not isinstance(req, dict):
            # Ignore garbage
            continue

        # Notifications have no id; per JSON-RPC, servers must not reply.
        if "id" not in req:
            # Best-effort: do not forward unsupported notification methods.
            continue

        local_resp = _handle_locally(req)
        if local_resp is not None:
            _write_message(stdout, local_resp)
            continue

        try:
            resp = _call_snowflake(target, req)
        except Exception as e:
            resp = _jsonrpc_error(req, -32000, f"Bridge error calling Snowflake: {e}")

        _write_message(stdout, resp)


if __name__ == "__main__":
    raise SystemExit(main())


