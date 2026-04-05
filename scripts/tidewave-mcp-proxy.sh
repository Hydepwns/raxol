#!/usr/bin/env bash
# stdio-to-HTTP MCP proxy for Tidewave
# Reads JSON-RPC from stdin, POSTs to Tidewave, writes response to stdout.
# Avoids Claude Code's HTTP OAuth discovery requirement.
set -euo pipefail

URL="${TIDEWAVE_URL:-http://localhost:4000/tidewave/mcp}"

while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue
  curl -s -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "$line"
  printf '\n'
done
