# `Raxol.Terminal.Session`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session.ex#L1)

Terminal session module.

This module manages terminal sessions with pure functional patterns.

REFACTORED: All try/rescue blocks replaced with functional error handling.

Features:
- Session lifecycle
- Input/output handling
- State management
- Configuration
- Session persistence and recovery

# `t`

```elixir
@type t() :: %Raxol.Terminal.Session{
  auto_save: boolean(),
  emulator: Raxol.Terminal.Emulator.Struct.t(),
  height: non_neg_integer() | nil,
  id: String.t(),
  renderer: Raxol.Terminal.Renderer.t(),
  theme: map() | nil,
  title: String.t() | nil,
  width: non_neg_integer() | nil
}
```

# `count_active_sessions`

```elixir
@spec count_active_sessions() :: non_neg_integer()
```

# `get_state`

```elixir
@spec get_state(GenServer.server()) :: t()
```

Gets the current state of a terminal session.

## Examples

    iex> {:ok, pid} = Session.start_link()
    iex> state = Session.get_state(pid)
    iex> state.width
    80

# `list_saved_sessions`

```elixir
@spec list_saved_sessions() :: {:ok, [String.t()]} | {:error, term()}
```

Lists all saved sessions.

# `load_session`

```elixir
@spec load_session(String.t()) :: {:ok, pid()} | {:error, term()}
```

Loads a session from persistent storage.

# `save_session`

```elixir
@spec save_session(GenServer.server()) :: :ok
```

Saves the current session state to persistent storage.

# `send_input`

```elixir
@spec send_input(GenServer.server(), String.t()) :: :ok
```

Sends input to a terminal session.

## Examples

    iex> {:ok, pid} = Session.start_link()
    iex> :ok = Session.send_input(pid, "test")
    iex> state = Session.get_state(pid)
    iex> state.input.buffer
    "test"

# `set_auto_save`

```elixir
@spec set_auto_save(GenServer.server(), boolean()) :: :ok
```

Sets whether the session should be automatically saved.

# `start_link`

# `stop`

```elixir
@spec stop(GenServer.server()) :: :ok
```

Stops a terminal session.

## Examples

    iex> {:ok, pid} = Session.start_link()
    iex> :ok = Session.stop(pid)
    iex> Process.alive?(pid)
    false

# `update_config`

```elixir
@spec update_config(GenServer.server(), map()) :: :ok
```

Updates the configuration of a terminal session.

## Examples

    iex> {:ok, pid} = Session.start_link()
    iex> :ok = Session.update_config(pid, %{width: 100, height: 30})
    iex> state = Session.get_state(pid)
    iex> state.width
    100

---

*Consult [api-reference.md](api-reference.md) for complete listing*
