# Raxol

[![CI](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml/badge.svg?branch=master)](https://github.com/Hydepwns/raxol/actions/workflows/ci-unified.yml)

Terminal apps for Elixir, built on OTP.

Raxol gives you a component model, layout engine, and render pipeline for building terminal UIs -- the kind of thing you'd reach for Ratatui, Bubble Tea, or Textual to do, but in Elixir with all the OTP batteries included.

Your app is a GenServer. Components can crash and restart without taking down the UI. You can hot-reload your view function while the app is running. The same code renders to a terminal, a browser via LiveView, or over SSH. No other TUI framework does all of that.

## Install

```elixir
# mix.exs -- after Hex publish: {:raxol, "~> 2.2"}
def deps do
  [{:raxol, path: "../raxol"}]
end
```

Or generate a new project:

```bash
mix raxol.new my_app
```

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

Run it:

```bash
mix run examples/getting_started/counter.exs
```

## What You Get

**23 widgets** -- Button, TextInput, Table, Tree, Modal, SelectList, Checkbox, Sparkline, and more. All keyboard-navigable with focus management.

**Layout engine** -- Flexbox (`row`/`column` with `flex`, `gap`, `align_items`) and CSS Grid (`template_columns`, `template_rows`). Nested freely.

**60fps rendering** -- Virtual DOM diffing, damage tracking, synchronized terminal output. Full frame renders in ~2ms, leaving 87% of the budget for your code.

**Theming** -- Named colors, RGB, 256-color, hex strings. Auto-downsample to whatever the terminal supports. Runtime theme switching.

**Event system** -- W3C-style capture and bubble phases. Events propagate through the view tree with `on_click`, `on_change`, `on_event` handlers.

## What Makes It Different

These aren't bolted on -- they fall out naturally from running on the BEAM:

**Crash isolation** -- Wrap any widget in `process_component/2` and it runs in its own process. If it crashes, it restarts. The rest of your UI doesn't blink.

**Hot code reload** -- Change your `view/1` function, save the file, and the running app updates. No restart. Powered by `Raxol.Dev.CodeReloader` watching the filesystem.

**SSH serving** -- `Raxol.SSH.serve(MyApp, port: 2222)` and anyone can `ssh localhost -p 2222` into your app. Each connection gets its own supervised process.

**LiveView bridge** -- The same TEA app can render to a Phoenix LiveView. Terminal and browser, same codebase, same state model.

**AI agents as TEA apps** -- An agent is just a TEA app where input comes from LLMs and tools instead of a keyboard. `use Raxol.Agent`, implement `init/update/view`, and you get OTP supervision, crash isolation, and inter-agent messaging for free. Coordinate agent teams with a supervisor -- no agent framework needed, just processes.

```elixir
defmodule MyAgent do
  use Raxol.Agent

  def init(_ctx), do: %{findings: []}

  def update({:agent_message, _from, {:analyze, file}}, model) do
    {model, [Command.shell("wc -l #{file}")]}
  end

  def update({:command_result, {:shell_result, %{output: out}}}, model) do
    {%{model | findings: [out | model.findings]}, []}
  end
end

{:ok, _} = Raxol.Agent.Session.start_link(app_module: MyAgent, id: :my_agent)
Raxol.Agent.Session.send_message(:my_agent, {:analyze, "lib/raxol.ex"})
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
```

## Performance

Measured on Apple M1 Pro, Elixir 1.19 / OTP 26:

| Operation | Time |
|-----------|------|
| Full frame (create + fill + diff) | 2.1 ms |
| Tree diff (100 nodes) | 4 us |
| Cell write | 0.97 us |
| ANSI parse | 38 us |

2.1ms per frame = 13% of the 60fps budget. See the [benchmark suite](docs/bench/README.md) for comparison against Ratatui, Bubble Tea, and Textual.

## Documentation

**Start here** -- [Quickstart](docs/getting-started/QUICKSTART.md) / [Core Concepts](docs/getting-started/CORE_CONCEPTS.md) / [Widget Gallery](docs/getting-started/WIDGET_GALLERY.md)

**Cookbook** -- [Building Apps](docs/cookbook/BUILDING_APPS.md) / [SSH Deployment](docs/cookbook/SSH_DEPLOYMENT.md) / [Theming](docs/cookbook/THEMING.md) / [LiveView](docs/cookbook/LIVEVIEW_INTEGRATION.md) / [Performance](docs/cookbook/PERFORMANCE_OPTIMIZATION.md)

**Reference** -- [Architecture](docs/core/ARCHITECTURE.md) / [Buffer API](docs/core/BUFFER_API.md) / [Benchmarks](docs/bench/README.md) / [API Docs](https://hexdocs.pm/raxol)

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
