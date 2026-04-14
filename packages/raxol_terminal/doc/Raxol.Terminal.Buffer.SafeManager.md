# `Raxol.Terminal.Buffer.SafeManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/safe_manager.ex#L1)

Safe buffer manager that handles buffer operations with error recovery.

This module provides a safe interface to buffer operations, ensuring
that failures don't crash the system and providing fallback behavior.

# `clear`

```elixir
@spec clear(pid() | atom()) :: :ok | {:error, term()}
```

Safely clears the buffer.

# `get_cell`

```elixir
@spec get_cell(pid() | atom(), non_neg_integer(), non_neg_integer()) ::
  {:ok, map()} | {:error, term()}
```

Safely gets a cell from the buffer.

# `info`

```elixir
@spec info(pid() | atom()) :: {:ok, map()} | {:error, term()}
```

Gets buffer info safely.

# `read`

```elixir
@spec read(pid() | atom(), non_neg_integer()) :: {:ok, binary()} | {:error, term()}
```

Safely reads from the buffer.

# `resize`

```elixir
@spec resize(pid() | atom(), non_neg_integer(), non_neg_integer()) ::
  :ok | {:error, term()}
```

Safely resizes the buffer.

# `scroll`

```elixir
@spec scroll(pid() | atom(), integer()) :: :ok | {:error, term()}
```

Safely scrolls the buffer.

# `set_cell`

```elixir
@spec set_cell(pid() | atom(), non_neg_integer(), non_neg_integer(), map()) ::
  :ok | {:error, term()}
```

Safely sets a cell in the buffer.

# `start_link`

```elixir
@spec start_link() :: {:ok, pid()} | {:error, term()}
```

Starts a safe manager process.

# `write`

```elixir
@spec write(pid() | atom(), binary()) :: :ok | {:error, term()}
```

Safely writes data to the buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
