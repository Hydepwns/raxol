# `Raxol.Terminal.OperationsBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/operations_behaviour.ex#L1)

Defines the behaviour for core terminal operations.

This behaviour consolidates all the essential terminal operations that were previously
missing proper behaviour definitions. It includes operations for:
- Cursor management
- Screen manipulation
- Text input/output
- Selection handling
- Display control

# `color`

```elixir
@type color() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `dimensions`

```elixir
@type dimensions() :: {non_neg_integer(), non_neg_integer()}
```

# `position`

```elixir
@type position() :: {non_neg_integer(), non_neg_integer()}
```

# `scroll_region`

```elixir
@type scroll_region() :: {non_neg_integer(), non_neg_integer()}
```

# `style`

```elixir
@type style() :: map() | nil
```

# `t`

```elixir
@type t() :: term()
```

# `cleanup`

```elixir
@callback cleanup(t()) :: t()
```

# `clear_line`

```elixir
@callback clear_line(t(), non_neg_integer()) :: t()
```

# `clear_screen`

```elixir
@callback clear_screen(t()) :: t()
```

# `clear_selection`

```elixir
@callback clear_selection(t()) :: t()
```

# `cursor_blinking?`

```elixir
@callback cursor_blinking?(t()) :: boolean()
```

# `cursor_visible?`

```elixir
@callback cursor_visible?(t()) :: boolean()
```

# `delete_chars`

```elixir
@callback delete_chars(t(), non_neg_integer()) :: t()
```

# `delete_lines`

```elixir
@callback delete_lines(t(), non_neg_integer()) :: t()
```

# `erase_chars`

```elixir
@callback erase_chars(t(), non_neg_integer()) :: t()
```

# `erase_display`

```elixir
@callback erase_display(t(), atom()) :: t()
```

# `erase_from_cursor_to_end`

```elixir
@callback erase_from_cursor_to_end(t()) :: t()
```

# `erase_from_start_to_cursor`

```elixir
@callback erase_from_start_to_cursor(t()) :: t()
```

# `erase_in_display`

```elixir
@callback erase_in_display(t(), atom()) :: t()
```

# `erase_in_line`

```elixir
@callback erase_in_line(t(), atom()) :: t()
```

# `erase_line`

```elixir
@callback erase_line(t(), atom()) :: t()
```

# `get_cell_at`

```elixir
@callback get_cell_at(t(), non_neg_integer(), non_neg_integer()) ::
  Raxol.Terminal.Cell.t()
```

# `get_content`

```elixir
@callback get_content(t()) :: [[Raxol.Terminal.Cell.t()]]
```

# `get_cursor_position`

```elixir
@callback get_cursor_position(t()) :: position()
```

# `get_cursor_style`

```elixir
@callback get_cursor_style(t()) :: atom()
```

# `get_line`

```elixir
@callback get_line(t(), non_neg_integer()) :: [Raxol.Terminal.Cell.t()]
```

# `get_scroll_bottom`

```elixir
@callback get_scroll_bottom(t()) :: non_neg_integer()
```

# `get_scroll_region`

```elixir
@callback get_scroll_region(t()) :: scroll_region()
```

# `get_scroll_top`

```elixir
@callback get_scroll_top(t()) :: non_neg_integer()
```

# `get_selection`

```elixir
@callback get_selection(t()) :: {position(), position()}
```

# `get_selection_boundaries`

```elixir
@callback get_selection_boundaries(t()) :: {position(), position()}
```

# `get_selection_end`

```elixir
@callback get_selection_end(t()) :: position()
```

# `get_selection_start`

```elixir
@callback get_selection_start(t()) :: position()
```

# `get_state`

```elixir
@callback get_state(t()) :: map()
```

# `get_style`

```elixir
@callback get_style(t()) :: style()
```

# `get_text_in_region`

```elixir
@callback get_text_in_region(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: String.t()
```

# `in_selection?`

```elixir
@callback in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
```

# `insert_chars`

```elixir
@callback insert_chars(t(), non_neg_integer()) :: t()
```

# `insert_lines`

```elixir
@callback insert_lines(t(), non_neg_integer()) :: t()
```

# `prepend_lines`

```elixir
@callback prepend_lines(t(), non_neg_integer()) :: t()
```

# `reset_charset_state`

```elixir
@callback reset_charset_state(t()) :: t()
```

# `resolve_load_order`

```elixir
@callback resolve_load_order(t()) :: t()
```

# `selection_active?`

```elixir
@callback selection_active?(t()) :: boolean()
```

# `set_blink_rate`

```elixir
@callback set_blink_rate(t(), non_neg_integer()) :: t()
```

# `set_cursor_blink`

```elixir
@callback set_cursor_blink(t(), boolean()) :: t()
```

# `set_cursor_position`

```elixir
@callback set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
```

# `set_cursor_style`

```elixir
@callback set_cursor_style(t(), atom()) :: t()
```

# `set_cursor_visibility`

```elixir
@callback set_cursor_visibility(t(), boolean()) :: t()
```

# `set_scroll_region`

```elixir
@callback set_scroll_region(t(), scroll_region()) :: t()
```

# `start_selection`

```elixir
@callback start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
```

# `stop`

```elixir
@callback stop(t()) :: t()
```

# `toggle_blink`

```elixir
@callback toggle_blink(t()) :: t()
```

# `toggle_visibility`

```elixir
@callback toggle_visibility(t()) :: t()
```

# `update_blink`

```elixir
@callback update_blink(t()) :: t()
```

# `update_selection`

```elixir
@callback update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
```

# `write_string`

```elixir
@callback write_string(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  String.t(),
  style()
) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
