# Raxol Application Specs

Technical specifications for Raxol's application layers, charts, and playground.

---

## Completed Phases (Summary)

All 5 application layers + ecosystem tooling + charts are done. See git history for full specs.

| Phase | Application | Modules | Tests | Key APIs |
|-------|-------------|---------|-------|----------|
| 0 | Agent-as-TEA | 4 | 39 | `use Raxol.Agent`, Session, Team, Comm |
| 1 | Mission Plugin System | 4 | 42 | Manifest, DependencyResolver, MissionProfile, ResourceBudget |
| 2 | AGI Cockpit Console | 8+ | 87 | AIBackend, Process, Orchestrator, Protocol, ContextStore |
| 3a | Sensor Fusion HUD | 7 | 48 | Feed, Fusion, HUD renderer, HUDOverlay |
| 3b | Distributed Swarm | 8 | 64 | CRDTs, NodeMonitor, CommsManager, Topology, TacticalOverlay |
| 4 | Self-Evolving Interface | 5 | 41 | BehaviorTracker, LayoutRecommender, LayoutTransition, FeedbackLoop |
| **Total** | | **~36** | **~321** | |

### Streaming Data Visualization -- DONE

7 modules in `lib/raxol/ui/charts/`, 91 tests, 5 examples:

| Module | LOC | Purpose |
|--------|-----|---------|
| ChartUtils | 189 | Shared: scaling, ranges, axes, legend, formatting |
| BrailleCanvas | 170 | 2x4 dot grid with per-layer multicolor merge |
| LineChart | 169 | Bresenham at braille dot resolution, multi-series |
| ScatterChart | 125 | Braille 2D scatter, multi-series |
| BarChart | 296 | Block chars (8 sub-char levels), vertical/horizontal, grouped |
| Heatmap | 161 | bg-color intensity, 3 built-in scales + custom fn |
| ViewBridge | 60 | cell tuples -> View DSL elements |

### Time-Travel Debugging -- DONE

2 modules in `lib/raxol/debug/`, 43 tests:

| Module | LOC | Purpose |
|--------|-----|---------|
| Snapshot | 124 | Snapshot struct, recursive map diff (changed/added/removed with key paths) |
| TimeTravel | 339 | GenServer: CircularBuffer history, cursor navigation, pause/resume, restore, export/import |

Hooks into Dispatcher's `process_app_update/3` to capture `{message, model_before, model_after}` at every `update/2` boundary. Lifecycle option `time_travel: true` starts the GenServer and wires it to the Dispatcher. `restore/0` sends the historical model back to the Dispatcher and triggers re-render. Zero cost when disabled.

### Future Nx Integration Points

- `Sensor.Fusion.fuse_batch/2` -- replace rule-based weighted averaging with Nx model
- `LayoutRecommender.apply_rules/2` -- replace rule engine with Axon MLP inference
- `FeedbackLoop.force_retrain/1` -- stub ready for background Axon training Task

---

## Phase 6: Playground

### Vision

One component catalog, three surfaces: terminal, browser, SSH. The same TEA
demo app renders identically on all three. This is the killer differentiator --
no other TUI framework can do this.

The web playground invites users to try the real terminal experience:

```
Love this in the browser? Try the real thing:

  $ mix raxol.playground           # local
  $ ssh playground@raxol.io        # remote
```

### Architecture

```
Raxol.Playground.Catalog           <-- shared component registry + demo apps
  |
  +---> mix raxol.playground       <-- terminal TEA app (Phase 6.1)
  |
  +---> PlaygroundLive (web)       <-- TEALive bridge rendering (Phase 6.2)
  |
  +---> ssh playground@raxol.io    <-- SSH serving (Phase 6.3)
```

All three surfaces consume the same `Catalog` and render the same demo TEA
apps. The web version uses TEALive to bridge TEA apps into LiveView. The SSH
version uses `Raxol.SSH.serve/2` (already implemented).

### 6.1 Component Catalog + Terminal Playground -- DONE

**Goal**: Shared component registry and a `mix raxol.playground` TEA app that
lets you browse, interact with, and copy code for all 23 widgets.

#### Catalog Module

`Raxol.Playground.Catalog` -- single source of truth for widget metadata.

```elixir
defmodule Raxol.Playground.Catalog do
  @type component :: %{
    name: String.t(),
    module: module(),          # the demo TEA app
    category: atom(),          # :input, :display, :feedback, :navigation, :overlay, :layout
    description: String.t(),
    complexity: :basic | :intermediate | :advanced,
    tags: [String.t()],
    code_snippet: String.t()   # copy-pasteable example
  }

  def list_components() :: [component]
  def get_component(name) :: component | nil
  def list_categories() :: [atom()]
  def filter(opts) :: [component]  # by category, complexity, search query
end
```

Each widget gets a **demo TEA app** -- a minimal `init/update/view` module that
showcases the widget with interactive state. These live in
`lib/raxol/playground/demos/` and implement `Raxol.Core.Runtime.Application`.

```elixir
# Example: lib/raxol/playground/demos/button_demo.ex
defmodule Raxol.Playground.Demos.ButtonDemo do
  use Raxol.Core.Runtime.Application

  def init(_opts), do: %{clicks: 0, variant: :primary}

  def update({:click, _}, model), do: %{model | clicks: model.clicks + 1}
  def update({:variant, v}, model), do: %{model | variant: v}

  def view(model) do
    column do
      text(content: "Button Demo")
      row do
        button(label: "Click Me (#{model.clicks})", on_click: {:click, nil})
        button(label: "Secondary", variant: :secondary, on_click: {:click, nil})
      end
      text(content: "Variant: #{model.variant} | Clicks: #{model.clicks}")
    end
  end
end
```

#### Terminal App

`Raxol.Playground.App` -- the main playground TEA app.

```
+-- Raxol Playground -----------------------------------------------+
| Components          | Button Demo                                 |
| ------------------- | ------------------------------------------- |
| INPUT               |  [ Click Me (3) ]  [ Secondary ]            |
|   > Button          |                                             |
|     TextInput       |  Variant: primary | Clicks: 3               |
|     Checkbox        | ------------------------------------------- |
|     SelectList      | Code:                                       |
|     Menu            |   button(label: "Click Me",                 |
| DISPLAY             |     on_click: {:click, nil})                 |
|     Table           |                                             |
|     Progress        | [j/k] Navigate  [Enter] Select  [Tab] Panel |
|     Tree            | [/] Search  [q] Quit  [c] Copy code         |
+---------------------+---------------------------------------------+
```

Layout: 3-panel split (sidebar, demo area, code area). Keyboard-driven:
- `j`/`k` or arrows: navigate component list
- `Enter`: select component, loads its demo TEA app in the main area
- `Tab`: cycle focus between panels
- `/`: search components
- `c`: copy code snippet to clipboard
- `q`: quit

Modules:

| Module | Path | Type | LOC est |
|--------|------|------|---------|
| `Catalog` | `lib/raxol/playground/catalog.ex` | pure func | ~150 |
| `App` | `lib/raxol/playground/app.ex` | TEA app | ~300 |
| `Mix.Tasks.Raxol.Playground` | `lib/mix/tasks/raxol.playground.ex` | mix task | ~50 |
| Demo apps (23) | `lib/raxol/playground/demos/*.ex` | TEA apps | ~50-100 each |

The demo apps are small -- each one just shows the widget with enough state
to be interactive. No demo should exceed ~100 LOC.

#### Phasing

**Step 1** (DONE): Catalog + 6 core widget demos (Button, TextInput, Table,
Progress, Modal, Menu) + terminal App with sidebar and demo area + `mix
raxol.playground` working end-to-end.

**Step 2** (DONE): Remaining 17 widget demos. 23 total across 7 categories
(input, display, feedback, navigation, overlay, layout, visualization).
164 playground tests, 0 failures.

**Step 3** (DONE): Category filter (`f`), complexity filter (`x`), help overlay (`?`).
Filters compose with search via `Catalog.filter/1`. Help swallows input until dismissed.
181 playground tests, 0 failures.

### 6.2 Web Playground (Refactor) -- DONE

**Goal**: Replace the simulated web playground with real TEALive-rendered demos.
The browser should show *actual* Raxol rendering, not HTML approximations.

#### What Changes

The existing `web/` playground has good UI chrome (sidebar, toolbar, themes,
presence, search) but fakes the rendering. The refactor:

1. **Replace `DemoComponents`** (HTML mockups) with TEALive-hosted demo apps
   from the shared Catalog. Each demo renders through the existing LiveView
   bridge (`Raxol.LiveView.TEALive`), producing real terminal output in the
   browser.

2. **Replace `TerminalView`** (ASCII art) with actual buffer-to-HTML rendering.
   The LiveView bridge already does this with caching and dirty checking.

3. **Replace `CodeExecutor`** (fake compilation) with displaying the
   Catalog's `code_snippet` for each component. No need for actual code
   execution in phase 1.

4. **Consolidate component data** -- `GalleryLive` and `PlaygroundLive` both
   hardcode component lists. Both should read from `Catalog`.

5. **Replace `ReplLive`** (simulated eval) with a "try it" prompt pointing to
   `mix raxol.playground` / SSH. Real REPL is a future feature.

6. **Add SSH callout** -- prominent banner on every page:
   ```
   Try the real terminal experience:
     ssh playground@raxol.io
     mix raxol.playground
   ```

#### Modules (refactored, not new)

| Module | Change |
|--------|--------|
| `PlaygroundLive` | Demo mode uses TEALive components from Catalog |
| `GalleryLive` | Reads from `Catalog` instead of hardcoded list |
| `DemoLive` | Each demo is a TEALive-hosted Catalog demo app |
| `DemoComponents` | Deleted -- replaced by TEALive rendering |
| `TerminalView` | Deleted -- replaced by buffer-to-HTML bridge |
| `CodeExamples` | Simplified -- reads `code_snippet` from Catalog |
| `CodeExecutor` | Deleted -- no fake compilation |
| `ReplLive` | Replaced with "try terminal" landing page |

The theme system (10 themes) and presence/sync features are kept -- they work
and add value.

### 6.3 SSH Playground

**Goal**: `ssh playground@raxol.io` drops you into the playground.

This is straightforward -- `Raxol.SSH.serve/2` already exists:

```elixir
# In deployment config or a standalone script
Raxol.SSH.serve(Raxol.Playground.App, port: 2222)
```

Each SSH connection gets its own Lifecycle process with its own state.
No new modules needed, just deployment config.

#### Deployment

- Add SSH port (2222) to `fly.toml` services
- Generate host key, store in Fly secrets
- Optional: rate limiting, connection cap

### Summary

| Step | Deliverable | Status | Modules |
|------|-------------|--------|---------|
| 6.1 Step 1 | Catalog + 6 demos + `mix raxol.playground` | DONE | 10 |
| 6.1 Step 2 | Remaining 17 demos (23 total) | DONE | 17 |
| 6.1 Step 3 | Search, filtering, help | DONE | ~0 (enhance App) |
| 6.2 | Web refactor (TEALive rendering) | DONE | ~0 (refactor existing) |
| 6.3 | SSH playground on raxol.io | DONE | ~0 (config only) |

### Design Principles

- **No fakes**: Every preview is real Raxol rendering. If it runs in the
  playground, it runs in your app.
- **Copy-paste ready**: Every demo has a code snippet you can drop into a
  project scaffolded by `mix raxol.new`.
- **Three surfaces, one codebase**: Terminal, browser, SSH all render the
  same demo apps. This IS the pitch.
- **Invite to terminal**: The web playground always nudges toward the real
  terminal experience. Like Bubble Tea's `ssh` demos but with the added
  twist that the browser version is equally real.
