# Raxol Ideas

## Origin Vision

Raxol started as two converging ideas: a terminal for AGI -- where AI agents
interact with a real terminal emulator the same way humans do -- and an interface
for the cockpit of a Gundam Wing Suit, where fault isolation, real-time
responsiveness, and sensor fusion are survival-critical.

## Key Architectural Differentiators

1. **Real VT100 Emulator** -- AI agents interact with structured buffers, not raw escape codes
2. **Multi-Agent Architecture** -- Each agent is a supervised OTP process with crash isolation
3. **BEAM VM Strengths** -- Soft real-time, per-subsystem isolation, multi-node distribution, hot code reload
4. **Three-Surface Rendering** -- Same TEA app in terminal, browser (TEALive), and SSH

## Completed (see git history for details)

- Agent-as-TEA, Mission Plugin System, AGI Cockpit Console
- Sensor Fusion HUD, Distributed Swarm, Self-Evolving Interface
- 23 widgets, flexbox + CSS grid layout, TEA architecture
- Process-per-component, hot code reload, LiveView bridge, SSH serving
- Session recording & replay, `mix raxol.new` generator, `mix raxol.demo`
- Inline image display (iTerm2/Kitty, Sixel with real dithering, ETS image cache)
- Streaming charts as first-class View DSL widgets (line_chart, bar_chart, scatter_chart, heatmap, sparkline)
- Component playground (terminal + web + SSH), 23 demos across 7 categories
- Code quality P3-P6 (0 skipped tests, 5361 passing, 0 dialyzer errors unsuppressed)

## Completed: Playground (Phase 6 in SPECS.md)

One component catalog, three surfaces. Same TEA demo apps render on all three:

- `mix raxol.playground` -- terminal TEA app (23 demos, search, filtering, help)
- Web -- real TEALive rendering (replaced HTML mockups), invites to terminal/SSH
- `ssh playground@raxol.io` -- SSH serving (fly.toml + connection limits)

## Future Feature Ideas

### Playground Enhancements (post-core)

- **Real REPL**: Sandboxed Elixir eval in browser and terminal (security implications)
- **Shareable links**: URL-encoded playground state for sharing widget configs
- **Collaborative editing**: Multi-user playground sessions (presence infra exists)
- **Property editor**: Sidebar to tweak widget props live (like Storybook)
- **Theme builder**: Interactive theme creation tool in the playground

### Charts & Data Visualization (Done)

Charts wired into View DSL as first-class widgets: `line_chart/1`, `bar_chart/1`,
`scatter_chart/1`, `heatmap/1`, `sparkline/1`. All available via `import View`.
Chart demos in playground catalog using DSL functions directly.

- Real-time streaming with auto-scaling axes (examples demonstrate this already)

### Time-Travel Debugging

Snapshot application state at each update cycle. Step forward/backward through
state transitions. Inspect model, view tree, and terminal buffer at any point.

### Collaborative Sessions

Multiple users share a terminal session via OTP distribution or WebSocket.
Cursor awareness, permissions (view-only vs control), chat overlay.

### SSH Session Multiplexing

tmux-like window/pane data structures for SSH sessions. Multiple terminal panes
per SSH connection, switchable with keyboard shortcuts.

## OTP/Elixir Ecosystem to Leverage

- **Nx / Bumblebee / Axon** -- ML inference native on BEAM (Fusion, LayoutRecommender)
- **FLAME** -- Elastic compute for model training bursts
- **Burrito** -- Package as single standalone binary
- **libcluster** -- Automatic node discovery for Swarm (currently manual)

## Demo & Marketing Ideas

- Record demos: cockpit, counter, agent_team (`mix raxol.record`)
- Convert .cast to GIFs for README/social (agg or svg-term)
- Twitter thread: "What if your terminal framework had OTP superpowers?"
- Post to r/elixir, Elixir Forum, HN
- Demo apps: file browser with agent search, chat TUI, log tailer

## Ecosystem

- Documentation site with widget gallery, tutorials, examples
- VS Code extension for component previews
- Benchmark suite comparing against Ratatui/Bubble Tea/Textual

## The Convergence Thesis

Terminal emulator + OTP supervision + Nx + LiveView + hot code reload +
distribution. No other framework combines all of these.

- Python TUI can't do fault isolation
- Rust TUI can't do hot reload
- Web dashboard can't do local terminal interaction
- **Only Raxol**: AI agent, human pilot, and remote operator all interact with
  the same state through different interfaces (terminal, browser, SSH) with
  the whole thing self-healing
