# Raxol

> Recursively, [axol](https://axol.io). Forever FOSS.

[![CI](https://github.com/DROOdotFOO/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/DROOdotFOO/raxol/actions/workflows/ci-unified.yml)
[![Hex](https://img.shields.io/hexpm/v/raxol.svg)](https://hex.pm/packages/raxol)

[OTP](https://en.wikipedia.org/wiki/Open_Telecom_Platform)-native terminal framework for Elixir.
Same app runs in a terminal, a browser via LiveView, or over SSH.

Your app is a [GenServer](https://hexdocs.pm/elixir/GenServer.html).
Components crash and restart without taking down the UI.
You can hot-reload your view function while it's running.
No other TUI framework does this; Raxol inherits it from the runtime.

## Try It

```bash
git clone https://github.com/DROOdotFOO/raxol.git
cd raxol && mix deps.get
mix raxol.playground          # 30 live demos, browse/search/filter
mix raxol.playground --ssh    # same thing, served over SSH (port 2222)
```

The flagship demo is a live BEAM dashboard: scheduler utilization, memory sparklines, process table, all updating in real time.

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
```

Other tools:

```bash
mix raxol.repl                                    # Sandboxed REPL (--sandbox strict)
mix phx.server                                    # Web playground at /playground
```

See [examples/README.md](examples/README.md) for the full learning path.

## Hello World

Every Raxol app follows [The Elm Architecture](https://guide.elm-lang.org/architecture/): `init`, `update`, `view`.

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

That counter works in a terminal. The same module renders in Phoenix LiveView or serves over SSH -- no changes needed.

## Install

```elixir
# mix.exs
def deps do
  [{:raxol, "~> 2.4"}]
end
```

Or generate a new project:

```bash
mix raxol.new my_app
```

## Architecture

Your app is a GenServer running [The Elm Architecture](https://guide.elm-lang.org/architecture/). The terminal backend is a real VT100 emulator, not raw escape codes -- agents can interact with structured screen buffers like they would with a browser DOM. Each component can run in its own OTP process. Crash one, the rest keep going.

One TEA app renders to terminal (termbox2 NIF on Unix, pure Elixir on Windows), Phoenix LiveView, and SSH. One codebase, three targets.

## Why OTP

These capabilities come from the [BEAM VM](<https://en.wikipedia.org/wiki/BEAM_(Erlang_virtual_machine)>), not a library:

| Capability                     | Raxol | Ratatui | Bubble Tea |       Textual       | Ink |
| ------------------------------ | :---: | :-----: | :--------: | :-----------------: | :-: |
| Crash isolation per component  |  yes  |   --    |     --     |         --          | --  |
| Hot code reload (no restart)   |  yes  |   --    |     --     |         --          | --  |
| Same app in terminal + browser |  yes  |   --    |     --     |       partial       | --  |
| Built-in SSH serving           |  yes  |   --    |  via lib   |         --          | --  |
| AI agent runtime               |  yes  |   --    |     --     |         --          | --  |
| Distributed clustering (CRDTs) |  yes  |   --    |     --     |         --          | --  |
| Time-travel debugging          |  yes  |   --    |     --     | partial<sup>1</sup> | --  |

Ratatui and Bubble Tea have excellent rendering and large ecosystems. Raxol's edge is structural -- OTP gives you these things for free.

<sup>1</sup> Textual has devtools with CSS inspection, but not state-level time-travel (stepping back/forward through update cycles).

## Features

### Core

**Process isolation.** Wrap any widget in `process_component/2` and it runs in its own process. Crashes restart cleanly; the rest of the UI stays up.

**Hot code reload.** Change your `view/1`, save, the running app picks it up. No restart.

**Widgets and layout.** Button, TextInput, Table, Tree, Modal, SelectList, Checkbox, Sparkline, Charts. Keyboard-navigable with focus management. Flexbox (`row`/`column` with `flex`, `gap`, `align_items`) and CSS Grid (`template_columns`, `template_rows`), nested freely. Virtual DOM diffing with damage tracking.

**Theming.** Named colors, RGB, 256-color, and hex -- downsampled to the terminal's capability. Inline images via Kitty graphics protocol, with Sixel and iTerm2 fallbacks.

### Multi-target

**SSH serving.** `Raxol.SSH.serve(MyApp, port: 2222)`. Each connection gets its own supervised process.

**LiveView bridge.** Same TEA app renders in Phoenix LiveView with a shared state model. See `examples/liveview/tea_counter_live.ex`.

**Distributed swarm.** CRDTs (LWW registers, OR-sets), node monitoring, seniority-based election. Discovery via libcluster with gossip, epmd, DNS, or Tailscale.

### AI and agents

An agent is a TEA app where input comes from LLMs instead of a keyboard. `use Raxol.Agent`, implement `init/update/view`, and you get supervised agents with inter-agent messaging. SSE streaming to Anthropic, OpenAI, Ollama, Groq. Free tier via LLM7.io.

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

**Agentic commerce.** Agents can pay for things autonomously. `raxol_payments` provides wallet management, spending controls with per-request/session/lifetime limits, and three payment protocols: x402 (Coinbase HTTP 402 auto-pay), MPP (Stripe/Tempo machine payments), and Xochi (cross-chain intent settlement). A Req plugin handles 402 flows transparently. See [docs](docs/features/AGENTIC_COMMERCE.md).

**Sensor fusion.** Poll sensors, fuse readings with weighted averaging, render gauges and sparklines. Self-adapting layout tracks usage and recommends changes (optional Nx/Axon ML backend).

### Developer tools

**Headless sessions and MCP.** Run any TEA app without a terminal for programmatic testing and AI integration. Tools are auto-derived from the widget tree -- Button exposes `click`, TextInput exposes `type_into`/`clear`/`get_value`. A focus lens filters to ~15 relevant tools per interaction. `mix mcp.server` starts the MCP server on stdio for Claude Code. Test with a pipe-friendly API:

```elixir
import Raxol.MCP.Test
import Raxol.MCP.Test.Assertions

session = start_session(MyApp)

session
|> type_into("search", "elixir")
|> click("submit")
|> assert_widget("results", fn w -> w[:content] != nil end)
|> stop_session()
```

**Time-travel debugging.** Snapshots every `update/2` cycle: step back, forward, jump, restore. Zero cost when disabled.

**Session recording.** Captures to asciinema v2 `.cast` files with pause, seek, speed control, and auto-save on crash.

**Sandboxed REPL.** `mix raxol.repl` with three safety levels. AST-based scanning blocks dangerous operations; safe for SSH in strict mode. The playground has 30 demos across 8 categories.

## Performance

Full frame in 2.1ms on Apple M1 Pro (Elixir 1.19 / OTP 27) -- 13% of the 60fps budget.

| What                              | Time    |
| --------------------------------- | ------- |
| Full frame (create + fill + diff) | 2.1 ms  |
| Tree diff (100 nodes)             | 4 μs    |
| Cell write                        | 0.97 μs |
| ANSI parse                        | 38 μs   |

The Unix/macOS backend uses a termbox2 NIF; Windows uses a pure Elixir driver (usable, not yet tuned). See the [benchmark suite](docs/bench/README.md) for methodology.

## Documentation

**Start here**

- [Quickstart](docs/getting-started/QUICKSTART.md)
- [Core Concepts](docs/getting-started/CORE_CONCEPTS.md)
- [Widget Gallery](docs/getting-started/WIDGET_GALLERY.md)

**Cookbook**

- [Building Apps](docs/cookbook/BUILDING_APPS.md)
- [SSH Deployment](docs/cookbook/SSH_DEPLOYMENT.md)
- [Theming](docs/cookbook/THEMING.md)
- [LiveView](docs/cookbook/LIVEVIEW_INTEGRATION.md)
- [Performance](docs/cookbook/PERFORMANCE_OPTIMIZATION.md)

**Reference**

- [Architecture](docs/core/ARCHITECTURE.md)
- [Buffer API](docs/core/BUFFER_API.md)
- [Benchmarks](docs/bench/README.md)
- [API Docs](https://hexdocs.pm/raxol)

**Advanced**

- [Agent Framework](docs/features/AGENT_FRAMEWORK.md)
- [Agentic Commerce](docs/features/AGENTIC_COMMERCE.md)
- [Sensor Fusion](docs/features/SENSOR_FUSION.md)
- [Distributed Swarm](docs/features/DISTRIBUTED_SWARM.md)
- [Recording & Replay](docs/features/RECORDING_REPLAY.md)
- [Why OTP for TUIs](docs/WHY_OTP.md)

**Standalone packages** -- grab just the subsystem you need:

| Package                                                    | Hex                           | What                                       |
| ---------------------------------------------------------- | ----------------------------- | ------------------------------------------ |
| [`raxol_core`](https://hex.pm/packages/raxol_core)         | `{:raxol_core, "~> 2.4"}`     | Behaviours, events, config, plugins        |
| [`raxol_terminal`](https://hex.pm/packages/raxol_terminal) | `{:raxol_terminal, "~> 2.4"}` | Terminal emulation, termbox2 NIF           |
| [`raxol_mcp`](https://hex.pm/packages/raxol_mcp)           | `{:raxol_mcp, "~> 2.4"}`      | MCP server, client, registry, test harness |
| [`raxol_agent`](https://hex.pm/packages/raxol_agent)       | `{:raxol_agent, "~> 2.4"}`    | AI agent framework                         |
| [`raxol_sensor`](https://hex.pm/packages/raxol_sensor)     | `{:raxol_sensor, "~> 2.4"}`   | Sensor fusion (zero deps)                  |
| [`raxol_payments`](https://hex.pm/packages/raxol_payments) | `{:raxol_payments, "~> 0.1"}` | Agent payments, Xochi cross-chain, stealth |
| [`raxol_liveview`](https://hex.pm/packages/raxol_liveview) | `{:raxol_liveview, "~> 2.4"}` | Phoenix LiveView bridge, themes, CSS       |
| [`raxol_plugin`](https://hex.pm/packages/raxol_plugin)     | `{:raxol_plugin, "~> 2.4"}`   | Plugin SDK, testing, generator             |

## Development

```bash
git clone https://github.com/DROOdotFOO/raxol.git
cd raxol
mix deps.get
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
mix raxol.check              # format, compile, credo, dialyzer, security, test
mix raxol.check --quick      # skip dialyzer
mix raxol.demo               # run built-in demos
```

## Accessibility

Screen reader support and semantic annotations aren't implemented yet. Tracked as a roadmap item. Contributions welcome.

## Origin Vision

> Raxol started as two converging ideas: a terminal for AGI, where AI agents
> interact with a real terminal emulator the same way humans do;
> and an interface for the cockpit of a Gundam Wing Suit, where fault isolation,
> real-time responsiveness, and sensor fusion are survival-critical.

## License

MIT. See [LICENSE.md](LICENSE.md).
