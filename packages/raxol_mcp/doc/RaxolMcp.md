# `RaxolMcp`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol_mcp.ex#L1)

MCP (Model Context Protocol) server and client for Raxol.

Provides a standalone MCP implementation with:

- `Raxol.MCP.Protocol` -- JSON-RPC 2.0 encoding/decoding
- `Raxol.MCP.Registry` -- ETS-backed tool/resource registration
- `Raxol.MCP.Server` -- transport-agnostic message router
- `Raxol.MCP.Transport.Stdio` -- stdio transport for CLI tools
- `Raxol.MCP.Transport.SSE` -- HTTP/SSE transport (Plug-based)
- `Raxol.MCP.Client` -- client for consuming external MCP servers

# `version`

```elixir
@spec version() :: String.t()
```

Returns the package version.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
