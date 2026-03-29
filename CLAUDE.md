# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Initial Setup

```bash
mix deps.get
```

The termbox2 NIF source (in `packages/raxol_terminal/lib/termbox2_nif/c_src/`) is vendored directly in the repo -- no git submodules needed.

### Building & Compilation

```bash
MIX_ENV=test mix compile
MIX_ENV=test mix compile --warnings-as-errors
```

### Testing

```bash
MIX_ENV=test mix test --exclude slow --exclude integration --exclude docker
MIX_ENV=test mix test test/path/to/test_file.exs      # specific file
MIX_ENV=test mix test test/path/to/test_file.exs:42   # specific line
MIX_ENV=test mix test --max-failures 5                 # limit failures
MIX_ENV=test mix test --failed                         # rerun failed
```

Note: `TMPDIR=/tmp` and `SKIP_TERMBOX2_TESTS=true` are set automatically via `.claude/settings.json`. `MIX_ENV=test` must be specified explicitly for compile and test commands.

### Code Quality

```bash
mix raxol.check               # All checks: format, compile, credo, dialyzer, security, test
mix raxol.check --quick       # Skip dialyzer
mix raxol.check --only format,credo  # Run specific checks only
mix raxol.check --skip test   # Skip specific checks
mix format                    # Format code
mix format --check-formatted  # Check formatting (CI)
mix credo                     # Style checks
mix dialyzer                  # Type checking
```

### Running Examples

```bash
mix run examples/getting_started/counter.exs  # Known working example (TEA model)
```

Working examples: `counter.exs`, `getting_started/todo_app.exs`, `apps/todo_app.ex`, `apps/showcase_app.exs`, `demo.exs` (all TEA pattern).
`demo.exs` is the flagship demo showing dashboard layout, live stats, and OTP differentiators.

Agent examples: `agents/code_review_agent.exs` (single agent with shell commands), `agents/agent_team.exs` (coordinator + worker team pattern), `agents/ai_cockpit.exs` (multi-agent AI cockpit with real LLM streaming -- mock by default, `FREE_AI=true` for LLM7.io, supports Anthropic/OpenAI/Ollama/Groq).

Sensor examples: `sensor_hud_demo.exs` (3 mock sensors with gauge, sparkline, threat HUD widgets).

Adaptive examples: `adaptive_ui_demo.exs` (behavior tracking, layout recommendations, feedback loop).

Playground: `mix raxol.playground` -- interactive widget catalog with 28 demos across 8 categories (input, display, feedback, navigation, overlay, layout, visualization, effects). Demos are self-contained TEA apps in `lib/raxol/playground/demos/`. Chart demos use View DSL functions directly. SSH mode: `mix raxol.playground --ssh` serves the playground over SSH (port 2222 by default). Production SSH enabled via `RAXOL_SSH_PLAYGROUND=true` env var in fly.toml.

### Development

```bash
mix phx.server                # Start Phoenix server (includes Tidewave in dev)
mix raxol.gen.specs lib/path  # Generate type specs for private functions
mix docs                      # Generate documentation
```

### Development Scripts

```bash
./scripts/dev.sh test [pattern]  # Run tests with grep filter
./scripts/dev.sh test-all        # Comprehensive test suite
./scripts/dev.sh check           # Pre-commit quality checks
./scripts/dev.sh dialyzer        # Static analysis with PLT caching
./scripts/dev.sh setup           # Environment setup
```

## Architecture

Raxol is an AGI-ready terminal framework for Elixir -- component model, agent runtime, sensor fusion, distributed swarm, and time-travel debugging on OTP. Supports multiple UI paradigms (React, LiveView, HEEx, Raw).

### Application Model

**TEA (The Elm Architecture) is the canonical app model.** Applications implement `init/1`, `update/2`, and `view/1` callbacks, mapped to a GenServer via `Raxol.start_link/2` which delegates to `Raxol.Core.Runtime.Lifecycle.start_link/2`. Do not introduce competing application models (e.g., LiveView-style `mount/render`).

```elixir
use Raxol.UI, framework: :react      # React patterns (TEA)
use Raxol.UI, framework: :liveview   # Phoenix LiveView patterns
use Raxol.UI, framework: :heex       # Phoenix templates
use Raxol.UI, framework: :raw        # Direct terminal control
```

### Extracted Packages

The codebase is decomposed into focused packages under `packages/`:

```
packages/
├── raxol_core/      # Behaviours, utils, events, config, accessibility, plugins
├── raxol_terminal/  # Terminal emulation (VT100/ANSI), termbox2 NIF, screen buffer
├── raxol_sensor/    # Sensor fusion (zero Raxol deps)
├── raxol_agent/     # AI agent framework (depends on main raxol)
├── raxol_liveview/  # (scaffold) LiveView bridge -- not yet wired
└── raxol_plugin/    # (scaffold) Plugin SDK -- not yet wired
```

**Dependency graph** (arrows = "depends on"):

```
raxol (main) --> raxol_core, raxol_terminal, raxol_sensor
raxol_terminal --> raxol_core
raxol_agent --> raxol (main does NOT depend on raxol_agent)
raxol_core --> telemetry (only external dep)
raxol_sensor --> (none)
```

Cross-package references use `@compile {:no_warn_undefined, Module}` and `Code.ensure_loaded?/1` guards. Struct patterns across package boundaries use map patterns (`%{field: x}`) instead of struct patterns (`%Struct{field: x}`).

**Package test commands:**

```bash
cd packages/raxol_core && MIX_ENV=test mix test       # 765 tests
cd packages/raxol_terminal && MIX_ENV=test mix test    # 1874 tests
cd packages/raxol_sensor && MIX_ENV=test mix test      # 55 tests
cd packages/raxol_agent && MIX_ENV=test mix test       # 131 tests
```

### Core Layers (main raxol)

```
lib/raxol/
├── ui/              # Multi-framework UI
│   ├── components/  # Widgets: TextInput, Table, Button, Modal, SelectList, Checkbox, Tree, etc.
│   ├── charts/      # Streaming charts: LineChart, ScatterChart, BarChart, Heatmap, BrailleCanvas
│   ├── layout/      # Flexbox/CSS grid engines, Preparer (two-phase), ScrollContent (lazy scroll)
│   ├── rendering/   # UI rendering (TreeDiffer, Composer, Painter, DamageTracker, etc.)
│   ├── text_measure.ex  # Unicode display width facade (single source of truth)
│   └── theming/
├── core/            # Services and utilities (runtime stays here; behaviours/events/config in raxol_core)
│   ├── renderer/    # Core rendering primitives (layout, views)
│   ├── runtime/     # Plugin system, lifecycle, event management
│   └── *_compat.ex  # Compatibility layers (Buffer, Renderer, Style, Box)
├── adaptive/        # Self-evolving interface (behavior tracking, layout recommendations)
├── debug/           # Time-travel debugger (snapshot TEA state per update cycle)
├── recording/       # Session recording & replay (Asciinema v2 format)
├── swarm/           # Distributed subsystem (CRDTs, node monitoring, topology)
│   ├── discovery.ex   # libcluster wrapper with strategy presets
│   ├── strategy/      # Custom libcluster strategies (Tailscale)
│   └── crdt/          # LWWRegister, ORSet (pure functional)
├── playground/      # Interactive widget catalog (28 demos, 8 categories)
├── ssh/             # SSH serving
├── repl/            # Interactive REPL
├── performance/     # Performance monitoring, profiling, caching
├── live_view/       # Phoenix LiveView integration (terminal + browser bridge)
└── effects/         # Visual effects (CursorTrail, etc.)
```

### Key Architectural Decisions

**Terminal Backend**: Automatic platform detection in `packages/raxol_terminal/lib/raxol/terminal/driver.ex`

- Unix/macOS: Native termbox2 NIF (`packages/raxol_terminal/lib/termbox2_nif/c_src/`)
- Windows: Pure Elixir IOTerminal (`packages/raxol_terminal/lib/raxol/terminal/io_terminal.ex`)

**Compat Layer**: The `lib/raxol/core/*_compat.ex` files provide the public `Raxol.Core.*` API (Buffer, Renderer, Style, Box).

**BaseManager Pattern**: GenServers use `use Raxol.Core.Behaviours.BaseManager` for consistent lifecycle management.

**State Management**: ETS-backed UnifiedStateManager

**Configuration**: TOML-based (`config/raxol.example.toml` as template) with environment overrides in `config/environments/`

**Agent Framework** (in `packages/raxol_agent/`): `use Raxol.Agent` creates TEA apps for AI agents. `Agent.Session` wraps Lifecycle with `environment: :agent` (skips terminal driver and plugin manager, uses anonymous Dispatcher to avoid singleton conflicts). Agents discover each other via `Raxol.Agent.Registry` (unique Registry). `Agent.Team` is an OTP Supervisor for coordinator/worker groups. Three agent-specific Command types: `:async` (streaming sender callback), `:shell` (Port-based execution), `:send_agent` (Registry-routed inter-agent messages arriving as `{:agent_message, from, payload}`). `view/1` is optional -- headless agents skip rendering entirely. Note: raxol_agent depends on main raxol, not the other way around.

**Swarm Discovery**: `Raxol.Swarm.Discovery` wraps libcluster (optional dep) with strategy presets: `:gossip` (LAN multicast), `:epmd` (static hosts), `:dns` (Fly.io/K8s), `:tailscale` (mesh via `tailscale status --json`, tag-filtered). NodeMonitor auto-wires `:nodeup`/`:nodedown` events to Topology (elections) and TacticalOverlay (peer sync). Custom strategy: `Raxol.Swarm.Strategy.Tailscale`.

**AI Backend Streaming**: `Raxol.Agent.Backend.HTTP.stream/2` provides real SSE streaming for Anthropic, OpenAI, Ollama, and Kimi APIs. Uses `Stream.resource/3` + `spawn_link` + message passing. Four SSE formats: Anthropic (content_block_delta), OpenAI/Kimi (data chunks + `[DONE]`), Ollama (NDJSON), Lumo (data: JSON per line with U2L decryption). `Raxol.Agent.Backend.Lumo` implements Proton Lumo's full U2L encryption protocol (per-request AES-256-GCM + PGP key delivery via gpg) with lumo-tamer OpenAI-compatible proxy as fallback. Tiered backend detection: Lumo -> Anthropic -> Kimi -> OpenAI -> Ollama -> LLM7 -> Mock.

**Time-Travel Debugging**: `Raxol.start_link(MyApp, time_travel: true)` enables snapshot recording of every `update/2` cycle. `Raxol.Debug.TimeTravel` stores `{message, model_before, model_after}` in a CircularBuffer. Navigate with `step_back/0`, `step_forward/0`, `jump_to/1`. `restore/0` sends the historical model to the Dispatcher for re-render. `Snapshot.diff/2` computes recursive map changes. Zero cost when disabled.

**SSH Architecture**: `Raxol.SSH.Server` wraps `:ssh.daemon` with auto-generated host keys. Each connection spawns a `Raxol.SSH.Session` running a Lifecycle with `environment: :ssh`. `CLI_Handler` translates SSH channel data to Raxol events. `IO_Adapter` bridges SSH channel I/O to the terminal rendering pipeline.

**REPL Architecture**: `Raxol.REPL.Evaluator` wraps `Code.eval_string` with `spawn_monitor` timeout, `StringIO` IO capture via group_leader swap, and persistent bindings across evaluations. `Raxol.REPL.Sandbox` scans ASTs via `Macro.prewalk` at three levels: `:none` (unrestricted), `:standard` (blocks System.cmd/File.rm/Port.open/etc), `:strict` (whitelist-only, safe for SSH exposure).

**Phoenix as library only**: No active web server in core, Ecto.Repo explicitly disabled at runtime.

### Buffer/Renderer API

The `Raxol.Core.Renderer` API:

- `render_diff/2` returns operation tuples: `[{:move, x, y}, {:write, text, style}, ...]`
- `apply_diff/1` converts operations to ANSI string for `IO.write/1`

```elixir
diff = Renderer.render_diff(old_buffer, new_buffer)
IO.write(Renderer.apply_diff(diff))  # NOT Enum.each(diff, &IO.write/1)
```

### Render Pipeline

The render pipeline lives in `lib/raxol/ui/rendering/` (10 modules: TreeDiffer, Layouter, Composer, Painter, DamageTracker, ComponentCache, RenderBatcher, TimerServer, Renderer, LayouterCached) plus `lib/raxol/ui/layout/` (Preparer, PreparedElement, ScrollContent). The flow is:

1. `view(model)` -> element tree
2. `Preparer.prepare_incremental` -> PreparedElement tree (cached text measurements)
3. `LayoutEngine.apply_layout` -> positioned elements (arithmetic only)
4. `UIRenderer.render_to_cells` -> cell tuples `{x, y, char, fg, bg, attrs}`
5. `ScreenBuffer` -> diff -> `Terminal.Renderer` -> ANSI output

**Text measurement**: All display-width-sensitive code uses `Raxol.UI.TextMeasure` (facade in `lib/raxol/ui/text_measure.ex`), which delegates to `Raxol.Terminal.CharacterHandling` for correct CJK/Unicode width. Never use `String.length` for display width.

**Scrollable containers**: `Raxol.UI.Layout.ScrollContent` behaviour enables lazy content sourcing for Viewport. `ListScrollContent` wraps lists, `StreamScrollContent` wraps fetch functions with a sliding cache window.

### Testing Patterns

**Test Tags** (auto-excluded based on environment):

- `@tag :docker` - Requires termbox2/Docker (excluded when `SKIP_TERMBOX2_TESTS=true`)
- `@tag :skip_on_ci` - Skip in CI (excluded when `SKIP_TERMBOX2_TESTS=true`)
- `@tag :unix_only` - Unix/macOS only (excluded on Windows)
- `@tag :slow` / `@tag :integration` - Long-running tests

**Test Infrastructure**:

- Test helpers in `test/support/` (IsolationHelper, TerminalTestHelper, etc.)
- `Raxol.Test.IsolationHelper.reset_global_state()` runs between tests
- Property-based tests in `test/property/`
- MockDB used instead of Ecto sandbox
- Mox mocks defined in `test/test_helper.exs` for core runtime behaviours

### Naming Conventions

- Module files: `<domain>_<function>.ex` (e.g., `cursor_manager.ex`, `buffer_server.ex`)
- Avoid generic names: `manager.ex`, `handler.ex`, `server.ex`
- Effects use full module paths: `Raxol.Effects.CursorTrail` not bare `CursorTrail`

### Consolidated Namespaces

These namespaces have been consolidated -- avoid creating new top-level alternatives:

- `Raxol.Terminal.Commands.*` - All command processing, in raxol_terminal package
- `Raxol.Terminal.Rendering.*` - All terminal rendering, in raxol_terminal package
- `Raxol.Performance.*` - All performance tools (not `core/performance/`)
- `Raxol.LiveView.*` - LiveView integration (not `liveview/`)
- `Raxol.Debug.*` - Debugging tools (time-travel, snapshots)
- `Raxol.Recording.*` - Session recording/replay (not `session/`)
- `Raxol.Swarm.*` - Distributed swarm (CRDTs, discovery, topology)
- `Raxol.Swarm.Strategy.*` - Custom libcluster strategies (Tailscale)
- `Raxol.UI.TextMeasure` - Single facade for display width measurement (not `String.length`)
- `Raxol.UI.Layout.ScrollContent` - Cursor-based lazy scroll behaviour + adapters

## Environment Variables

**Set automatically** (via `.claude/settings.json`):

- `SKIP_TERMBOX2_TESTS=true` - Skip Docker/termbox2-dependent tests
- `TMPDIR=/tmp` - Temporary directory for test artifacts

**Optional**:

- `CI=true` - Triggers CI-specific config
- `RAXOL_SKIP_TERMINAL_INIT=true` - Skip terminal init in certain contexts

## Dialyzer

- PLT cached in `priv/plts/` for faster reruns
- `.dialyzer_ignore.exs` contains ~39 documented intentional suppressions (15 patterns)
- Mix aliases: `mix dialyzer.setup`, `mix dialyzer.check`, `mix dialyzer.clean`

## Deployment

**Production**: Fly.io at `https://raxol.io`

```bash
flyctl deploy              # Deploy
flyctl status --app raxol  # Status
flyctl logs --app raxol    # Logs
```

Configuration: `fly.toml`, Dockerfile: `docker/Dockerfile.web`

## Project Notes

- Themes stored in `priv/themes/` as JSON
- Domain: raxol.io (made by axol.io)
- Plugin docs: `docs/plugins/GUIDE.md`
- `AGENTS.md` contains the improvement roadmap, competitive analysis, and implementation plan
- HEEx terminal compilation (`compile_heex_for_terminal`) is experimental/naive

<!-- usage-rules-start -->
<!-- usage_rules-start -->

## usage_rules usage

_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before taking any
action. These usage rules contain guidelines and rules _directly from the package authors_.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
