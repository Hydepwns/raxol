# `Raxol.Terminal.Input.InputBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/input_buffer.ex#L1)

A simple data structure for managing input buffer state.

This module provides a stateless API for managing input buffer data,
separate from the GenServer-based Buffer module that handles process-based buffering.

# `overflow_mode`

```elixir
@type overflow_mode() :: :truncate | :wrap | :error
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Input.InputBuffer{
  contents: binary(),
  max_size: non_neg_integer(),
  overflow_mode: overflow_mode()
}
```

# `append`

Appends data to the buffer.

# `backspace`

Removes the last character from the buffer (backspace).

# `clear`

Clears the buffer contents.

# `delete_first`

Removes the first character from the buffer.

# `empty?`

Checks if the buffer is empty.

# `get_contents`

Gets the current contents of the buffer.

# `insert_at`

Inserts a character at the specified position.

# `max_size`

Gets the maximum size of the buffer.

# `new`

Creates a new input buffer with default values.

# `new`

Creates a new input buffer with custom max_size and overflow_mode.

# `overflow_mode`

Gets the overflow mode of the buffer.

# `prepend`

Prepends data to the buffer.

# `replace_at`

Replaces a character at the specified position.

# `set_contents`

Sets the contents of the buffer, handling overflow according to the buffer's mode.

# `set_max_size`

Sets the maximum size of the buffer.

# `set_overflow_mode`

Sets the overflow mode of the buffer.

# `size`

Gets the current size (byte count) of the buffer contents.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
