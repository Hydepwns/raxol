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
mix raxol.check               # All checks: format, compile, credo, dialyzer, security, test
mix raxol.check --quick       # Skip dialyzer
mix raxol.check --only format,credo  # Run specific checks only
mix raxol.check --skip test   # Skip specific checks
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
├── terminal/        # Terminal emulation (VT100/ANSI)
│   ├── ansi/        # ANSI sequence parsing
│   ├── buffer/      # Screen buffer management
│   ├── commands/    # Command processing (CSI/OSC/DCS handlers, executor)
│   ├── emulator/    # Terminal emulator
│   ├── rendering/   # Terminal rendering (backend, GPU, styles)
│   └── driver.ex    # Platform-specific backend selection
├── ui/              # Multi-framework UI
│   ├── components/
│   ├── rendering/   # UI rendering pipeline
│   └── theming/
├── core/            # Services and utilities
│   ├── behaviours/  # BaseManager pattern for GenServers
│   ├── renderer/    # Core rendering primitives (layout, views)
│   ├── runtime/     # Plugin system
│   └── *_compat.ex  # Compatibility layers (Buffer, Renderer, Style, Box)
├── performance/     # Performance monitoring, profiling, caching
├── live_view/       # Phoenix LiveView integration
└── effects/         # Visual effects (CursorTrail, etc.)
```

### Key Architectural Decisions

**Multi-Framework UI**: Use via `use Raxol.UI, framework: :react/:liveview/:heex/:raw`

**Terminal Backend**: Automatic platform detection in `lib/raxol/terminal/driver.ex`
- Unix/macOS: Native termbox2 NIF (`lib/termbox2_nif/c_src/`)
- Windows: Pure Elixir IOTerminal (`lib/raxol/terminal/io_terminal.ex`)

**Compat Layer**: The `lib/raxol/core/*_compat.ex` files provide the public `Raxol.Core.*` API (Buffer, Renderer, Style, Box). These override modules from deps via `ignore_module_conflict: true` in mix.exs.

**BaseManager Pattern**: GenServers use `use Raxol.Core.Behaviours.BaseManager` for consistent lifecycle management.

**State Management**: ETS-backed UnifiedStateManager

**Configuration**: TOML-based in `config/raxol.toml` with environment overrides in `config/environments/`

### Buffer/Renderer API

The `Raxol.Core.Renderer` API:
- `render_diff/2` returns operation tuples: `[{:move, x, y}, {:write, text, style}, ...]`
- `apply_diff/1` converts operations to ANSI string for `IO.write/1`

```elixir
diff = Renderer.render_diff(old_buffer, new_buffer)
IO.write(Renderer.apply_diff(diff))  # NOT Enum.each(diff, &IO.write/1)
```

### Testing Patterns

**Test Tags** (auto-excluded based on environment):
- `@tag :docker` - Requires termbox2/Docker (excluded when `SKIP_TERMBOX2_TESTS=true`)
- `@tag :skip_on_ci` - Skip in CI (excluded when `SKIP_TERMBOX2_TESTS=true`)
- `@tag :unix_only` - Unix/macOS only (excluded on Windows)
- `@tag :slow` / `@tag :integration` - Long-running tests

**Test Infrastructure**:
- Test helpers in `test/support/` (IsolationHelper, TerminalTestHelper, etc.)
- `Raxol.Test.IsolationHelper.reset_global_state()` runs between tests
- Property-based tests in `test/property/`
- MockDB used instead of Ecto sandbox

### Naming Conventions

- Module files: `<domain>_<function>.ex` (e.g., `cursor_manager.ex`, `buffer_server.ex`)
- Avoid generic names: `manager.ex`, `handler.ex`, `server.ex`
- Effects use full module paths: `Raxol.Effects.CursorTrail` not bare `CursorTrail`

### Consolidated Namespaces

These namespaces have been consolidated - avoid creating new top-level alternatives:

- `Raxol.Terminal.Commands.*` - All command processing (not `terminal/command/` or `command_processor.ex`)
- `Raxol.Terminal.Rendering.*` - All terminal rendering (not `terminal/render/` or `terminal/renderer/`)
- `Raxol.Performance.*` - All performance tools (not `core/performance/`)
- `Raxol.LiveView.*` - LiveView integration (not `liveview/`)

## Environment Variables

**Required for tests** (set automatically in `.claude/settings.local.json`):
- `SKIP_TERMBOX2_TESTS=true` - Skip Docker/termbox2-dependent tests
- `TMPDIR=/tmp` - Temporary directory for test artifacts
- `MIX_ENV=test` - Required for test compilation

**Optional**:
- `CI=true` - Triggers CI-specific config
- `RAXOL_SKIP_TERMINAL_INIT=true` - Skip terminal init in certain contexts

## Development Scripts

```bash
./scripts/dev.sh test [pattern]  # Run tests with grep filter
./scripts/dev.sh test-all        # Comprehensive test suite
./scripts/dev.sh check           # Pre-commit quality checks
./scripts/dev.sh dialyzer        # Static analysis with PLT caching
./scripts/dev.sh setup           # Environment setup
```

## Dialyzer

- PLT cached in `priv/plts/` for faster reruns
- `.dialyzer_ignore.exs` contains ~100 documented intentional suppressions
- Mix aliases: `mix dialyzer.setup`, `mix dialyzer.check`, `mix dialyzer.clean`

## Deployment

**Production**: Fly.io at `https://raxol.io`

```bash
flyctl deploy              # Deploy
flyctl status --app raxol  # Status
flyctl logs --app raxol    # Logs
```

Configuration: `fly.toml`, Dockerfile: `docker/Dockerfile.web`

## Project Notes

- **Phoenix as library only** - No active web server in core, Ecto.Repo explicitly disabled
- Themes stored in `priv/themes/` as JSON
- Never add coauthored-by claude or emojis to commits
- Domain: raxol.io (made by axol.io)
- Plugin docs: `docs/plugins/GUIDE.md`

<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
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
