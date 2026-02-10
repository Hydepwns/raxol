# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Building & Compilation

```bash
MIX_ENV=test mix compile
MIX_ENV=test mix compile --warnings-as-errors
```

### Testing

```bash
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
MIX_ENV=test mix test test/path/to/test_file.exs      # specific file
MIX_ENV=test mix test test/path/to/test_file.exs:42   # specific line
MIX_ENV=test mix test --max-failures 5                 # limit failures
MIX_ENV=test mix test --failed                         # rerun failed
```

Note: TMPDIR and SKIP_TERMBOX2_TESTS are set automatically via `.claude/settings.local.json`.

### Code Quality

```bash
mix format                    # Format code
mix format --check-formatted  # Check formatting (CI)
mix credo                     # Style checks
mix dialyzer                  # Type checking
mix raxol.check               # All quality checks (format, credo, dialyzer)
mix raxol.check --quick       # Skip dialyzer
```

### Development

```bash
mix phx.server                # Start Phoenix server (includes Tidewave in dev)
mix raxol.gen.component Name  # Generate component
mix raxol.gen.specs lib/path  # Generate type specs for private functions
mix docs                      # Generate documentation
```

## Architecture

Raxol is a terminal application framework supporting multiple UI paradigms (React, LiveView, HEEx, Raw).

### Core Layers

```
lib/raxol/
├── terminal/     # Terminal emulation (VT100/ANSI)
│   ├── ansi/     # ANSI sequence parsing
│   ├── buffer/   # Screen buffer management
│   ├── cursor/   # Cursor state
│   ├── emulator/ # Terminal emulator
│   └── driver.ex # Platform-specific backend selection
├── ui/           # Multi-framework UI
│   ├── components/
│   ├── events/
│   └── theming/
└── core/         # Services and utilities
    ├── runtime/  # Plugin system
    └── error_handler.ex
```

### Key Architectural Decisions

**Multi-Framework UI**: Use via `use Raxol.UI, framework: :react/:liveview/:heex/:raw`

**Terminal Backend**: Automatic platform detection

- Unix/macOS: Native termbox2 NIF (`lib/termbox2_nif/c_src/`)
- Windows: Pure Elixir IOTerminal (`lib/raxol/terminal/io_terminal.ex`)
- Runtime selection in `lib/raxol/terminal/driver.ex`

**State Management**: ETS-backed UnifiedStateManager with BaseManager pattern

**Configuration**: TOML-based in `config/raxol.toml` with environment overrides in `config/environments/`

### Testing Patterns

- Always set `SKIP_TERMBOX2_TESTS=true` environment variable
- Test helpers in `test/support/`
- Use `Raxol.Terminal.DriverTestHelper` for terminal testing
- Property-based tests in `test/property/`

### Naming Conventions

- Module files: `<domain>_<function>.ex` (e.g., `cursor_manager.ex`, `buffer_server.ex`)
- Avoid generic names: `manager.ex`, `handler.ex`, `server.ex`

## Deployment

**Production**: Fly.io at `https://raxol.io`

```bash
flyctl deploy              # Deploy
flyctl status --app raxol  # Status
flyctl logs --app raxol    # Logs
```

Configuration: `fly.toml`, Dockerfile: `docker/Dockerfile.web`

## Project Notes

- Phoenix is used as a library - no Ecto.Repo auto-starting
- Themes stored in `priv/themes/` as JSON
- Never add coauthored-by claude or emojis to commits
- Domain: raxol.io (made by axol.io)
  <!-- usage-rules-start -->
  <!-- usage-rules-header -->

# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.

<!-- usage-rules-header-end -->

<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
