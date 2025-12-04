# Development

Everything you need to develop with Raxol.

## Setup

### Quick Start (Nix)
```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
nix-shell
mix deps.get
mix setup
```

### Manual Setup
```bash
# Requirements: Elixir 1.19.0+, Erlang/OTP 28.2+, Node.js 20+, PostgreSQL 15+
mix deps.get
git submodule update --init --recursive
mix compile
```

## Commands

### Testing
```bash
# Run all tests
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

# Run specific test
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/file.exs

# Run failed tests
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test --failed

# With coverage
mix test --cover
```

### Code Quality
```bash
mix format                    # Format code
mix credo                     # Style check
mix raxol.dialyzer           # Enhanced type check with PLT caching
mix raxol.dialyzer --setup   # Build PLT files from scratch
mix raxol.dialyzer --check   # Quick type check
mix docs                     # Generate docs
mix raxol.pre_commit         # Run all checks
```

### Development
```bash
mix raxol.tutorial     # Interactive tutorial
mix raxol.playground   # Component playground
iex -S mix            # Interactive shell
```

## Static Analysis with Dialyzer

Raxol uses an enhanced Dialyzer setup with intelligent PLT caching for fast, comprehensive type checking.

### Quick Commands
```bash
# Run analysis (builds PLT if needed)
mix raxol.dialyzer

# Quick check (uses existing PLT)
mix raxol.dialyzer --check

# Build PLT from scratch
mix raxol.dialyzer --setup

# Clean PLT cache
mix raxol.dialyzer --clean

# Show statistics
mix raxol.dialyzer --stats

# Performance profiling
mix raxol.dialyzer --profile
```

### Development Workflow Integration
```bash
# Use via dev.sh script
./scripts/dev.sh dialyzer

# Part of quality checks
./scripts/dev.sh check
```

### PLT Caching Strategy

Dialyzer uses a two-tier PLT caching system for optimal performance:

- **Core PLT** (`priv/plts/core.plt`): Erlang/OTP + stable dependencies
- **Local PLT** (`priv/plts/local.plt`): Project modules + volatile dependencies

This minimizes rebuild times while ensuring analysis accuracy.

### Handling False Positives

Known false positives are filtered via `.dialyzer_ignore.exs`:

```elixir
# Terminal/NIF related warnings
~r/termbox2_nif.*has no local return/,
~r/Phoenix.*callback.*never called/,
~r/GenServer.*init.*no local return/
```

### CI Integration

Dialyzer runs automatically in CI with PLT caching enabled, providing fast feedback on type safety.

## Configuration

### Environment Variables
```elixir
# config/dev.exs
config :raxol,
  terminal: [
    width: 120,
    height: 40,
    scrollback: 10_000
  ],
  performance: [
    cache: true,
    profiling: true
  ]
```

### Test Environment
```elixir
# config/test.exs
config :raxol,
  terminal: [headless: true, mock_pty: true],
  performance: [assertions: true]
```

## Troubleshooting

### Common Issues

**NIF Compilation Fails**
```bash
export TMPDIR=/tmp
SKIP_TERMBOX2_TESTS=true mix compile
```

**Module Not Found**
```bash
mix deps.clean --all
mix deps.get
mix compile --force
```

**Test Failures**
```bash
# Clear test cache
rm -rf _build/test
MIX_ENV=test mix compile
```

**Performance Issues**
```elixir
# Enable profiling
Raxol.Profiler.enable()
# Run operation
Raxol.Profiler.report()
```

## Architecture

### Module Organization
```
lib/raxol/
├── terminal/       # Terminal emulation
├── ui/            # UI components
├── core/          # Core services
└── test/          # Test helpers
```

### Naming Conventions
- Files: `<domain>_<function>.ex` (e.g., `cursor_manager.ex`)
- Modules: Singular names (e.g., `EventManager` not `EventsManager`)
- No generic names like `manager.ex` or `handler.ex`

### Error Handling
```elixir
# Use functional patterns
case safe_call(fn -> operation() end) do
  {:ok, result} -> result
  {:error, _} -> default
end

# With pipelines
with {:ok, data} <- fetch(),
     {:ok, result} <- process(data) do
  {:ok, result}
end
```

## Performance

### Profiling
```elixir
{result, stats} = Raxol.Profiler.profile do
  expensive_operation()
end
IO.inspect(stats)
```

### Benchmarking
```bash
mix run bench/parser_profiling.exs
```

### Optimization Tips
- Use damage tracking (automatic)
- Enable component caching
- Batch state updates
- Profile before optimizing

## Contributing

### Pre-commit Hooks
```bash
# Install hooks
cp .git-hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# Or use Mix task
mix raxol.install_hooks
```

### Code Standards
- 98.7%+ test coverage
- Zero compilation warnings
- All checks must pass
- Follow functional patterns

## Build & Release

### Precompilation
```bash
# Optimize for production
MIX_ENV=prod mix compile
mix raxol.precompile
```

### Release
```bash
MIX_ENV=prod mix release
```

## Resources

- [Architecture Decision Records](adr/)
- [API Reference](api-reference.md)
- [Error Handling Guide](error-handling.md)
- [Functional Programming](functional-programming.md)