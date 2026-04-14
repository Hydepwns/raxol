# `Raxol.Terminal.HistoryBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/history_buffer.ex#L1)

Manages terminal command history buffer operations.
This module handles the storage and retrieval of command history.

# `t`

```elixir
@type t() :: %Raxol.Terminal.HistoryBuffer{
  commands: [String.t()],
  max_size: non_neg_integer(),
  position: integer()
}
```

# `add_command`

```elixir
@spec add_command(t(), String.t()) :: t()
```

Adds a command to the history buffer.

# `clear`

```elixir
@spec clear(t()) :: t()
```

Clears the command history.

# `get_all_commands`

```elixir
@spec get_all_commands(t()) :: [String.t()]
```

Gets all commands in history.

# `get_command_at`

```elixir
@spec get_command_at(t(), integer()) :: {:ok, String.t()} | {:error, String.t()}
```

Gets the command at the specified index.

# `get_max_size`

```elixir
@spec get_max_size(t()) :: non_neg_integer()
```

Gets the maximum history size.

# `get_position`

```elixir
@spec get_position(t()) :: integer()
```

Gets the current history position.

# `get_size`

```elixir
@spec get_size(t()) :: non_neg_integer()
```

Gets the history size.

# `load_from_file`

```elixir
@spec load_from_file(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
```

Loads history from a file.

# `new`

```elixir
@spec new(non_neg_integer()) :: t()
```

Creates a new history buffer with the specified maximum size.

# `next_command`

```elixir
@spec next_command(t()) :: {:ok, t(), String.t()} | {:error, String.t()}
```

Moves to the next command in history.

# `previous_command`

```elixir
@spec previous_command(t()) :: {:ok, t(), String.t()} | {:error, String.t()}
```

Moves to the previous command in history.

# `save_to_file`

```elixir
@spec save_to_file(t(), String.t()) :: :ok | {:error, String.t()}
```

Saves the history to a file.

# `set_max_size`

```elixir
@spec set_max_size(t(), non_neg_integer()) :: t()
```

Sets the maximum history size.

# `set_position`

```elixir
@spec set_position(t(), integer()) :: t()
```

Sets the history position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
