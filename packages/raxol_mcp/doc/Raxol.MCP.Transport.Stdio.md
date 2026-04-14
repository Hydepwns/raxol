# `Raxol.MCP.Transport.Stdio`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/transport/stdio.ex#L1)

Stdio transport for MCP.

Reads JSON-RPC messages line-by-line from stdin, routes them to the
MCP Server, and writes responses to stdout. This is the transport used
by Claude Code and other CLI MCP clients.

## Notifications

Subscribes to the MCP Server for push notifications (e.g. `notifications/tools/list_changed`).
Notifications are written to stdout as unsolicited JSON-RPC messages.

## Important

When using this transport, configure Logger to write to stderr to avoid
corrupting the JSON-RPC stream on stdout:

    config :logger, :default_handler, %{config: %{type: :standard_error}}

Or at runtime:

    Logger.configure_backend(:console, device: :standard_error)

# `t`

```elixir
@type t() :: %Raxol.MCP.Transport.Stdio{
  io_device: IO.device(),
  output_device: IO.device(),
  reader_ref: reference() | nil,
  server: GenServer.server()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Start the stdio transport.

## Options

- `:server` -- MCP Server pid or name (default: `Raxol.MCP.Server`)
- `:name` -- GenServer name (optional)
- `:io_device` -- input device (default: `:stdio`), useful for testing
- `:output_device` -- output device (default: `:stdio`), useful for testing

---

*Consult [api-reference.md](api-reference.md) for complete listing*
