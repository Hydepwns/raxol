# `Raxol.Terminal.Rendering.RenderServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/render_server.ex#L1)

Provides a unified interface for terminal rendering operations.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Rendering.RenderServer{
  buffer: Raxol.Terminal.Buffer.t(),
  cache: map(),
  cursor_visible: boolean(),
  font_settings: map(),
  fps: integer(),
  screen: term(),
  style: term(),
  termbox_initialized: boolean(),
  theme: map(),
  title: String.t()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

```elixir
@spec cleanup(t()) :: :ok
```

Cleans up resources.

# `get_title`

```elixir
@spec get_title() :: String.t()
```

Gets the current window title.

# `handle_manager_call`

# `handle_manager_cast`

# `handle_manager_info`

# `init_manager`

Initializes the GenServer with default state.

# `init_terminal`

```elixir
@spec init_terminal() :: :ok
```

Initializes the terminal.

# `render`

```elixir
@spec render(t()) :: :ok
```

Renders the current state.

# `render`

```elixir
@spec render(t(), String.t()) :: :ok
```

Renders the current state with a specific renderer ID.

# `reset_config`

```elixir
@spec reset_config() :: :ok
```

Resets the configuration to defaults.

# `resize`

```elixir
@spec resize(non_neg_integer(), non_neg_integer()) :: :ok
```

Resizes the renderer.

# `set_config_value`

```elixir
@spec set_config_value(atom(), any()) :: :ok
```

Sets a specific configuration value.

# `set_cursor_visibility`

```elixir
@spec set_cursor_visibility(boolean()) :: :ok
```

Sets cursor visibility.

# `set_title`

```elixir
@spec set_title(String.t()) :: :ok
```

Sets the window title.

# `shutdown_terminal`

```elixir
@spec shutdown_terminal() :: :ok
```

Shuts down the terminal.

# `start_link`

# `update_config`

```elixir
@spec update_config(map()) :: :ok
```

Updates the renderer configuration with a single argument.

# `update_config`

```elixir
@spec update_config(t(), map()) :: :ok
```

Updates the renderer configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
