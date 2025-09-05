---
title: Development Guide
description: Setup and development workflow for Raxol
date: 2025-07-25
author: Raxol Team
section: documentation
tags: [development, setup, nix, workflow]
---

# Development Guide

This guide explains how to set up and work with the Raxol development environment using Nix.

> **📚 For Architecture Context**: See [Architecture Decision Records](./adr/README.md) for detailed background on all major architectural decisions and design rationale.

## Recent Infrastructure Improvements

### Error Handling Framework
- **Module**: `Raxol.Core.ErrorHandler` - Centralized error handling with logging and recovery
- **Module**: `Raxol.Core.ErrorRecovery` - Circuit breakers, retries, and graceful degradation
- **Usage**: Wrap critical operations with `with_error_handling` macro
- **Example**: See `SafeLifecycleOperations` for plugin lifecycle error handling

### Performance Tools
- **Module**: `Raxol.Core.Performance.Profiler` - Profile code execution and identify bottlenecks
- **Module**: `Raxol.Core.Performance.Optimizer` - Caching, batching, and optimization utilities
- **Usage**: Use `profile` macro to measure performance, `cached` for caching operations

### Security Infrastructure
- **Module**: `Raxol.Security.Auditor` - Input validation and security checks
- **Module**: `Raxol.Security.SessionManager` - Secure session management
- **Module**: `Raxol.Security.InputValidator` - Schema-based input validation

### Functional Programming Standards (v1.1.0)
- **Module**: `Raxol.Core.ErrorHandling` - Functional error handling with Result types
- **Guide**: `docs/ERROR_HANDLING_GUIDE.md` - Comprehensive error handling patterns
- **Migration**: `docs/guides/FUNCTIONAL_PROGRAMMING_MIGRATION.md` - Migration from imperative patterns
- **Performance**: 7 hot-path caches with 30-70% improvements

### Code Standards
- **Module**: `Raxol.Core.Standards.CodeStyle` - Coding standards and patterns
- **Module**: `Raxol.Core.Standards.ConsistencyChecker` - Automated consistency checking
- **Module**: `Raxol.Core.Standards.CodeGenerator` - Code generation templates
- **Mix Task**: `mix raxol.check_consistency` - Check code consistency

## Prerequisites

- [Nix](https://nixos.org/download.html) installed on your system
- [direnv](https://direnv.net/) (optional, but recommended)

## Quick Setup

1. **Clone the repository**:

   ```bash
   git clone https://github.com/Hydepwns/raxol.git
   cd raxol
   ```

2. **Enter the development environment**:

   ```bash
   nix-shell
   ```

   Or if you have direnv installed, it will automatically load the environment when you `cd` into the project.

3. **Install dependencies**:

   ```bash
   mix deps.get
   git submodule update --init --recursive
   ```

4. **Setup the project**:

   ```bash
   mix setup
   ```

## What's Included

The Nix environment provides:

- **Erlang 25.3.2.7** and **Elixir 1.17.1** (matching `.tool-versions`)
- **PostgreSQL 15** with automatic setup and management
- **Build tools**: gcc, make, cmake, pkg-config
- **Image processing**: ImageMagick (for mogrify)
- **Node.js 20** (for esbuild and other JS tools)
- **Development utilities**: git, curl, wget
- **System libraries**: libffi, openssl, zlib, ncurses

## Development Workflow

### Starting the Environment

```bash
# Enter the shell
nix-shell

# The shell will automatically:
# - Set up Erlang/Elixir paths
# - Initialize PostgreSQL if needed
# - Start PostgreSQL if not running
# - Set up environment variables for termbox2_nif compilation
```

### Common Commands

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Start Phoenix server
mix phx.server

# Run credo (code quality)
mix credo

# Generate documentation
mix docs

# Stop PostgreSQL (when done)
pg_ctl -D $PGDATA stop
```

### Database Management

The Nix environment automatically manages a local PostgreSQL instance:

- **Data directory**: `$PWD/.postgres`
- **Port**: 5432
- **Authentication**: Trust (no password required)

```bash
# Check database status
pg_ctl -D $PGDATA status

# Stop database
pg_ctl -D $PGDATA stop

# Start database
pg_ctl -D $PGDATA start

# Reset database
mix ecto.reset
```

### Building Native Dependencies

The `termbox2_nif` dependency requires C compilation. The environment is configured to handle this automatically:

```bash
# The environment variables are set automatically:
# - ERL_EI_INCLUDE_DIR
# - ERL_EI_LIBDIR
# - ERLANG_PATH

# Compile dependencies
mix deps.compile
```

## Troubleshooting

### PostgreSQL Issues

If PostgreSQL fails to start:

```bash
# Remove the data directory and reinitialize
rm -rf .postgres
nix-shell  # This will reinitialize the database
```

### Compilation Issues

If you encounter compilation errors:

```bash
# Clean and rebuild
mix deps.clean --all
mix deps.get
mix deps.compile
```

### Nix Cache Issues

If you encounter Nix cache issues:

```bash
# Update Nix cache
nix-channel --update
nix-env -u

# Or rebuild the shell
nix-shell --run "echo 'Shell rebuilt'"
```

## Environment Variables

The following environment variables are set automatically:

- `ERLANG_PATH`: Path to Erlang installation
- `ELIXIR_PATH`: Path to Elixir installation
- `ERL_EI_INCLUDE_DIR`: Erlang include directory
- `ERL_EI_LIBDIR`: Erlang library directory
- `PGDATA`: PostgreSQL data directory
- `PGHOST`: PostgreSQL host
- `PGPORT`: PostgreSQL port (5432)
- `MIX_ENV`: Mix environment (dev)
- `MAGICK_HOME`: ImageMagick installation path

## Contributing

When contributing to Raxol:

1. Use the Nix environment for consistent development
2. Run tests before submitting: `mix test`
3. Check code quality: `mix credo`
4. Update documentation if needed
5. Follow functional programming patterns (see guides below)

### Functional Programming Best Practices (v1.1.0)

As of v1.1.0, Raxol follows strict functional programming principles with a 97.1% reduction in try/catch blocks and 100% elimination of Process Dictionary usage.

#### Core Principles

1. **Explicit Error Handling**: All errors must be explicit in function signatures
2. **Immutability**: No Process Dictionary or mutable state
3. **Composability**: Functions should compose well with pipelines
4. **Pattern Matching**: Prefer pattern matching over conditionals

#### Error Handling Patterns (Required for all new code)

```elixir
# ✅ GOOD: Use Result types with explicit error handling
alias Raxol.Core.ErrorHandling

def process_data(input) do
  with {:ok, validated} <- validate_input(input),
       {:ok, transformed} <- transform_data(validated),
       {:ok, result} <- save_result(transformed) do
    {:ok, result}
  end
end

# ✅ GOOD: Use safe_call for potentially failing operations
def fetch_user_data(user_id) do
  ErrorHandling.safe_call(fn -> 
    Database.get_user!(user_id)
  end)
end

# ✅ GOOD: Use safe_genserver_call for server operations  
def get_server_state(server) do
  ErrorHandling.safe_genserver_call(server, :get_state, 5000)
end

# ✅ GOOD: Use safe_call_with_info for debugging
def debug_operation(data) do
  case ErrorHandling.safe_call_with_info(fn -> complex_operation(data) end) do
    {:ok, result} -> result
    {:error, {kind, reason, stacktrace}} ->
      Logger.error("Operation failed", 
        kind: kind, 
        reason: reason, 
        stacktrace: stacktrace
      )
      {:error, :operation_failed}
  end
end

# ❌ BAD: Avoid try/catch for control flow
def bad_pattern(data) do
  try do
    risky_operation(data)
  rescue
    _ -> default_value()
  end
end

# ❌ BAD: Avoid Process Dictionary
def bad_context_pattern() do
  Process.put(:context, value)
  # ... code ...
  Process.get(:context)
end

# ❌ BAD: Avoid excessive conditionals
def bad_conditional(value) do
  cond do
    value < 0 -> :negative
    value == 0 -> :zero
    value > 0 -> :positive
  end
end
```

#### Pattern Matching Best Practices

```elixir
# ✅ GOOD: Use function heads for pattern matching
def process_message({:data, payload}), do: handle_data(payload)
def process_message({:error, reason}), do: handle_error(reason)
def process_message({:command, cmd}), do: execute_command(cmd)
def process_message(_unknown), do: {:error, :unknown_message}

# ✅ GOOD: Use guard clauses
def validate_age(age) when is_integer(age) and age >= 0 and age <= 150 do
  {:ok, age}
end
def validate_age(_), do: {:error, :invalid_age}
```

#### Pipeline Composition

```elixir
# ✅ GOOD: Use pipeline-friendly functions
def process_order(order_data) do
  order_data
  |> validate_order()
  |> calculate_totals()
  |> apply_discounts()
  |> generate_invoice()
  |> send_confirmation()
end

# Each function returns {:ok, data} or {:error, reason}
defp validate_order(data) do
  # validation logic
  {:ok, data}
end
```

#### State Management

```elixir
# ✅ GOOD: Use immutable state transformations
def update_user(user, changes) do
  user
  |> Map.merge(changes)
  |> validate_user()
  |> save_user()
end

# ❌ BAD: Don't mutate state
def bad_update(user, changes) do
  # Don't do this - Process Dictionary is banned
  Process.put(:user, Map.merge(user, changes))
end
```

#### Performance Guidelines

- **Caching**: Use the 7 established cache modules for hot paths
- **Lazy Evaluation**: Use streams for large datasets
- **Tail Recursion**: Ensure recursive functions are tail-call optimized
- **Benchmarking**: Profile before optimizing (use `Raxol.Benchmark`)

```elixir
# ✅ GOOD: Tail-recursive accumulator pattern
def sum_list(list, acc \\ 0)
def sum_list([], acc), do: acc
def sum_list([h | t], acc), do: sum_list(t, acc + h)

# ✅ GOOD: Stream processing for large data
def process_large_file(path) do
  path
  |> File.stream!()
  |> Stream.map(&parse_line/1)
  |> Stream.filter(&valid?/1)
  |> Stream.map(&transform/1)
  |> Enum.to_list()
end
```

#### Testing Functional Code

```elixir
# Test both success and failure paths
describe "functional error handling" do
  test "successful operation returns ok tuple" do
    assert {:ok, result} = MyModule.safe_operation(valid_input)
    assert result == expected_value
  end
  
  test "failed operation returns error tuple" do
    assert {:error, reason} = MyModule.safe_operation(invalid_input)
    assert reason == :invalid_input
  end
  
  test "pipeline stops on first error" do
    result = 
      {:ok, "data"}
      |> MyModule.step1()
      |> MyModule.step2_that_fails()
      |> MyModule.step3()
    
    assert {:error, :step2_failed} = result
  end
end
```

#### Code Organization

- **Module Cohesion**: One module, one responsibility
- **Function Size**: Keep functions under 20 lines
- **Type Specifications**: All public functions must have @spec
- **Documentation**: Document error conditions in @doc
- **Naming**: Use descriptive names that indicate Result types (e.g., `safe_fetch`, `try_connect`)

## Advanced Usage

### Custom Nix Configuration

You can customize the Nix environment by modifying `shell.nix`:

```nix
# Add additional packages
devTools = with pinnedPkgs; [
  # ... existing tools ...
  your-custom-package
];
```

### Building with Nix

You can also build the project using Nix:

```bash
# Build the project
nix-build

# The result will be in ./result/
```

### Flakes (Experimental)

If you prefer using Nix flakes, you can create a `flake.nix` file based on the existing `shell.nix` and `default.nix` files.

## Support

If you encounter issues with the Nix setup:

1. Check the [Nix documentation](https://nixos.org/guides/)
2. Verify your Nix installation: `nix --version`
3. Try updating Nix: `nix-channel --update`
4. Open an issue on GitHub with details about your environment
