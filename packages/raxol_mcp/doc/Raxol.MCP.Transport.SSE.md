# `Raxol.MCP.Transport.SSE`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/transport/sse.ex#L2)

HTTP/SSE transport for MCP.

Plug-based router providing JSON-RPC over HTTP POST and server-sent events
for notifications. No Phoenix dependency.

## Endpoints

- `POST /mcp` -- receive JSON-RPC request, return response
- `GET /mcp/sse` -- server-sent events stream for notifications
- `GET /health` -- health check

## Usage

Mount in a Plug pipeline or start standalone with `Plug.Cowboy`:

    Plug.Cowboy.http(Raxol.MCP.Transport.SSE, [server: Raxol.MCP.Server], port: 4001)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
