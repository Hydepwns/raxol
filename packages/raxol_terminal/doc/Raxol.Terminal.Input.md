# `Raxol.Terminal.Input`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input.ex#L1)

Handles input processing for the terminal.

# `completion_callback`

```elixir
@type completion_callback() :: (String.t() -&gt; [String.t()])
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input{
  buffer: list(),
  completion_callback: completion_callback() | nil,
  completion_index: non_neg_integer(),
  completion_options: [String.t()],
  last_click: {integer(), integer(), atom()} | nil,
  last_drag: {integer(), integer(), atom()} | nil,
  last_release: {integer(), integer(), atom()} | nil,
  state: atom()
}
```

# `clear_completion`

Clears completion state. Should be called when input changes other than tab completion.

# `example_completion_callback`

Example completion callback that provides Elixir keywords.

# `handle_click`

Handles a mouse click event.

# `handle_drag`

Handles a mouse drag event.

# `handle_release`

Handles a mouse release event.

# `new`

Creates a new input handler.

# `tab_complete`

Performs tab completion on the input buffer.
Uses the completion_callback to find matches and cycles through them.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
