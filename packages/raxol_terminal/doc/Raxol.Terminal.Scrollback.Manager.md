# `Raxol.Terminal.Scrollback.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scrollback/scrollback_manager.ex#L1)

Manages terminal scrollback buffer operations.

# `scrollback_buffer`

```elixir
@type scrollback_buffer() :: [scrollback_line()]
```

# `scrollback_line`

```elixir
@type scrollback_line() :: String.t()
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Scrollback.Manager{
  current_position: non_neg_integer(),
  scrollback_buffer: scrollback_buffer(),
  scrollback_limit: pos_integer()
}
```

# `add_to_scrollback`

Adds a line to the scrollback buffer.

# `clear_scrollback`

Clears the scrollback buffer.

# `get_current_line`

Gets the current line from the scrollback buffer.

# `get_current_position`

Gets the current scrollback position.

# `get_scrollback_buffer`

Gets the current scrollback buffer.

# `get_scrollback_limit`

Gets the scrollback limit.

# `get_scrollback_range`

Gets a range of lines from the scrollback buffer.

# `get_scrollback_size`

Gets the current size of the scrollback buffer.

# `new`

Creates a new scrollback manager instance.

# `scroll_down`

Scrolls down in the scrollback buffer.

# `scroll_up`

Scrolls up in the scrollback buffer.

# `scrollback_empty?`

Checks if the scrollback buffer is empty.

# `set_current_position`

Sets the current scrollback position.

# `set_scrollback_limit`

Sets the scrollback limit.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
