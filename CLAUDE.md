# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status
**Current Version**: v1.6.0 (Production Ready)
**Compilation Status**: Zero warnings achieved (fully clean with `--warnings-as-errors`)
**Test Coverage**: 100% for core modules (UnifiedStateManager: 30/30, ComponentManager: 16/16)
**Performance**: Parser 0.17-1.25μs | Render 265-283μs | Memory <2.8MB

## New in v1.6.0

### Production Ready Release
- Core functionality test failures completely resolved
- UnifiedStateManager module implemented with full ETS backing
- ComponentManager async error handling verified and stable
- Zero compilation warnings maintained across critical modules
- Enhanced BaseManager pattern adoption continues

### Code Quality Achievements
- All originally failing test modules now pass 100%
- Functional programming patterns maintained throughout
- Clean compilation with strict error checking
- Comprehensive state management and component lifecycle support

### Previous Features (v1.4.1)

### Automated Type Spec Generation
```bash
# Generate type specs for private functions
mix raxol.gen.specs lib/file.ex           # Single file
mix raxol.gen.specs lib/dir --recursive   # Directory
mix raxol.gen.specs lib --dry-run         # Preview only
mix raxol.gen.specs lib --interactive     # Confirm each spec
```

### Unified TOML Configuration
- Centralized config in `config/raxol.toml`
- Environment-specific overrides in `config/environments/`
- Runtime updates via `Raxol.Config` module
- See `docs/configuration/UNIFIED_CONFIG.md`

### Enhanced Debug Mode
- Four levels: `:off`, `:basic`, `:detailed`, `:verbose`
- Performance monitoring and profiling
- Detailed logging with metadata
- See `docs/development/DEBUG_MODE.md`

## Commands

### Consolidated Mix Tasks (v1.4.1+)
```bash
# Main Raxol command - show all available commands
mix raxol help

# Quality checking - run all quality checks
mix raxol.check             # Run all quality checks (format, credo, dialyzer)
mix raxol.check --quick     # Quick checks (skip dialyzer)

# Enhanced test runner
mix raxol.test              # Run tests with enhanced features
mix raxol.test --coverage   # With coverage report
mix raxol.test --parallel   # Parallel execution
mix raxol.test_parallel     # Optimized parallel test execution
mix raxol.test_flaky        # Detect and analyze flaky tests

# Type spec generation (NEW in v1.4.1)
mix raxol.gen.specs <path>  # Generate type specs for private functions
mix raxol.gen.specs lib --recursive --dry-run  # Preview for entire lib

# Performance and profiling
mix raxol.profile <module>  # Profile specific module
mix raxol.mutation          # Run mutation testing (refactored with functional patterns)
mix raxol.perf analyze      # Quick performance analysis
mix raxol.perf profile <module> # Profile specific module with options
mix raxol.perf monitor      # Start continuous monitoring
mix raxol.perf memory       # Memory usage analysis
mix raxol.perf report       # Generate performance report

# Documentation and analysis
mix raxol.docs              # Generate documentation
```

### Testing
```bash
# Standard test commands (always use TMPDIR=/tmp and SKIP_TERMBOX2_TESTS=true)
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker

# Run specific test file
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/path/to/test_file.exs

# Run failed tests only
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --failed

# Run tests with max failures limit
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --max-failures 5

# Run tests without warnings as errors (for debugging)
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --no-warnings-as-errors
```

### Building & Compilation
```bash
# IMPORTANT: Always set TMPDIR to avoid nix-shell issues (especially on macOS)
export TMPDIR=/tmp

# Compile with test environment and skip termbox2 tests
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile

# Compile with warnings as errors (default in v1.4.1+)
TMPDIR=/tmp SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile --warnings-as-errors

# Format code
mix format

# Check formatting
mix format --check-formatted
```

#### Troubleshooting Compilation Issues
If you encounter compilation errors with the NIF (Native Implemented Function):
1. Ensure gcc and make are installed: `gcc --version && make --version`
2. Always set TMPDIR environment variable: `export TMPDIR=/tmp`
3. The Makefile now automatically handles TMPDIR issues
4. Use `--no-warnings-as-errors` flag if debugging compilation issues

### Code Quality
```bash
# Run Credo for style checks
mix credo

# Run Dialyzer for type checking  
mix dialyzer

# Generate documentation
mix docs

# Run all quality checks at once (v1.4.1+)
mix raxol.check
```

### Development Tools
```bash
# Run interactive tutorial
mix raxol.tutorial

# Component playground
mix raxol.playground

# Start LSP server for IDE integration
mix raxol.lsp --stdio          # For stdio communication
mix raxol.lsp --port 9999      # For TCP communication
mix raxol.lsp --verbose        # With debug output

# Component generation
mix raxol.gen.component MyComponent

# Legacy development script utilities (still available)
./scripts/dev.sh test          # Run tests (optional pattern filter)
./scripts/dev.sh test-all      # Run all test suites
./scripts/dev.sh check         # Run all quality checks
./scripts/dev.sh format        # Format code
./scripts/dev.sh bench         # Benchmark with comparison
./scripts/dev.sh profile       # Profile specific module
```

## Architecture Overview

Raxol is a high-performance terminal application framework that supports multiple UI paradigms (React, Svelte, LiveView, HEEx). The codebase is organized into several key layers:

### Core Structure
```
lib/raxol/
├── terminal/          # Terminal emulation core (VT100/ANSI compliance)
│   ├── ansi/         # ANSI sequence parsing and handling
│   ├── buffer/       # Screen buffer management
│   ├── cursor/       # Cursor state and movement
│   ├── emulator/     # Terminal emulator implementation
│   └── window/       # Window management
├── ui/               # Multi-framework UI layer
│   ├── components/   # Pre-built UI components
│   ├── events/       # Event handling system
│   └── theming/      # Theme management
├── core/             # Core services and utilities
│   ├── runtime/      # Plugin system and lifecycle
│   ├── accessibility/# Accessibility features
│   └── error_handler.ex # Centralized error handling
└── test/             # Test utilities and helpers
```

### Key Modules

**Terminal Emulation Layer** (`lib/raxol/terminal/`)
- `Raxol.Terminal.Emulator` - Main terminal emulator with full VT100/ANSI support
- `Raxol.Terminal.Buffer` - Efficient screen buffer management
- `Raxol.Terminal.ANSI.Parser` - High-performance ANSI sequence parser (3.3μs/op)
- `Raxol.Terminal.Window.Manager` - Window and pane management

**UI Framework Layer** (`lib/raxol/ui/`)
- Supports multiple UI paradigms via `use Raxol.UI, framework: :react/:svelte/:liveview/:heex/:raw`
- Universal features work across all frameworks (actions, transitions, context, slots)
- Component lifecycle hooks and state management

**Error Handling** (`lib/raxol/core/error_handler.ex`)
- Centralized error classification and handling
- Graceful degradation for terminal operations
- Comprehensive error recovery strategies

### Testing Patterns

Tests use several key helpers and patterns:
- Always set `SKIP_TERMBOX2_TESTS=true` environment variable
- Test files mirror the lib structure in `test/`
- Common test helpers in `test/support/`
- Use `Raxol.Terminal.DriverTestHelper` for terminal testing
- Property-based tests in `test/property/`

### Performance Considerations

- Parser operations optimized to 3.3μs/op
- Memory usage kept under 2.8MB per session  
- Extensive benchmarking suite in `bench/`
- Render operations under 1ms for 60fps capability
- Automated performance regression detection in CI (5% tolerance)

#### Benchmarking Commands
```bash
# Run specific benchmarks
mix run bench/buffer_benchmark.exs
mix run bench/cursor_benchmark.exs
mix run bench/render_performance_simple.exs
mix run bench/render_pipeline_profiling.exs
mix run bench/validate_optimizations.exs

# Profile specific modules
mix raxol.profile <module_name>

# Use legacy scripts for benchmarking
./scripts/dev.sh bench
```

### NIF Integration

The project includes a NIF (Native Implemented Function) for termbox2:
- C source in `lib/termbox2_nif/c_src/`
- Built automatically via `elixir_make` 
- Makefile handles compilation during `mix deps.compile`

### Naming Conventions

Follow established patterns documented in `docs/development/NAMING_CONVENTIONS.md`:
- Module files use `<domain>_<function>.ex` format (e.g., `cursor_manager.ex`, `buffer_server.ex`)
- Avoid generic names like `manager.ex`, `handler.ex`, `server.ex`
- All 154+ duplicate filenames resolved in Sprint 22-23
- Consistent naming prevents compilation conflicts and improves navigation

### Mutation Testing

The project includes a custom mutation testing implementation via `mix raxol.mutation`. This task has been refactored to follow functional programming patterns:

```bash
# Run basic mutation testing
mix raxol.mutation

# Test specific module with more mutations
mix raxol.mutation --target lib/raxol/core/state_manager.ex --mutations 20

# Quick check with limited operators
mix raxol.mutation --operators arithmetic --mutations 5
```

The implementation:
- Uses pattern matching instead of if/else statements
- Follows functional programming patterns (no imperative loops)
- Removes all emoji characters from output
- Properly handles all edge cases with pattern matching

Note: The Muzak library (`{:muzak, "~> 1.1"}`) is installed as a dependency but not currently used due to integration issues.

### Coding Style Guidelines

- **Pattern Matching**: Use pattern matching and guards instead of imperative if/else statements
- **Functional Patterns**: Prefer functional constructs (map, reduce, filter) over imperative loops
- **No Emojis**: Do not use emoji characters in code or output
- **Error Handling**: Use {:ok, result} and {:error, reason} tuples with pattern matching

## Deployment and Hosting

### Production Infrastructure

Raxol uses a multi-tier deployment strategy. See `docs/architecture/DEPLOYMENT.md` for complete details.

**Primary Hosting: Fly.io** (Production)
- URL: `https://raxol.fly.dev`
- Full Phoenix LiveView application with backend
- 2 machines running, auto-scaling enabled
- Deployment: `flyctl deploy` (uses `docker/Dockerfile.web`)
- Configuration: `fly.toml`
- Status: Active and production-ready

**Secondary: Cloudflare Pages** (Optional CDN)
- Static assets only (`web/priv/static`)
- Automated via `.github/workflows/deploy-web.yml`
- Purpose: CDN for static content, not for main playground
- Limitation: No backend/Phoenix runtime, no WebSockets

**Tertiary: GitHub Pages** (Metrics Dashboard)
- Performance benchmarks and metrics only
- Via `.github/workflows/performance-tracking.yml`
- Not for application hosting

### Key Distinction

**Fly.io is the primary hosting provider** because:
1. Supports full Phoenix LiveView functionality
2. Has WebSocket support for real-time features
3. Runs complete Elixir/OTP backend
4. Currently deployed and operational
5. Your purchased domain `raxol.io` should point here

Cloudflare Pages only serves static files and cannot run the Phoenix backend needed for the interactive playground.

### Deployment Commands

```bash
# Deploy to Fly.io
flyctl deploy

# Check status
flyctl status --app raxol

# View logs
flyctl logs --app raxol

# SSH into machine
flyctl ssh console
```

### Important Notes

- Always use absolute paths when working with files
- The project uses Phoenix but as a library - no Ecto.Repo auto-starting
- Themes are stored in `priv/themes/` as JSON files
- Configuration uses TOML format where applicable
- Full test coverage target is 100% (currently at 98.7%)
- Never add coauthored by claude, emojis or other claude metadata to any commit messages
- We have purchased raxol.io for this project, raxol is made by axol.io
- only write code idiomatic to elixir. avoid emojis, use ascii instead