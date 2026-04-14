# `Raxol.Terminal.Selection.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/selection/selection_manager.ex#L1)

Manages text selection operations in the terminal.

# `position`

```elixir
@type position() :: {non_neg_integer(), non_neg_integer()}
```

# `selection_mode`

```elixir
@type selection_mode() :: :normal | :word | :line
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Selection.Manager{
  active: boolean(),
  end_pos: position() | nil,
  mode: selection_mode(),
  scrollback_included: boolean(),
  start_pos: position() | nil
}
```

# `end_selection`

Ends the current selection.

# `get_selected_text`

Gets the selected text from the terminal buffer.

# `get_selection_range`

Gets the current selection range.

# `include_scrollback`

Includes scrollback buffer in selection.

# `new`

Creates a new selection manager instance.

# `position_in_selection?`

Checks if a position is within the current selection.

# `scrollback_included?`

Checks if scrollback is included in selection.

# `start_selection`

Starts a new selection at the given position.

# `update_selection`

Updates the selection end position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
