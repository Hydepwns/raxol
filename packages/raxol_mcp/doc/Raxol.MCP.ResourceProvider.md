# `Raxol.MCP.ResourceProvider`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/resource_provider.ex#L1)

Behaviour for TEA apps that expose model state as MCP resources.

Apps implement `mcp_resources/0` to declare named projections of their
model. Each projection becomes a browsable MCP resource at
`raxol://session/{id}/model/{key}`.

## Example

    defmodule MyApp do
      use Raxol.UI, framework: :react
      @behaviour Raxol.MCP.ResourceProvider

      @impl Raxol.MCP.ResourceProvider
      def mcp_resources do
        [
          {"counters", &Map.get(&1, :counters, %{})},
          {"status", fn model -> %{state: model.state, uptime: model.uptime} end}
        ]
      end

      # ... init/1, update/2, view/1
    end

The `ToolSynchronizer` checks for this callback at init and registers
resources accordingly, updating them on each model change.

# `projection`

```elixir
@type projection() :: {String.t(), (map() -&gt; term())}
```

A named projection: `{key, fn model -> term end}`

# `mcp_resources`
*optional* 

```elixir
@callback mcp_resources() :: [projection()]
```

Return a list of named model projections.

Each tuple is `{key, projection_fn}` where `key` becomes the resource
path segment and `projection_fn` extracts data from the TEA model.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
