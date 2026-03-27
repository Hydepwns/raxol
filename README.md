# Raxol

[![CI](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml)

OTP-native terminal framework for Elixir. Same app runs in a terminal, a browser via LiveView, or over SSH.

Your app is a GenServer. Components crash and restart without taking down the UI. Hot-reload your view function while it's running. Coordinate AI agent teams with OTP supervisors. Cluster nodes with CRDTs and automatic discovery. No other TUI framework does any of that -- Raxol gets it from the runtime.

## Why OTP Changes Everything

Every feature below comes from the BEAM, not a library bolted on top:

| Capability                     | Raxol | Ratatui | Bubble Tea | Textual | Ink |
| ------------------------------ | :---: | :-----: | :--------: | :-----: | :-: |
| Crash isolation per component  |  yes  |   --    |     --     |   --    | --  |
| Hot code reload (no restart)   |  yes  |   --    |     --     |   --    | --  |
| Same app in terminal + browser |  yes  |   --    |     --     | partial | --  |
| Built-in SSH serving           |  yes  |   --    |  via lib   |   --    | --  |
| AI agent runtime               |  yes  |   --    |     --     |   --    | --  |
| Distributed clustering (CRDTs) |  yes  |   --    |     --     |   --    | --  |
| Time-travel debugging          |  yes  |   --    |     --     |   --    | --  |
| Session recording (asciinema)  |  yes  |   --    |     --     |   yes   | --  |
| Self-adapting layout           |  yes  |   --    |     --     |   --    | --  |
| Flexbox & CSS Grid layout      |  yes  |   --    |     --     |   yes   | yes |
| Inline images (Kitty/Sixel)    |  yes  |   yes   |     --     |   --    | --  |

The mapping is natural: GenServer = Elm update loop, process = component with crash isolation, supervisor = restart strategy, `:ssh` = SSH serving without deps, `libcluster` = node discovery.

## Hello World

Every Raxol app follows [The Elm Architecture](https://guide.elm-lang.org/architecture/) -- `init`, `update`, `view`:

```elixir
defmodule Counter do
  use Raxol.Core.Runtime.Application

  def init(_ctx), do: %{count: 0}

  def update(:inc, model), do: {%{model | count: model.count + 1}, []}
  def update(:dec, model), do: {%{model | count: model.count - 1}, []}
  def update(_, model), do: {model, []}

  def view(model) do
    column style: %{padding: 1, gap: 1} do
      [
        text("Count: #{model.count}", style: [:bold]),
        row style: %{gap: 1} do
          [button("+", on_click: :inc), button("-", on_click: :dec)]
        end
      ]
    end
  end

  def subscribe(_model), do: []
end
```

```bash
mix run examples/getting_started/counter.exs
```

That counter works in a terminal. The same module renders in Phoenix LiveView. The same module serves over SSH. One codebase, three targets.

## What Makes It Different

**Crash isolation** -- Wrap any widget in `process_component/2` and it runs in its own process. It crashes, it restarts. The rest of your UI doesn't blink.

**Hot code reload** -- Change your `view/1` function, save, and the running app updates. No restart, no reconnect.

**AI agents as TEA apps** -- An agent is a TEA app where input comes from LLMs instead of a keyboard. `use Raxol.Agent`, implement `init/update/view`, and you get supervised, crash-isolated agents with inter-agent messaging. Real SSE streaming to Anthropic, OpenAI, Ollama, Groq. Free tier via LLM7.io.

```elixir
defmodule MyAgent do
  use Raxol.Agent

  def init(_ctx), do: %{findings: []}

  def update({:agent_message, _from, {:analyze, file}}, model) do
    {model, [shell("wc -l #{file}")]}
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    {%{model | findings: [out | model.findings]}, []}
  end
end

{:ok, _} = Raxol.Agent.Session.start_link(app_module: MyAgent, id: :my_agent)
Raxol.Agent.Session.send_message(:my_agent, {:analyze, "lib/raxol.ex"})
```

**SSH serving** -- `Raxol.SSH.serve(MyApp, port: 2222)` and anyone can SSH into your app. Each connection gets its own supervised process.

**LiveView bridge** -- The same TEA app renders to a Phoenix LiveView. Terminal and browser, same codebase, same state model. See `examples/liveview/tea_counter_live.ex`.

**Distributed swarm** -- CRDTs (LWW registers, OR-sets), node monitoring, seniority-based election, tactical overlay sync. Automatic discovery via libcluster (gossip, epmd, DNS, Tailscale).

**Sensor fusion** -- Poll sensors, fuse readings with weighted averaging and thresholds, render gauges and sparklines.

**Self-adapting layout** -- Track how the UI is used, recommend layout changes, animate transitions. The interface evolves.

**Time-travel debugging** -- Snapshot every `update/2` cycle. Step back, forward, jump to any point, restore state. Zero cost when disabled.

**Session recording** -- Capture sessions as asciinema v2 `.cast` files. Replay with pause, seek, speed control. Auto-save on crash.

**Sandboxed REPL** -- `mix raxol.repl` with three safety levels. AST-based scanner blocks dangerous operations. Safe for SSH in strict mode.

## What You Get

**Rich widget set** -- Button, TextInput, Table, Tree, Modal, SelectList, Checkbox, Sparkline, Charts, and more. All keyboard-navigable with focus management.

**Layout engine** -- Flexbox (`row`/`column` with `flex`, `gap`, `align_items`) and CSS Grid (`template_columns`, `template_rows`). Nested freely.

**60fps rendering** -- Virtual DOM diffing, damage tracking, synchronized terminal output. Full frame in ~2ms -- that's 13% of the 60fps budget, leaving 87% for your code.

**Theming** -- Named colors, RGB, 256-color, hex strings. Auto-downsample to whatever the terminal supports.

**Terminal compatibility** -- Works in Ghostty, Kitty, WezTerm, iTerm2, Alacritty, Terminal.app, Windows Terminal, and anything with basic ANSI support. Auto-detects Kitty graphics protocol for inline images (Ghostty, Kitty, WezTerm). Falls back to Sixel or iTerm2 protocol where available.

**Interactive playground** -- `mix raxol.playground` opens live demos across all categories. Browse, search, filter by complexity. Works over SSH too.

## Install

```elixir
# mix.exs
def deps do
  [{:raxol, "~> 2.3"}]
end
```

Or generate a new project:

```bash
mix raxol.new my_app
```

## Try the Demo

The flagship demo is a live BEAM dashboard -- scheduler utilization, memory sparklines, process table, all updating in real time:

```bash
git clone --recursive https://github.com/Hydepwns/raxol.git
cd raxol && mix deps.get
mix run examples/demo.exs
```

More examples:

```bash
mix run examples/getting_started/counter.exs    # Minimal counter
mix run examples/apps/file_browser.exs           # File browser with tree nav
mix run examples/apps/todo_app.ex                # Todo list
mix run examples/agents/code_review_agent.exs    # AI agent analyzing files
mix run examples/agents/agent_team.exs           # Coordinator + worker agents
mix run examples/agents/ai_cockpit.exs           # Multi-agent AI cockpit (mock)
FREE_AI=true mix run examples/agents/ai_cockpit.exs  # Real AI via LLM7.io (free)
mix run examples/swarm/cluster_demo.exs          # CRDT state sync demo
mix raxol.repl                                    # Sandboxed REPL (--sandbox strict)
mix phx.server                                    # LiveView counter at /counter
```

## Performance

Full frame in 2.1ms on Apple M1 Pro (Elixir 1.19 / OTP 26). That's 13% of the 60fps budget -- components crash and restart in microseconds without affecting the UI.

| What                              | Time    |
| --------------------------------- | ------- |
| Full frame (create + fill + diff) | 2.1 ms  |
| Tree diff (100 nodes)             | 4 us    |
| Cell write                        | 0.97 us |
| ANSI parse                        | 38 us   |

Raxol is slower per-operation than Rust or Go (expected for a managed runtime). The tradeoff: crash isolation, hot reload, distribution, and SSH serving that those frameworks don't have. See the [benchmark suite](docs/bench/README.md) for details.

## Documentation

**Start here** -- [Quickstart](docs/getting-started/QUICKSTART.md) / [Core Concepts](docs/getting-started/CORE_CONCEPTS.md) / [Widget Gallery](docs/getting-started/WIDGET_GALLERY.md)

**Cookbook** -- [Building Apps](docs/cookbook/BUILDING_APPS.md) / [SSH Deployment](docs/cookbook/SSH_DEPLOYMENT.md) / [Theming](docs/cookbook/THEMING.md) / [LiveView](docs/cookbook/LIVEVIEW_INTEGRATION.md) / [Performance](docs/cookbook/PERFORMANCE_OPTIMIZATION.md)

**Reference** -- [Architecture](docs/core/ARCHITECTURE.md) / [Buffer API](docs/core/BUFFER_API.md) / [Benchmarks](docs/bench/README.md) / [API Docs](https://hexdocs.pm/raxol)

**Advanced** -- [Agent Framework](docs/features/AGENT_FRAMEWORK.md) / [Sensor Fusion](docs/features/SENSOR_FUSION.md) / [Distributed Swarm](docs/features/DISTRIBUTED_SWARM.md) / [Recording & Replay](docs/features/RECORDING_REPLAY.md) / [Why OTP for TUIs](docs/WHY_OTP.md)

## Development

```bash
git clone --recursive https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
```

The termbox2 NIF requires a git submodule. If you cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

## License

MIT -- see [LICENSE.md](LICENSE.md)
