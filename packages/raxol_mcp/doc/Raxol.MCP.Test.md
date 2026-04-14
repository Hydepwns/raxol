# `Raxol.MCP.Test`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/test.ex#L1)

Test harness for Raxol MCP applications.

Provides session management, semantic interaction helpers, and a
pipe-friendly API for testing TUI apps via their MCP tool interface.

## Usage

    import Raxol.MCP.Test
    import Raxol.MCP.Test.Assertions

    test "user can search" do
      session = start_session(MyApp)

      session
      |> type_into("search_input", "elixir")
      |> click("search_btn")
      |> assert_widget("results_table", fn w -> w[:content] != nil end)
      |> stop_session()
    end

## How It Works

`start_session/2` spins up a headless TEA app (via `Raxol.Headless`),
a per-session `Raxol.MCP.Registry`, and a `ToolSynchronizer` that
auto-derives MCP tools from the view tree. Interaction helpers like
`click/2` and `type_into/3` call tools through the registry, exercising
the full MCP pipeline.

For unit tests that don't need a running app, use the lower-level
modules directly: `TreeWalker.derive_tools/2`, `Registry.call_tool/3`.

# `call_tool`

```elixir
@spec call_tool(Raxol.MCP.Test.Session.t(), String.t(), map()) ::
  Raxol.MCP.Test.Session.t()
```

Call an arbitrary MCP tool by its full name.

Returns the session for piping. Raises on failure.

    session |> call_tool("widget_id.action", %{"key" => "value"})

# `clear`

```elixir
@spec clear(Raxol.MCP.Test.Session.t(), String.t()) :: Raxol.MCP.Test.Session.t()
```

Clear an input widget by ID.

Calls the `widget_id.clear` tool through the MCP registry.

    session |> clear("search_input")

# `click`

```elixir
@spec click(Raxol.MCP.Test.Session.t(), String.t()) :: Raxol.MCP.Test.Session.t()
```

Click a button widget by ID.

Calls the `widget_id.click` tool through the MCP registry.

    session |> click("submit_btn")

# `get_model`

```elixir
@spec get_model(Raxol.MCP.Test.Session.t()) :: term()
```

Get the current TEA model from the session.

# `get_structured_widgets`

```elixir
@spec get_structured_widgets(Raxol.MCP.Test.Session.t()) :: [
  Raxol.MCP.StructuredScreenshot.widget_summary()
]
```

Get the structured widget tree (all widgets as summaries).

# `get_tools`

```elixir
@spec get_tools(Raxol.MCP.Test.Session.t()) :: [map()]
```

List all MCP tools currently registered for this session.

Returns tool definitions (name, description, inputSchema).

# `get_widget`

```elixir
@spec get_widget(Raxol.MCP.Test.Session.t(), String.t()) :: map() | nil
```

Find a widget by ID in the current view tree.

Returns the structured widget summary or `nil` if not found.

# `screenshot`

```elixir
@spec screenshot(Raxol.MCP.Test.Session.t()) :: String.t()
```

Get the plain text screenshot of the current session.

# `select`

```elixir
@spec select(Raxol.MCP.Test.Session.t(), String.t(), map()) ::
  Raxol.MCP.Test.Session.t()
```

Select a row in a table or item in a list by ID.

    session |> select("results_table", %{"index" => 0})

# `send_key`

```elixir
@spec send_key(Raxol.MCP.Test.Session.t(), atom() | String.t(), keyword()) ::
  Raxol.MCP.Test.Session.t()
```

Send a key event to the session via Headless.

This bypasses MCP tools -- use for navigation (Tab, Escape, arrow keys)
that don't map to widget tools.

    session |> send_key(:tab) |> send_key("q", ctrl: true)

# `send_keys`

```elixir
@spec send_keys(Raxol.MCP.Test.Session.t(), [
  atom() | String.t() | {atom() | String.t(), keyword()}
]) ::
  Raxol.MCP.Test.Session.t()
```

Send a sequence of key events.

    session |> send_keys([:tab, :tab, :enter])
    session |> send_keys([{"a", ctrl: true}, :escape])

# `start_session`

```elixir
@spec start_session(
  module() | String.t(),
  keyword()
) :: Raxol.MCP.Test.Session.t()
```

Start a headless MCP test session for the given TEA app module.

Returns a `%Session{}` struct that flows through all pipe-friendly helpers.

## Options

  * `:id` - session ID (default: auto-generated unique atom)
  * `:width` - terminal width (default: 120)
  * `:height` - terminal height (default: 40)
  * `:settle_ms` - ms to wait after start for initial render (default: 100)

# `stop_session`

```elixir
@spec stop_session(Raxol.MCP.Test.Session.t()) :: :ok
```

Stop a test session, cleaning up all resources.

Returns `:ok`. Can be used at the end of a pipe (the session is consumed).

# `toggle`

```elixir
@spec toggle(Raxol.MCP.Test.Session.t(), String.t()) :: Raxol.MCP.Test.Session.t()
```

Toggle a checkbox by ID.

    session |> toggle("remember_me")

# `type_into`

```elixir
@spec type_into(Raxol.MCP.Test.Session.t(), String.t(), String.t()) ::
  Raxol.MCP.Test.Session.t()
```

Type text into an input widget by ID.

Calls the `widget_id.type_into` tool through the MCP registry.

    session |> type_into("search_input", "elixir")

---

*Consult [api-reference.md](api-reference.md) for complete listing*
