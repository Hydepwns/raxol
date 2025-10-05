# Raxol Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/raxol_plugin.svg)](https://hex.pm/packages/raxol_plugin)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/raxol_plugin)

Plugin framework for Raxol terminal applications. Build extensible terminal UIs with a simple behavior-based API.

## Installation

```elixir
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_plugin, "~> 2.0"}
  ]
end
```

## Quick Start

```elixir
defmodule MyPlugin do
  @behaviour Raxol.Plugin

  alias Raxol.Core.Buffer

  @impl true
  def init(_opts), do: {:ok, %{counter: 0}}

  @impl true
  def handle_input(key, _modifiers, state) do
    case key do
      " " -> {:ok, %{state | counter: state.counter + 1}}
      "r" -> {:ok, %{counter: 0}}
      "q" -> {:exit, state}
      _ -> {:ok, state}
    end
  end

  @impl true
  def render(buffer, state) do
    buffer
    |> Buffer.write_at(0, 0, "Counter: #{state.counter}")
    |> Buffer.write_at(0, 1, "Press SPACE to increment, R to reset, Q to quit")
  end

  @impl true
  def cleanup(_state), do: :ok
end

# Run it
Raxol.Plugin.run(MyPlugin, buffer_width: 80, buffer_height: 24)
```

## Plugin Behavior

Four required callbacks:

- `init(opts)` - Initialize plugin state
- `handle_input(key, modifiers, state)` - Process input events
- `render(buffer, state)` - Render current state to buffer
- `cleanup(state)` - Clean up resources

One optional callback:

- `handle_info(message, state)` - Handle async messages

## Input Handling

Special keys as atoms: `:enter`, `:escape`, `:tab`, `:backspace`, `:delete`, `:up`, `:down`, `:left`, `:right`, `:home`, `:end`, `:page_up`, `:page_down`, `:f1`-`:f12`

Modifiers: `%{ctrl: bool, alt: bool, shift: bool, meta: bool}`

## Examples

Full examples in the [main repository](https://github.com/Hydepwns/raxol/tree/master/examples/plugins):
- counter.exs - Simple counter plugin
- Spotify integration - OAuth + Web API
- Custom integrations

## Documentation

See [main repository](https://github.com/Hydepwns/raxol):
- [Spotify Plugin Guide](https://github.com/Hydepwns/raxol/blob/master/docs/plugins/SPOTIFY.md)
- [Building Plugins](https://github.com/Hydepwns/raxol/blob/master/examples/plugins/README.md)

## License

MIT License - See LICENSE file

## Contributing

Visit [main repository](https://github.com/Hydepwns/raxol)

## Credits

Built by [axol.io](https://axol.io) for [raxol.io](https://raxol.io)
