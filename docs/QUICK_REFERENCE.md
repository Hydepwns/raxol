# Quick Reference

## Essential Commands

```bash
# Testing
SKIP_TERMBOX2_TESTS=true MIX_ENV=test mix test
mix test --failed
mix test --cover

# Development
mix raxol.tutorial      # Interactive tutorial
mix raxol.playground    # Component playground
iex -S mix             # Interactive shell

# Quality
mix format             # Format code
mix credo             # Style check
mix raxol.pre_commit  # All checks
```

## Common Patterns

### Terminal
```elixir
{:ok, t} = Raxol.Terminal.start(width: 80, height: 24)
Raxol.Terminal.write(t, "Hello \e[32mWorld\e[0m")
Raxol.Terminal.execute(t, "ls -la")
```

### Components
```elixir
defmodule MyComponent do
  use Raxol.Component
  def init(props), do: %{text: props[:text]}
  def render(state, _), do: text(state.text)
end
```

### Error Handling
```elixir
case safe_call(fn -> risky() end) do
  {:ok, result} -> result
  {:error, _} -> default
end
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| NIF compile fails | `export TMPDIR=/tmp` |
| Module not found | `mix deps.clean --all && mix deps.get` |
| Tests fail | `rm -rf _build/test && mix test` |
| Slow performance | `Raxol.Profiler.enable()` |

## Configuration

```elixir
# config/dev.exs
config :raxol,
  terminal: [width: 120, height: 40],
  performance: [cache: true],
  accessibility: [screen_reader: true]
```

## ANSI Codes

```
\e[H         Home
\e[2J        Clear screen
\e[31m       Red text
\e[1m        Bold
\e[?25l      Hide cursor
\e[{n}A      Up n lines
```

## Keyboard Shortcuts

```elixir
{:key, :enter}
{:key, :escape}
{:key, "j", [:ctrl]}
{:key, :arrow_up}
{:mouse, :click, row, col}
```

## Links

- [Getting Started](getting-started.md)
- [API Reference](api-reference.md)
- [Full Docs](README.md)