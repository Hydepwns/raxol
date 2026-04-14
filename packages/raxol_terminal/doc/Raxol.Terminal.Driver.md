# `Raxol.Terminal.Driver`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/driver.ex#L1)

Handles raw terminal input/output and event generation.

Responsibilities:
- Setting terminal mode (raw, echo)
- Reading input events via termbox2_nif NIF
- Parsing input events into `Raxol.Core.Events.Event` structs
- Detecting terminal resize events
- Sending parsed events to the `Dispatcher`
- Restoring terminal state on exit

# `dispatcher_pid`

```elixir
@type dispatcher_pid() :: pid() | nil
```

# `original_stty`

```elixir
@type original_stty() :: String.t()
```

# `termbox_state`

```elixir
@type termbox_state() :: :uninitialized | :initialized | :failed
```

# `backend`

```elixir
@spec backend() :: :termbox2_nif | :io_terminal
```

Returns the current terminal backend being used.

## Examples

    iex> Raxol.Terminal.Driver.backend()
    :termbox2_nif

    iex> Raxol.Terminal.Driver.backend()
    :io_terminal

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `handle_manager_call`

# `process_position_change`

Processes a terminal position change event.

# `process_title_change`

Processes a terminal title change event.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
