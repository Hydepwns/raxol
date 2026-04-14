# `Raxol.MCP.Registry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/registry.ex#L1)

ETS-backed registry for MCP tools and resources.

Any module can register tools and resources. The registry stores definitions
alongside callback functions that are invoked when tools are called or
resources are read.

Reads (`list_tools`, `call_tool`, `list_resources`, `read_resource`) go
directly to ETS with `read_concurrency: true` -- no GenServer bottleneck.
Writes (`register_*`, `unregister_*`) serialize through the GenServer.

## Tool Registration

    tools = [
      %{
        name: "raxol_screenshot",
        description: "Capture a screenshot",
        inputSchema: %{type: "object", properties: %{id: %{type: "string"}}},
        callback: fn args -> {:ok, [%{type: "text", text: "screenshot data"}]} end
      }
    ]
    Registry.register_tools(registry, tools)

## Resource Registration

    resources = [
      %{
        uri: "raxol://session/demo/model",
        name: "Session Model",
        description: "Current TEA model state",
        callback: fn -> {:ok, %{counter: 5}} end
      }
    ]
    Registry.register_resources(registry, resources)

# `prompt_def`

```elixir
@type prompt_def() :: %{
  name: String.t(),
  description: String.t(),
  arguments: [map()],
  callback: (map() -&gt; {:ok, [map()]} | {:error, term()})
}
```

# `resource_def`

```elixir
@type resource_def() :: %{
  uri: String.t(),
  name: String.t(),
  description: String.t(),
  callback: (-&gt; {:ok, term()} | {:error, term()})
}
```

# `tool_def`

```elixir
@type tool_def() :: %{
  name: String.t(),
  description: String.t(),
  inputSchema: map(),
  callback: (map() -&gt; {:ok, term()} | {:error, term()})
}
```

# `call_tool`

```elixir
@spec call_tool(GenServer.server(), String.t(), map()) ::
  {:ok, term()} | {:error, term()}
```

Call a registered tool by name with arguments.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `circuit_status`

```elixir
@spec circuit_status(GenServer.server(), Raxol.MCP.CircuitBreaker.key()) :: map()
```

Get circuit breaker status for a tool, resource, or prompt key.

# `get_prompt`

```elixir
@spec get_prompt(GenServer.server(), String.t(), map()) ::
  {:ok, [map()]} | {:error, term()}
```

Get a prompt by name, rendering it with the given arguments.

# `list_prompts`

```elixir
@spec list_prompts(GenServer.server()) :: [map()]
```

List all registered prompts (definitions without callbacks).

# `list_resources`

```elixir
@spec list_resources(GenServer.server()) :: [map()]
```

List all registered resources (definitions without callbacks).

# `list_tools`

```elixir
@spec list_tools(GenServer.server()) :: [map()]
```

List all registered tools (definitions without callbacks).

# `read_resource`

```elixir
@spec read_resource(GenServer.server(), String.t()) ::
  {:ok, term()} | {:error, term()}
```

Read a registered resource by URI.

# `register_prompts`

```elixir
@spec register_prompts(GenServer.server(), [prompt_def()]) :: :ok
```

Register one or more prompts.

# `register_resources`

```elixir
@spec register_resources(GenServer.server(), [resource_def()]) :: :ok
```

Register one or more resources.

# `register_tools`

```elixir
@spec register_tools(GenServer.server(), [tool_def()]) :: :ok
```

Register one or more tools.

# `reset_circuit`

```elixir
@spec reset_circuit(GenServer.server(), Raxol.MCP.CircuitBreaker.key()) :: :ok
```

Manually reset a circuit breaker.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Start the registry, linked to the calling process.

# `unregister_prompts`

```elixir
@spec unregister_prompts(GenServer.server(), [String.t()]) :: :ok
```

Unregister prompts by name.

# `unregister_resources`

```elixir
@spec unregister_resources(GenServer.server(), [String.t()]) :: :ok
```

Unregister resources by URI.

# `unregister_tools`

```elixir
@spec unregister_tools(GenServer.server(), [String.t()]) :: :ok
```

Unregister tools by name.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
