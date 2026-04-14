# `Raxol.Terminal.ScreenBuffer.Selection`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/selection.ex#L1)

Text selection operations for the screen buffer.
Handles selection creation, updates, text extraction, and clipboard operations.

# `selection`

```elixir
@type selection() ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  | nil
```

# `clear_selection`

```elixir
@spec clear_selection(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Clears the current selection.

# `expand_selection_to_word`

```elixir
@spec expand_selection_to_word(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Expands selection to word boundaries.

# `extend_selection`

```elixir
@spec extend_selection(
  Raxol.Terminal.ScreenBuffer.Core.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Extends the selection to the specified position.
Starts a new selection if none exists.

# `get_selected_lines`

```elixir
@spec get_selected_lines(Raxol.Terminal.ScreenBuffer.Core.t()) :: [String.t()]
```

Gets the selected text as lines.

# `get_selected_text`

```elixir
@spec get_selected_text(Raxol.Terminal.ScreenBuffer.Core.t()) :: String.t()
```

Gets the selected text as a string.

# `get_selection`

```elixir
@spec get_selection(Raxol.Terminal.ScreenBuffer.Core.t()) :: selection()
```

Gets the current selection boundaries, normalized so start <= end.

# `get_selection_boundaries`

```elixir
@spec get_selection_boundaries(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  {{non_neg_integer(), non_neg_integer()},
   {non_neg_integer(), non_neg_integer()}}
  | nil
```

# `get_selection_end`

```elixir
@spec get_selection_end(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  {non_neg_integer(), non_neg_integer()} | nil
```

# `get_selection_start`

```elixir
@spec get_selection_start(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  {non_neg_integer(), non_neg_integer()} | nil
```

# `has_selection?`

```elixir
@spec has_selection?(Raxol.Terminal.ScreenBuffer.Core.t()) :: boolean()
```

Checks if there is an active selection.

# `position_in_selection?`

```elixir
@spec position_in_selection?(
  Raxol.Terminal.ScreenBuffer.Core.t(),
  integer(),
  integer()
) :: boolean()
```

Checks if a position is within the current selection.
Delegates to `selected?/3`.

# `select_all`

```elixir
@spec select_all(Raxol.Terminal.ScreenBuffer.Core.t()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Selects all content in the buffer.

# `select_line`

```elixir
@spec select_line(Raxol.Terminal.ScreenBuffer.Core.t(), integer()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Selects an entire line.

# `select_lines`

```elixir
@spec select_lines(Raxol.Terminal.ScreenBuffer.Core.t(), integer(), integer()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Selects multiple lines.

# `select_word`

```elixir
@spec select_word(Raxol.Terminal.ScreenBuffer.Core.t(), integer(), integer()) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Selects a word at the given position.

# `selected?`

```elixir
@spec selected?(Raxol.Terminal.ScreenBuffer.Core.t(), integer(), integer()) ::
  boolean()
```

Checks if the specified position is within the current selection.

# `selection_active?`

```elixir
@spec selection_active?(Raxol.Terminal.ScreenBuffer.Core.t()) :: boolean()
```

Delegates to `has_selection?/1`.

# `start_selection`

```elixir
@spec start_selection(
  Raxol.Terminal.ScreenBuffer.Core.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Starts a new selection at the specified position.

# `update_selection`

```elixir
@spec update_selection(
  Raxol.Terminal.ScreenBuffer.Core.t(),
  non_neg_integer(),
  non_neg_integer()
) ::
  Raxol.Terminal.ScreenBuffer.Core.t()
```

Updates the selection endpoint. Returns buffer unchanged if no selection exists.
Unlike `extend_selection/3`, does not start a new selection on nil.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
