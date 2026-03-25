# Development Guide

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
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test

# Specific test
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test test/file.exs

# Rerun failed tests
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

## Dialyzer

Raxol has an enhanced Dialyzer setup with PLT caching for faster type checking.

### Commands
```bash
mix raxol.dialyzer           # Run analysis (builds PLT if needed)
mix raxol.dialyzer --check   # Quick check (uses existing PLT)
mix raxol.dialyzer --setup   # Build PLT from scratch
mix raxol.dialyzer --clean   # Clean PLT cache
mix raxol.dialyzer --stats   # Show statistics
mix raxol.dialyzer --profile # Performance profiling
```

You can also use the dev script:
```bash
./scripts/dev.sh dialyzer
./scripts/dev.sh check      # Runs dialyzer as part of quality checks
```

### PLT Caching

Two-tier system:

- **Core PLT** (`priv/plts/core.plt`): Erlang/OTP + stable dependencies
- **Local PLT** (`priv/plts/local.plt`): Project modules + volatile dependencies

This keeps rebuild times short while staying accurate.

### False Positives

Known false positives are filtered in `.dialyzer_ignore.exs`:

```elixir
~r/termbox2_nif.*has no local return/,
~r/Phoenix.*callback.*never called/,
~r/GenServer.*init.*no local return/
```

Dialyzer runs in CI with PLT caching enabled.

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
rm -rf _build/test
MIX_ENV=test mix compile
```

**Performance Issues**
```elixir
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
- Modules: Singular names (`EventManager` not `EventsManager`)
- Avoid generic names like `manager.ex` or `handler.ex`

### Error Handling
```elixir
case safe_call(fn -> operation() end) do
  {:ok, result} -> result
  {:error, _} -> default
end

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
- Damage tracking is automatic
- Enable component caching
- Batch state updates
- Profile before optimizing

## Contributing

### Pre-commit Hooks
```bash
cp .git-hooks/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit

# Or
mix raxol.install_hooks
```

### Code Standards
- 98.7%+ test coverage
- Zero compilation warnings
- All checks must pass
- Functional patterns

## Build & Release

### Precompilation
```bash
MIX_ENV=prod mix compile
mix raxol.precompile
```

### Release
```bash
MIX_ENV=prod mix release
```

## Quick Reference

### Common Patterns

**Terminal**
```elixir
{:ok, t} = Raxol.Terminal.start(width: 80, height: 24)
Raxol.Terminal.write(t, "Hello \e[32mWorld\e[0m")
```

**Components**
```elixir
defmodule MyComponent do
  use Raxol.Component
  def init(props), do: %{text: props[:text]}
  def render(state, _), do: text(state.text)
end
```

**Error Handling**
```elixir
case safe_call(fn -> risky() end) do
  {:ok, result} -> result
  {:error, _} -> default
end
```

### ANSI Codes
```
\e[H         Home
\e[2J        Clear screen
\e[31m       Red text
\e[1m        Bold
\e[?25l      Hide cursor
```

### Keyboard Events
```elixir
{:key, :enter}
{:key, :escape}
{:key, "j", [:ctrl]}
{:mouse, :click, row, col}
```

## Resources

- [Architecture Decision Records](adr/)
- HexDocs API Reference: https://hexdocs.pm/raxol
