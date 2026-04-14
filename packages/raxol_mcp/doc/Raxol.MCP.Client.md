# `Raxol.MCP.Client`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/client.ex#L1)

MCP (Model Context Protocol) client for consuming external tool servers.

Manages a stdio-based MCP server process: spawns it, performs the
`initialize` handshake, discovers available tools via `tools/list`,
and executes tool calls via `tools/call`.

## Usage

    {:ok, client} = Client.start_link(
      name: :my_server,
      command: "npx",
      args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"]
    )

    {:ok, tools} = Client.list_tools(client)
    {:ok, result} = Client.call_tool(client, "read_file", %{path: "/tmp/hello.txt"})
    Client.stop(client)

## Tool Namespacing

Tools are namespaced with the server name prefix: `mcp__<server>__<tool>`.
Use `tool_name/2` to build namespaced names, and `parse_tool_name/1` to
decompose them.

# `call_result`

```elixir
@type call_result() :: %{content: [map()], is_error: boolean()}
```

# `t`

```elixir
@type t() :: %Raxol.MCP.Client{
  args: [String.t()],
  buffer: String.t(),
  call_timeout: pos_integer(),
  command: String.t(),
  env: [{String.t(), String.t()}],
  name: atom(),
  next_id: pos_integer(),
  pending: %{required(pos_integer()) =&gt; GenServer.from() | :init},
  port: port() | nil,
  registry: atom() | nil,
  status: :starting | :initializing | :ready | :closed,
  tools: [tool()] | nil
}
```

# `tool`

```elixir
@type tool() :: %{name: String.t(), description: String.t(), input_schema: map()}
```

# `call_tool`

```elixir
@spec call_tool(GenServer.server(), String.t(), map(), keyword()) ::
  {:ok, call_result()} | {:error, term()}
```

Call a tool on the MCP server.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `list_tools`

```elixir
@spec list_tools(
  GenServer.server(),
  keyword()
) :: {:ok, [tool()]} | {:error, term()}
```

List tools available on the MCP server.

# `parse_tool_name`

```elixir
@spec parse_tool_name(String.t()) :: {:ok, {String.t(), String.t()}} | :error
```

Parse a namespaced tool name into `{server, tool}` or `:error`.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Start an MCP client linked to the calling process.

# `status`

```elixir
@spec status(GenServer.server()) :: map()
```

Get the client's current status.

# `stop`

```elixir
@spec stop(GenServer.server()) :: :ok
```

Stop the MCP server and client.

# `tool_name`

```elixir
@spec tool_name(atom(), String.t()) :: String.t()
```

Build a namespaced tool name: `mcp__<server>__<tool>`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
