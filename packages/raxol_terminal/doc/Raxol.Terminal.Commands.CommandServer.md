# `Raxol.Terminal.Commands.CommandServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/command_server.ex#L1)

Unified command handler that consolidates all terminal command processing.

Routes commands to specialized handler modules:
- `CommandServer.CursorOps` -- cursor movement and positioning
- `CommandServer.EraseOps` -- screen/line/character erase
- `CommandServer.DeviceOps` -- DA/DSR device responses
- `CommandServer.ModeOps` -- ANSI/DEC mode set/reset
- `CommandServer.SGROps` -- SGR text formatting
- `CommandServer.BufferLineOps` -- insert/delete lines with scroll regions

# `command_params`

```elixir
@type command_params() :: %{
  type: command_type(),
  command: String.t(),
  params: [integer()],
  intermediates: String.t(),
  private_markers: String.t()
}
```

# `command_result`

```elixir
@type command_result() ::
  {:ok, Raxol.Terminal.Emulator.t()}
  | {:error, atom(), Raxol.Terminal.Emulator.t()}
```

# `command_type`

```elixir
@type command_type() :: :csi | :osc | :dcs | :escape | :control
```

# `handle_command`

```elixir
@spec handle_command(Raxol.Terminal.Emulator.t(), command_params()) ::
  command_result()
```

Processes any terminal command with unified handling.

# `handle_csi`

```elixir
@spec handle_csi(Raxol.Terminal.Emulator.t(), String.t(), [integer()], String.t()) ::
  command_result()
```

Handles CSI (Control Sequence Introducer) commands.

# `handle_osc`

```elixir
@spec handle_osc(Raxol.Terminal.Emulator.t(), String.t() | integer(), String.t()) ::
  command_result()
```

Handles OSC (Operating System Command) sequences.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
