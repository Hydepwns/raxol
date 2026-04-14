# `Raxol.Core.Runtime.Log`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/log.ex#L1)

Centralized logging system for Raxol with structured context, performance tracking,
and consistent formatting across all modules.

## Features

- Structured logging with automatic context enrichment
- Module-aware logging with automatic module detection
- Performance and timing utilities
- Standardized error handling with stacktraces
- Debug mode support with conditional logging
- Automatic metadata collection (node, environment, version)
- IO.puts/inspect migration helpers

## Usage

Instead of using Logger directly or IO.puts, use this module:

    # Basic logging
    Log.info("User authenticated successfully")
    Log.error("Database connection failed")

    # With context
    Log.info("Processing request", %{user_id: 123, action: :login})
    Log.error("Validation failed", %{errors: errors, input: input})

    # Performance timing
    Log.time_info("Database query", fn ->
      expensive_operation()
    end)

    # Module-aware logging (automatically detects calling module)
    Log.info("Operation completed")

    # Migration from IO.puts
    Log.console("Debug output for development")

# `context`

```elixir
@type context() :: map() | keyword() | nil
```

# `log_level`

```elixir
@type log_level() :: :debug | :info | :warn | :error
```

# `metadata`

```elixir
@type metadata() :: map()
```

# `auto_log`

Log with automatic error classification and severity detection.

# `console`

Console logging for development - replacement for IO.puts.
Only logs in development/test environments.

# `debug`

# `debug`

# `debug_if`

Conditional debug logging based on module configuration.

# `debug_with_context`

# `error`

# `error`

# `error_with_context`

# `error_with_stacktrace`

Logs an error with stacktrace and context.

# `event`

Structured event logging with automatic metadata enrichment.

# `info`

# `info`

# `info_with_context`

# `info_with_context`

# `log_inspect`

Structured inspect logging - replacement for IO.inspect.

# `module_debug`

Module-aware logging that automatically detects the calling module.

# `module_error`

# `module_info`

# `module_warning`

# `time_debug`

Performance timing logger that measures and logs execution time.

# `time_info`

# `time_warning`

# `warning`

# `warning`

# `warning_with_context`

Logs a warning with context.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
