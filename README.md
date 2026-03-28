# Raxol

[![CI](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml)

[OTP](https://en.wikipedia.org/wiki/Open_Telecom_Platform)-native terminal framework for Elixir.
Same app runs in a terminal, a browser via LiveView, or over SSH.

Your app is a [GenServer](https://hexdocs.pm/elixir/GenServer.html).
Components can crash and restart without taking down the UI.
Hot-reload your view function while it's running.

Coordinate AI agent teams with OTP supervisors.
Cluster nodes with CRDTs and automatic discovery.
No other TUI framework does any of that -- Raxol inherits it _from the runtime_.

## Origin Vision

> Raxol started as two converging ideas: a terminal for AGI, where AI agents
> interact with a real terminal emulator the same way humans do;
> and an interface for the cockpit of a Gundam Wing Suit, where fault isolation,
> real-time, responsiveness, and sensor fusion are survival-critical.

## Architecture

Your app is a GenServer running [The Elm Architecture](https://guide.elm-lang.org/architecture/). The terminal backend is a real VT100 emulator -- not raw escape codes -- so AI agents can interact with structured screen buffers the same way they'd interact with a browser DOM. Each component can run in its own OTP process. Crash one, the rest keep going, the supervisor restarts it.

The same TEA app renders to three targets: terminal (termbox2 NIF on Unix, pure Elixir on Windows), Phoenix LiveView in a browser, and SSH. You write it once.

## Why OTP

Every capability below comes from the [BEAM VM](<https://en.wikipedia.org/wiki/BEAM_(Erlang_virtual_machine)>), not a library:

| Capability                     | Raxol | Ratatui | Bubble Tea | Textual | Ink |
| ------------------------------ | :---: | :-----: | :--------: | :-----: | :-: |
| Crash isolation per component  |  yes  |   --    |     --     |   --    | --  |
| Hot code reload (no restart)   |  yes  |   --    |     --     |   --    | --  |
| Same app in terminal + browser |  yes  |   --    |     --     | partial | --  |
| Built-in SSH serving           |  yes  |   --    |  via lib   |   --    | --  |
| AI agent runtime               |  yes  |   --    |     --     |   --    | --  |
| Distributed clustering (CRDTs) |  yes  |   --    |     --     |   --    | --  |
| Time-travel debugging          |  yes  |   --    |     --     |   --    | --  |

The other frameworks are good at what they do -- Ratatui and Bubble Tea have excellent rendering and large ecosystems. The difference is that Raxol gets crash isolation, hot reload, distribution, and SSH for free from OTP. Those aren't features we built; they're properties of the runtime.

GenServer = Elm update loop. Process = component with crash isolation. Supervisor = restart strategy. `:ssh` = SSH serving without deps. `libcluster` = node discovery.

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

## Features

The big stuff first.

**Crash isolation** -- wrap any widget in `process_component/2` and it runs in its own process. It crashes, it restarts. The rest of your UI doesn't blink.

**Hot code reload** -- change your `view/1` function, save, and the running app updates. No restart, no reconnect.

**AI agents as TEA apps** -- an agent is just a TEA app where input comes from LLMs instead of a keyboard. `use Raxol.Agent`, implement `init/update/view`, and you get supervised, crash-isolated agents with inter-agent messaging. Real SSE streaming to Anthropic, OpenAI, Ollama, Groq. Free tier via LLM7.io.

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

Beyond those, here's what else is in the box.

**LiveView bridge.** The same TEA app renders to a Phoenix LiveView -- terminal and browser, same codebase, same state model. See `examples/liveview/tea_counter_live.ex`.

**Distributed swarm.** CRDTs (LWW registers, OR-sets), node monitoring, seniority-based election, tactical overlay sync. Discovery via libcluster: gossip, epmd, DNS, or Tailscale.

**Widgets and layout.** Button, TextInput, Table, Tree, Modal, SelectList, Checkbox, Sparkline, Charts, and more. All keyboard-navigable with focus management. Layout uses flexbox (`row`/`column` with `flex`, `gap`, `align_items`) and CSS Grid (`template_columns`, `template_rows`), nested freely.

Rendering is virtual DOM diffing with damage tracking -- full frame in ~2ms, which is 13% of the 60fps budget.

Sensor fusion polls sensors, fuses readings with weighted averaging and thresholds, renders gauges and sparklines. Self-adapting layout tracks usage patterns and recommends layout changes (optional Nx/Axon ML backend). Time-travel debugging snapshots every `update/2` cycle -- step back, forward, jump, restore, zero cost when disabled. Session recording captures to asciinema v2 `.cast` files with pause, seek, speed control, and auto-save on crash.

Theming supports named colors, RGB, 256-color, and hex strings, auto-downsampled to whatever the terminal supports. Works in Ghostty, Kitty, WezTerm, iTerm2, Alacritty, Terminal.app, Windows Terminal, and anything with basic ANSI. Inline images via Kitty graphics protocol (Ghostty, Kitty, WezTerm), with Sixel and iTerm2 protocol fallbacks.

`mix raxol.repl` gives you a sandboxed REPL with three safety levels -- AST-based scanner blocks dangerous operations, safe for SSH in strict mode. The interactive playground has 28 live demos across 8 categories; see [Try It](#try-it).

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

## Try It

```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol && mix deps.get
mix raxol.playground          # 28 live demos, browse/search/filter
mix raxol.playground --ssh    # same thing, served over SSH (port 2222)
```

The flagship demo is a live BEAM dashboard -- scheduler utilization, memory sparklines, process table, all updating in real time:

```bash
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

Full frame in 2.1ms on Apple M1 Pro (Elixir 1.19 / OTP 27). That's 13% of the 60fps budget -- components crash and restart in microseconds without affecting the UI.

| What                              | Time    |
| --------------------------------- | ------- |
| Full frame (create + fill + diff) | 2.1 ms  |
| Tree diff (100 nodes)             | 4 us    |
| Cell write                        | 0.97 us |
| ANSI parse                        | 38 us   |

Raxol is slower per-operation than Rust or Go (expected for a managed runtime). The tradeoff: crash isolation, hot reload, distribution, and SSH serving that those frameworks don't have. Windows uses a pure Elixir terminal driver (~10x slower than the Unix/macOS termbox2 NIF) -- functional but not performance-optimized. See the [benchmark suite](docs/bench/README.md) for details.

## Documentation

**Start here** -- [Quickstart](docs/getting-started/QUICKSTART.md) / [Core Concepts](docs/getting-started/CORE_CONCEPTS.md) / [Widget Gallery](docs/getting-started/WIDGET_GALLERY.md)

**Cookbook** -- [Building Apps](docs/cookbook/BUILDING_APPS.md) / [SSH Deployment](docs/cookbook/SSH_DEPLOYMENT.md) / [Theming](docs/cookbook/THEMING.md) / [LiveView](docs/cookbook/LIVEVIEW_INTEGRATION.md) / [Performance](docs/cookbook/PERFORMANCE_OPTIMIZATION.md)

**Reference** -- [Architecture](docs/core/ARCHITECTURE.md) / [Buffer API](docs/core/BUFFER_API.md) / [Benchmarks](docs/bench/README.md) / [API Docs](https://hexdocs.pm/raxol)

**Advanced** -- [Agent Framework](docs/features/AGENT_FRAMEWORK.md) / [Sensor Fusion](docs/features/SENSOR_FUSION.md) / [Distributed Swarm](docs/features/DISTRIBUTED_SWARM.md) / [Recording & Replay](docs/features/RECORDING_REPLAY.md) / [Why OTP for TUIs](docs/WHY_OTP.md)

**Standalone packages** -- [`raxol_core`](packages/raxol_core/) (behaviours, events, config, plugins), [`raxol_terminal`](packages/raxol_terminal/) (terminal emulation, termbox2 NIF), [`raxol_agent`](packages/raxol_agent/) (AI agent framework), [`raxol_sensor`](packages/raxol_sensor/) (sensor fusion). Use these if you want just one subsystem without the full framework.

## Development

```bash
git clone https://github.com/Hydepwns/raxol.git
cd raxol
mix deps.get
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
mix raxol.check              # format, compile, credo, dialyzer, security, test
mix raxol.check --quick      # skip dialyzer
mix raxol.demo               # run built-in demos
```

## Accessibility

Screen reader support and semantic annotations are not yet implemented. This is tracked as a roadmap item. Contributions welcome.

## License

MIT -- see [LICENSE.md](LICENSE.md)
