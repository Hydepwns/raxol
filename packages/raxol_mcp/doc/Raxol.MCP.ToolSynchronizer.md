# `Raxol.MCP.ToolSynchronizer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/tool_synchronizer.ex#L1)

Per-session GenServer that bridges the render pipeline to the MCP Registry.

Listens for `[:raxol, :runtime, :view_tree_updated]` telemetry events,
derives tools from the view tree via `TreeWalker`, diffs against the
previously registered set, and updates the Registry. Debounces rapid
renders (50ms) to avoid thrashing.

Also manages model-projected resources when the app implements
`Raxol.MCP.ResourceProvider`, and registers context tree + widget tree
resources for the session.

Started by `Raxol.Headless` when creating a session. Linked to the
session lifecycle -- dies when the session dies, cleaning up its tools.

## Usage

    {:ok, pid} = ToolSynchronizer.start_link(
      registry: Raxol.MCP.Registry,
      dispatcher_pid: dispatcher_pid,
      session_id: :my_session,
      app_module: MyApp
    )

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

Start a ToolSynchronizer linked to the calling process.

# `sync`

```elixir
@spec sync(GenServer.server(), map()) :: :ok
```

Force an immediate tool sync from the current view tree.

# `update_focus`

```elixir
@spec update_focus(GenServer.server(), String.t() | nil) :: :ok
```

Update the focused widget ID for FocusLens filtering.

When a widget gains focus (keyboard or mouse click), call this to
adjust which tools are exposed via `FocusLens`.

# `update_hover`

```elixir
@spec update_hover(GenServer.server(), String.t() | nil) :: :ok
```

Update the hovered widget ID for anticipatory tool exposure.

When the mouse hovers over a widget, call this so `FocusLens`
can pre-expose that widget's tools alongside the focused widget's.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
