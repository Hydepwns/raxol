# `Raxol.Terminal.MemoryManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/memory_manager.ex#L1)

Manages memory usage and limits for the terminal emulator.

# `t`

```elixir
@type t() :: %Raxol.Terminal.MemoryManager{
  current_memory: non_neg_integer(),
  max_memory: non_neg_integer(),
  memory_limit: non_neg_integer()
}
```

# `check_and_cleanup`

Checks and cleans up memory if needed.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `estimate_memory_usage`

Estimates memory usage for the given state.
Returns the estimated memory usage in bytes.

# `get_limit`

Gets the memory limit.

# `get_memory_usage`

Gets the current memory usage.

# `get_usage`

Gets the current memory usage (alias for get_memory_usage).

# `handle_manager_cast`

# `handle_manager_info`

# `should_scroll?`

Checks if scrolling is needed based on memory usage.

# `start_link`

# `update_usage`

Updates memory usage for the given state.

# `within_limits?`

Checks if the current memory usage is within limits.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
