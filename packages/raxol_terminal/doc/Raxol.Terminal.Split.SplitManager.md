# `Raxol.Terminal.Split.SplitManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/split/split_manager.ex#L1)

Manages terminal split windows and panes.

Each split can optionally be bound to a `ConcurrentBuffer` pid and a
`TerminalProcess` pid, enabling the cockpit to map panes to live
terminal buffers.

# `t`

```elixir
@type t() :: %Raxol.Terminal.Split.SplitManager{
  buffer_pid: pid() | nil,
  content: map(),
  created_at: DateTime.t(),
  dimensions: %{width: integer(), height: integer()},
  id: integer(),
  label: String.t() | nil,
  position: %{x: integer(), y: integer()},
  terminal_pid: pid() | nil
}
```

# `bind_buffer`

```elixir
@spec bind_buffer(integer(), pid(), pid(), pid() | nil) ::
  {:ok, t()} | {:error, :not_found}
```

Binds a ConcurrentBuffer and optional TerminalProcess to a split.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_split`

```elixir
@spec create_split(map(), pid()) :: {:ok, t()} | {:error, term()}
```

Creates a new split with the given options.

# `get_split_buffer`

```elixir
@spec get_split_buffer(integer(), pid()) ::
  {:ok, pid()} | {:error, :not_found | :no_buffer}
```

Gets the buffer pid bound to a split.

# `handle_manager_cast`

# `handle_manager_info`

# `list_splits`

```elixir
@spec list_splits(pid()) :: [t()]
```

Lists all splits.

# `navigate_to_split`

```elixir
@spec navigate_to_split(integer(), pid()) :: {:ok, t()} | {:error, :not_found}
```

Navigates to an existing split.

# `remove_split`

```elixir
@spec remove_split(integer(), pid()) :: :ok | {:error, :not_found}
```

Removes a split by id.

# `resize_split`

```elixir
@spec resize_split(integer(), %{width: integer(), height: integer()}, pid()) ::
  {:ok, t()} | {:error, :not_found}
```

Resizes an existing split.

# `set_label`

```elixir
@spec set_label(integer(), String.t(), pid()) :: {:ok, t()} | {:error, :not_found}
```

Sets a label on a split (for display in pane headers).

# `start_link`

# `unbind_buffer`

```elixir
@spec unbind_buffer(integer(), pid()) :: {:ok, t()} | {:error, :not_found}
```

Unbinds the buffer from a split.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
