# `Raxol.Terminal.Emulator.Output`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/output.ex#L1)

Handles output processing for the terminal emulator.
Provides functions for output buffering, processing, and formatting.

# `clear_output_buffer`

Clears the output buffer.

# `get_output_buffer`

Gets the current output buffer content.

# `process_buffer`

Processes the output buffer and updates the emulator state.

# `process_output`

Processes output data and updates the emulator state.

# `write`

Writes data to the output buffer.

# `write_control`

```elixir
@spec write_control(Raxol.Terminal.Emulator.Struct.t(), char()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Writes a control character to the output buffer.
Returns {:ok, updated_emulator}.

# `write_escape`

```elixir
@spec write_escape(Raxol.Terminal.Emulator.Struct.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Writes an escape sequence to the output buffer.
Returns {:ok, updated_emulator}.

# `write_line`

```elixir
@spec write_line(Raxol.Terminal.Emulator.Struct.t(), String.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Writes a line to the output buffer.
Returns {:ok, updated_emulator}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
