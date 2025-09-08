# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
```bash
# Run all tests (excluding slow/integration/docker tests)
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker

# Run specific test file
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/path/to/test_file.exs

# Run failed tests only
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --failed

# Run tests with max failures limit
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --max-failures 5
```

### Building & Compilation
```bash
# Compile with test environment and skip termbox2 tests
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix compile

# Compile with warnings as errors
mix compile --warnings-as-errors

# Format code
mix format

# Check formatting
mix format --check-formatted
```

### Code Quality
```bash
# Run Credo for style checks
mix credo

# Run Dialyzer for type checking  
mix dialyzer

# Generate documentation
mix docs
```

### Development Tools
```bash
# Run interactive tutorial
mix raxol.tutorial

# Run component playground
mix raxol.playground

# Development script utilities
./scripts/dev.sh test          # Run tests (optional pattern filter)
./scripts/dev.sh test-all      # Run all test suites
./scripts/dev.sh check         # Run all quality checks
./scripts/dev.sh format        # Format code
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
- Common test helpers in `test/support/` and `lib/raxol/test/`
- Use `Raxol.Terminal.DriverTestHelper` for terminal testing
- Property-based tests in `test/property/`

### Performance Considerations

- Parser operations optimized to 3.3μs/op
- Memory usage kept under 2.8MB per session  
- Extensive benchmarking suite in `bench/`
- Use `mix run bench/parser_profiling.exs` for performance testing

### NIF Integration

The project includes a NIF (Native Implemented Function) for termbox2:
- C source in `lib/termbox2_nif/c_src/`
- Built automatically via `elixir_make` 
- Makefile handles compilation during `mix deps.compile`

### Important Notes

- Always use absolute paths when working with files
- The project uses Phoenix but as a library - no Ecto.Repo auto-starting
- Themes are stored in `priv/themes/` as JSON files
- Configuration uses TOML format where applicable
- Full test coverage target is 100% (currently at 98.7%)
- never add coauthored by claude, emojis or other claude metadata to any commit messages