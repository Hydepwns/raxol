# `Raxol.Terminal.Emulator.SafeEmulator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/safe_emulator.ex#L1)

Enhanced terminal emulator with comprehensive error handling.
Refactored to use functional error handling patterns instead of try/catch.

# `error_stats`

```elixir
@type error_stats() :: %{
  total_errors: non_neg_integer(),
  errors_by_type: map(),
  last_error: {DateTime.t(), term()} | nil,
  recovery_attempts: non_neg_integer()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Emulator.SafeEmulator{
  config: map(),
  emulator_state: term(),
  error_stats: error_stats(),
  input_buffer: binary(),
  last_checkpoint: term(),
  recovery_state: atom()
}
```

# `checkpoint`

Performs checkpoint/restore operations.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_health`

Gets error statistics and health status.

# `get_state`

Gets the current terminal state with error recovery.

# `handle_manager_cast`

# `handle_sequence`

Safely handles ANSI sequences with fallback.

# `process_input`

Safely processes input with validation and error recovery.

# `recover`

Triggers recovery mechanism manually.

# `resize`

Safely resizes the terminal with validation.

# `restore`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
