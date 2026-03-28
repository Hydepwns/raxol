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
mix dialyzer                  # Type checking (PLT cached in priv/plts/)
mix docs                      # Generate docs
mix raxol.check               # Run all checks (format, compile, credo, dialyzer, test)
mix raxol.check --quick       # Skip dialyzer
```

### Development
```bash
mix raxol.playground   # Component playground (28 widget demos)
mix raxol.repl         # Interactive REPL with sandboxing
iex -S mix            # Interactive shell
```

## Dialyzer

PLT cached in `priv/plts/` for faster reruns.

### Commands
```bash
mix dialyzer                  # Run analysis (builds PLT if needed)
mix dialyzer --format short   # Compact output
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
```bash
mix raxol.perf                # Performance monitoring
mix raxol.flamegraph          # Generate flame graph
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
```bash
mix raxol.perf                # Performance monitoring
mix raxol.perf.monitor        # Live performance monitor
mix raxol.flamegraph          # Generate flame graph
```

### Benchmarking
```bash
mix raxol.bench               # Run benchmark suite
mix run bench/core/buffer_benchmark.exs  # Specific benchmark
```

### Optimization Tips
- Damage tracking is automatic
- Enable component caching
- Batch state updates
- Profile before optimizing

## Contributing

### Pre-commit Checks
```bash
mix raxol.check               # Run all quality checks before committing
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
```

### Release
```bash
MIX_ENV=prod mix release
```

## Quick Reference

### TEA App

```elixir
defmodule MyApp do
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context), do: %{count: 0}

  @impl true
  def update(message, model) do
    case message do
      :increment -> {%{model | count: model.count + 1}, []}
      %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}} ->
        {model, [command(:quit)]}
      _ -> {model, []}
    end
  end

  @impl true
  def view(model) do
    column style: %{padding: 1} do
      [text("Count: #{model.count}"), button("+", on_click: :increment)]
    end
  end

  @impl true
  def subscribe(_model), do: []
end

{:ok, pid} = Raxol.start_link(MyApp, [])
```

### Keyboard Event Shapes

```elixir
# Printable character
%Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "q"}}

# Modifier key
%Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: "c", ctrl: true}}

# Special key
%Raxol.Core.Events.Event{type: :key, data: %{key: :enter}}
%Raxol.Core.Events.Event{type: :key, data: %{key: :escape}}
%Raxol.Core.Events.Event{type: :key, data: %{key: :tab}}
```

### ANSI Codes
```
\e[H         Home
\e[2J        Clear screen
\e[31m       Red text
\e[1m        Bold
\e[?25l      Hide cursor
```

## Resources

- [Architecture Decision Records](adr/)
- HexDocs API Reference: https://hexdocs.pm/raxol
