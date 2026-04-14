# `Raxol.Terminal.Buffer.BufferManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/buffer_manager.ex#L1)

Buffer manager for terminal operations.

This module provides a centralized interface for buffer management,
consolidating buffer operations for the terminal renderer.

# `batch_operations`

# `clear`

# `flush`

# `get_cell`

# `get_content`

# `get_cursor_position`

# `get_dimensions`

# `get_size`

# `resize`

# `set_cell`

# `start_link`

# `update_cursor_position`

# `write`

```elixir
@spec write(pid(), String.t()) :: {:ok, pid()}
```

Writes text to the buffer at the current cursor position.

This is a simplified interface that writes text character by character
starting at the current cursor position.

# `write_at`

```elixir
@spec write_at(pid(), non_neg_integer(), non_neg_integer(), String.t()) ::
  {:ok, pid()}
```

Writes text to the buffer at a specific position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
