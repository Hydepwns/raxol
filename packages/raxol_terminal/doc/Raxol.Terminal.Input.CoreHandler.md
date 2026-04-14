# `Raxol.Terminal.Input.CoreHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/core_handler.ex#L1)

Core input handling functionality for the terminal emulator.
Manages the main input buffer and cursor state.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.CoreHandler{
  buffer: String.t(),
  cursor_position: non_neg_integer(),
  mode_manager: Raxol.Terminal.ModeManager.t(),
  tab_completion: map(),
  tab_completion_index: non_neg_integer(),
  tab_completion_matches: [String.t()]
}
```

# `insert_text`

```elixir
@spec insert_text(String.t(), non_neg_integer(), String.t()) :: String.t()
```

Inserts text at the specified position in the buffer.

# `new`

```elixir
@spec new() :: t()
```

Creates a new input handler with default values.

# `process_terminal_input`

```elixir
@spec process_terminal_input(map(), binary()) :: {map(), list()}
```

Processes a raw input string for the terminal, parsing control sequences and printable characters.
This function drives the terminal command parser.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
