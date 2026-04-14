# `Raxol.Terminal.Buffer.Scrollback`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/scrollback.ex#L1)

Handles scrollback buffer operations for the screen buffer.
This module manages the history of lines that have scrolled off the screen,
including adding, retrieving, and clearing scrollback content.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Scrollback{limit: integer(), lines: list()}
```

# `add_line`

Adds a line to the scrollback buffer.

# `add_lines`

Adds multiple lines to the scrollback buffer.

# `cleanup`

Cleans up the scrollback buffer.

# `clear`

Clears the scrollback buffer.

# `full?`

Checks if the scrollback buffer is full.

# `get_limit`

Gets the current scrollback limit.

# `get_line`

Gets a specific line from the scrollback buffer.

# `get_lines`

Gets lines from the scrollback buffer.

# `get_memory_usage`

Gets the memory usage of the scrollback buffer.

# `get_newest_line`

Gets the newest line in the scrollback buffer.

# `get_oldest_line`

Gets the oldest line in the scrollback buffer.

# `new`

Returns a new scrollback buffer with default settings.

# `set_limit`

Sets the scrollback limit.

# `size`

Gets the total number of lines in the scrollback buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
