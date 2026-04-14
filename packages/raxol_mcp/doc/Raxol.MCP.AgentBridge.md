# `Raxol.MCP.AgentBridge`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/agent_bridge.ex#L1)

Bridges Raxol Agent Actions to MCP tools.

Converts Action modules (which implement the `Raxol.Agent.Action` behaviour)
into MCP Registry tool definitions, allowing external MCP clients to invoke
agent capabilities.

## Usage

    actions = [MyApp.Actions.ReadFile, MyApp.Actions.WriteFile]
    tools = AgentBridge.actions_to_mcp_tools(actions)
    Raxol.MCP.Registry.register_tools(registry, tools)

The bridge also provides meta-tools for agent management:
`agent.list`, `agent.send`, `agent.get_model`.

# `actions_to_mcp_tools`

```elixir
@spec actions_to_mcp_tools([module()], map()) :: [Raxol.MCP.Registry.tool_def()]
```

Convert a list of Action modules to MCP tool definitions.

Each Action module must implement `__action_meta__/0` and `call/2`.
Tools are namespaced with `agent.` prefix.

# `meta_tools`

```elixir
@spec meta_tools() :: [Raxol.MCP.Registry.tool_def()]
```

Returns meta-tools for agent management: list, send, get_model.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
