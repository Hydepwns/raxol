# `Raxol.Terminal.Buffer.Selection`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/selection.ex#L1)

Manages text selection operations for the terminal.
This module handles all selection-related operations including:
- Starting and updating selections
- Getting selected text
- Checking if positions are within selections
- Managing selection boundaries
- Extracting text from regions

# `active?`

```elixir
@spec active?(Raxol.Terminal.ScreenBuffer.t()) :: boolean()
```

Checks if there is an active selection.

# `clear`

```elixir
@spec clear(Raxol.Terminal.ScreenBuffer.t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Clears the current selection.

# `contains?`

```elixir
@spec contains?(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
  boolean()
```

Checks if a position is within the current selection.

# `get_boundaries`

```elixir
@spec get_boundaries(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  | nil
```

Gets the current selection boundaries.

# `get_buffer_text`

```elixir
@spec get_buffer_text(Raxol.Terminal.ScreenBuffer.t()) ::
  {:ok, String.t()} | {:error, term()}
```

Gets the buffer text for the current selection.
This is an alias for get_text/1 for compatibility.

# `get_end_position`

```elixir
@spec get_end_position(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer()} | nil
```

Gets the selection end position.

# `get_line`

```elixir
@spec get_line([String.t()], non_neg_integer()) :: String.t()
```

Gets a line from a list of strings at the specified index.

# `get_start_position`

```elixir
@spec get_start_position(Raxol.Terminal.ScreenBuffer.t()) ::
  {non_neg_integer(), non_neg_integer()} | nil
```

Gets the selection start position.

# `get_text`

```elixir
@spec get_text(Raxol.Terminal.ScreenBuffer.t()) :: String.t()
```

Gets the currently selected text.

# `get_text_in_region`

```elixir
@spec get_text_in_region(
  Raxol.Terminal.ScreenBuffer.t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: String.t()
```

Gets text from a specified region in the buffer.

# `new`

```elixir
@spec new(
  {non_neg_integer(), non_neg_integer()},
  {non_neg_integer(), non_neg_integer()}
) ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

Creates a new selection with start and end positions.

# `start`

```elixir
@spec start(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Starts a text selection at the specified position.

# `update`

```elixir
@spec update(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Updates the current text selection to the specified position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
