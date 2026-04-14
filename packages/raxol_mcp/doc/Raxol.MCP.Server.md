# `Raxol.MCP.Server`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/server.ex#L1)

Transport-agnostic MCP server.

Receives decoded JSON-RPC messages, dispatches to the Registry for tool/resource
operations, and returns response maps. Transports (stdio, SSE) call
`handle_message/2` and write the response back over their I/O channel.

## Supported Methods

- `initialize` -- MCP handshake, returns server capabilities
- `notifications/initialized` -- client acknowledgement (no reply)
- `ping` -- health check
- `tools/list` -- list registered tools
- `tools/call` -- invoke a tool
- `resources/list` -- list registered resources
- `resources/read` -- read a resource
- `prompts/list` -- list registered prompts
- `prompts/get` -- render a prompt with arguments
- `logging/setLevel` -- set server log level
- `completion/complete` -- auto-complete tool arguments

## Notifications

The server can push notifications to connected transports. Transports
subscribe via `subscribe/2` and receive `{:mcp_notification, map()}` messages.

# `t`

```elixir
@type t() :: %Raxol.MCP.Server{
  initialized: boolean(),
  log_level:
    :debug
    | :info
    | :notice
    | :warning
    | :error
    | :critical
    | :alert
    | :emergency,
  registry: GenServer.server(),
  resource_subscriptions: %{required(String.t()) =&gt; boolean()},
  subscribers: [pid()]
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `handle_message`

```elixir
@spec handle_message(GenServer.server(), map()) :: {:reply, map() | nil}
```

Handle a decoded JSON-RPC message.

Returns `{:reply, response_map}` for requests or `{:reply, nil}` for
notifications (no response needed).

# `notify`

```elixir
@spec notify(GenServer.server(), String.t(), map()) :: :ok
```

Send a notification to all subscribed transports.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Start the server, linked to the calling process.

# `subscribe`

```elixir
@spec subscribe(GenServer.server(), pid()) :: :ok
```

Subscribe a transport process to server notifications.

The subscriber receives `{:mcp_notification, notification_map}` messages.
Automatically unsubscribes when the subscriber process exits.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
