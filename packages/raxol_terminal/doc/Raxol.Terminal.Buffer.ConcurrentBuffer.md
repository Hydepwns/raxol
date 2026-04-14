# `Raxol.Terminal.Buffer.ConcurrentBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/concurrent_buffer.ex#L1)

A thread-safe buffer implementation using GenServer for concurrent access.
Provides synchronous operations to ensure data integrity when multiple
processes are reading/writing to the buffer simultaneously.

# `batch`

```elixir
@spec batch(pid() | atom(), (Raxol.Terminal.Buffer.t() -&gt; Raxol.Terminal.Buffer.t())) ::
  :ok | {:error, term()}
```

Performs a batch of operations atomically.

# `batch_operations`

```elixir
@spec batch_operations(pid() | atom(), list()) :: :ok | {:error, term()}
```

Performs a batch of operations from a list.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

```elixir
@spec clear(pid() | atom()) :: :ok
```

Clears the entire buffer.

# `fill_region`

```elixir
@spec fill_region(
  pid() | atom(),
  integer(),
  integer(),
  integer(),
  integer(),
  String.t(),
  map()
) :: :ok
```

Fills a region with a character.

# `flush`

```elixir
@spec flush(pid() | atom()) :: :ok
```

Flushes any pending operations (for compatibility).
Returns :ok immediately as operations are synchronous.

# `get_buffer`

```elixir
@spec get_buffer(pid() | atom()) ::
  {:ok, Raxol.Terminal.Buffer.t()} | {:error, term()}
```

Gets the current buffer state for reading.

# `get_cell`

```elixir
@spec get_cell(pid() | atom(), integer(), integer()) ::
  {:ok, Raxol.Terminal.Buffer.Cell.t()} | {:error, term()}
```

Gets a cell from the buffer.

# `handle_manager_cast`

# `handle_manager_info`

# `scroll`

```elixir
@spec scroll(pid() | atom(), integer()) :: :ok
```

Scrolls the buffer content.

# `set_cell`

```elixir
@spec set_cell(pid() | atom(), integer(), integer(), Raxol.Terminal.Buffer.Cell.t()) ::
  :ok | {:error, term()}
```

Sets a cell in the buffer.

# `start_link`

# `start_server`

```elixir
@spec start_server(keyword()) :: {:ok, pid()} | {:error, term()}
```

Starts a concurrent buffer server.

Options:
  - :width - Buffer width (default: 80)
  - :height - Buffer height (default: 24)
  - :name - GenServer name (optional)

# `stop`

```elixir
@spec stop(pid() | atom()) :: :ok
```

Stops the concurrent buffer server.

# `write`

```elixir
@spec write(pid() | atom(), integer(), integer(), String.t(), map()) ::
  :ok | {:error, term()}
```

Writes text starting at the given position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
