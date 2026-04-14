# `mix mcp.server`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/mix/tasks/mcp.server.ex#L1)

Starts the Raxol MCP server with stdio transport.

This is the entry point for Claude Code and other MCP clients.
Reads JSON-RPC messages from stdin, writes responses to stdout.

## Usage

    mix mcp.server

## .mcp.json Configuration

    {
      "mcpServers": {
        "raxol": {
          "type": "stdio",
          "command": "mix",
          "args": ["mcp.server"],
          "env": { "MIX_ENV": "dev" }
        }
      }
    }

---

*Consult [api-reference.md](api-reference.md) for complete listing*
