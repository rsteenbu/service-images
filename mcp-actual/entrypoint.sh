#!/bin/sh
# Read BEARER_TOKEN from the file at $MCP_BEARER_TOKEN_FILE (docker-compose
# secrets are mounted here) so the secret lives on tmpfs, not in Config.Env.
set -eu
if [ -n "${MCP_BEARER_TOKEN_FILE:-}" ] && [ -r "$MCP_BEARER_TOKEN_FILE" ]; then
  BEARER_TOKEN="$(cat "$MCP_BEARER_TOKEN_FILE")"
  export BEARER_TOKEN
fi
exec actual-mcp "$@"
