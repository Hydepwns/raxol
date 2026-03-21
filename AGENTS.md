# AGENTS.md -- Raxol Improvement Plan

## Mission

Make raxol the best terminal UI framework in any language. The Elixir/OTP ecosystem has no mature TUI framework -- raxol fills that gap.

## Current State (March 2026)

### What Works

- Terminal emulation (VT100/ANSI parsing, screen buffers, character sets) -- solid, well-tested
- Buffer primitives -- pure-functional create/write/read/resize/clear/to_string
- LiveView bridge -- buffer-to-HTML with caching, dirty checking, themes
- Tree diffing -- keyed and non-keyed child handling
- Layout engines -- flexbox (1028 lines) and CSS grid (1092 lines) with real algorithms
- Test suite -- ~4756 tests, 0 failures, property-based tests, broad coverage (4715 last verified)
- Plugin system -- real architecture with lifecycle, dependency resolution, events (40+ modules)
- Counter example -- runs end-to-end (`mix run examples/getting_started/counter.exs`)
- `Raxol.start_link/2` -- defined, delegates to `Raxol.Core.Runtime.Lifecycle.start_link/2`
- Render pipeline -- `lib/raxol/ui/rendering/pipeline.ex` (834 lines) is a working GenServer; most stages implemented, only stage 5 (render/paint) has stubs
- 9 real widgets (TextInput, TextArea, Table, Button, Modal, SelectList, Checkbox, ProgressBar, MultiLineInput), 2 partial (CodeBlock, MarkdownRenderer), 1 stub (Terminal)
- All widgets render consistent `%{type: ..., content/children: ..., style: ...}` maps (normalized in Track A Step 4)
- MultiLineInput has undo/redo (snapshot-based, 100-entry cap) and desired_col vertical navigation

### What's Broken

- **HEEx terminal compilation is naive** -- `lib/raxol/heex/components.ex` has 455 lines of real Phoenix Component implementations, but `compile_heex_for_terminal` is still naive string replacement
- **Scope creep** -- CQRS and EventSourcing remain entangled with core terminal code; Spotify, SSH, WASM, encryption, and audit modules have been removed
- **Version mismatch** -- FIXED: `version/0` now returns "2.1.0" matching mix.exs

### Track A: Widget Audit & Hardening (Completed Steps)

Steps 1-3 completed in prior session. Step 4 completed in current session:

- **Step 4.1**: Fixed CodeBlock render/2 -- replaced nonexistent Makeup modules with actual API (`Makeup.highlight_inner_html/2`), added HTML tag stripping for TUI
- **Step 4.2**: Implemented MultiLineInput undo/redo -- snapshot-based history stack (`{value, cursor_pos}`), pushed before mutations, redo cleared on new edits, 100-entry cap
- **Step 4.3**: Fixed EventHandler/MessageRouter message mismatch -- EventHandler now emits tuples matching router expectations (e.g., `{:select_all}` not `:select_all`, `{:selection_move, dir}` not `{:select_and_move, dir}`)
- **Step 4.4**: Normalized render return types across all widgets -- standardized to `%{type: ..., content/children: ..., style: ...}` flat maps compatible with TreeDiffer. Affected: Terminal, TextInput, TextField, Checkbox, SelectList renderer, Progress. Updated 7 test files.
- **Step 4.5**: Fixed desired_col persistence in NavigationHelper -- vertical movements preserve intended column across short lines, horizontal movements clear it. Added 10 tests.

### Codebase Stats

- `lib/raxol/` -- ~276K lines across terminal/, ui/, core/, performance/, live_view/, effects/
- `test/` -- 325 test files, ~4756 passing tests
- Key entry points: `lib/raxol.ex`, `lib/raxol/core/runtime/application.ex`
- NIF: `lib/termbox2_nif/c_src/` (termbox2 git submodule, requires `git submodule update --init --recursive`)

## Competitive Landscape

| Framework  | Lang       | Stars   | Layout                  | Widgets      | Architecture      |
| ---------- | ---------- | ------- | ----------------------- | ------------ | ----------------- |
| Bubble Tea | Go         | 39k     | String concat           | 14           | Elm MVU           |
| Ink        | JS         | 35.6k   | Flexbox (Yoga)          | 6+UI lib     | React             |
| Textual    | Python     | 26k     | CSS Grid+Flex           | 31+          | Retained DOM      |
| Ratatui    | Rust       | 19k     | Constraint              | 15           | Immediate mode    |
| **Raxol**  | **Elixir** | **<1k** | **Flex+Grid (partial)** | **9 real + 3 partial/stub** | **TEA (partial)** |

### Why Raxol Can Win

- **No Elixir TUI framework exists** -- Ratatouille is stalled on termbox1, Owl is CLI-only
- **OTP maps perfectly to TUI architecture** -- GenServer = Elm MVU, processes = components, supervision = crash recovery, hot reload = live dev
- **LiveView bridge is unique** -- same app in terminal AND browser, no other framework does this natively
- **Erlang `:ssh` built-in** -- SSH app serving without external deps (Garnish proved this)

### Ratatui's Weaknesses (Exploit These)

- No built-in app architecture -- devs must design event loops, state management from scratch
- No focus management, no event bubbling
- Cassowary layout engine is aging (unmaintained since 2018)
- Steep Rust learning curve limits adoption

### Bubble Tea's Weaknesses (Exploit These)

- String-based rendering -- `View()` returns a string, layouts break at scale
- Component composition is painful -- state duplication, message routing boilerplate
- Components don't implement the Model interface, can't be nested generically
- Manual dimension management for every nested component

## Implementation Plan

### Phase 1: Make It Work (Priority: CRITICAL)

The single most important thing is that someone can `mix run examples/counter.exs` and interact with a working TUI. Nothing else matters until this works.

#### 1.1 Fix the Application Entry Point -- DONE

- TEA (init/update/view) is the canonical app model, mapping to GenServer
- `Raxol.start_link/2` exists at `lib/raxol.ex:194-196`, delegates to `Raxol.Core.Runtime.Lifecycle.start_link/2`
- Counter example runs end-to-end (fixed in commit 5272332b)
- Files: `lib/raxol.ex`, `lib/raxol/core/runtime/application.ex`, `lib/raxol/core/runtime/lifecycle.ex`

#### 1.2 Make 3 Examples Run End-to-End -- IN PROGRESS

- **Counter** (`examples/getting_started/counter.exs`) -- DONE, runs end-to-end
- **Todo List** (`examples/getting_started/todo_app.exs`) -- DONE, runs end-to-end
- **Showcase** (`examples/apps/showcase_app.exs`) -- DONE, rewritten from LiveView to TEA pattern with 5 sections demonstrating View DSL components
- **File Browser** -- not yet attempted
- Each must: start from `mix run`, handle keyboard input, render to terminal, exit cleanly with `q` or `Ctrl+C`

#### 1.3 Wire the Layout Engine -- PARTIALLY DONE

- Flexbox engine exists at `lib/raxol/ui/layout/flexbox.ex`
- The render pipeline at `lib/raxol/ui/rendering/pipeline.ex` (834 lines) is a working GenServer with most stages implemented; only stage 5 (render/paint) has stubs
- Remaining: fully connect element tree -> flexbox layout -> positioned cells -> buffer write -> terminal output

#### 1.4 Wire the View DSL

- `lib/raxol/view/elements.ex` generates element maps (row, column, box, text, etc.)
- These must flow into the layout engine and produce buffer writes
- Start with: `box`, `text`, `row`, `column` -- enough for the 3 examples

#### 1.5 Clean Up -- MOSTLY DONE

- DONE: Deleted scope creep modules: Spotify plugin, SSH client/session/server, encryption, audit (16 files), WASM builder + mix task
- NOT DELETED: CQRS and EventSourcing -- too entangled with `terminal_handlers.ex`, `terminal_commands.ex`, `terminal_supervisor.ex`, `terminal_registry.ex` (would require core rewrite)
- DONE: Fixed `version/0` in `lib/raxol.ex` to return "2.1.0" matching mix.exs
- DONE: Removed `Raxol.Toast` calls from examples (module doesn't exist)
- DONE: Marked HEEx terminal compilation as experimental in moduledoc
- DONE: todo_app.exs rewritten to TEA and runs end-to-end
- DONE: showcase_app.ex rewritten to TEA pattern (no more `Screen`/`Stack`/LiveView references)

### Phase 2: Widget Library (Priority: HIGH)

Build 15 production-quality widgets. Each widget must have: implementation, tests, and a runnable example.

#### Must-Have Widgets (match Ratatui + Bubble Tea baseline)

1. **Text** -- styled text rendering with wrapping, alignment, truncation
2. **TextInput** -- single-line input with cursor, selection, validation -- EXISTS
3. **TextArea** -- multi-line input with scrolling -- EXISTS
4. **List/SelectList** -- scrollable list with selection, search/filter, pagination -- EXISTS
5. **Table** -- sortable columns, scrolling, selection (503 lines) -- EXISTS
6. **Tabs** -- tab bar with content switching
7. **ProgressBar** -- linear, circular, spinner variants -- EXISTS
8. **Viewport/Scrollable** -- scroll any content that exceeds bounds
9. **Tree** -- expandable/collapsible tree (file browser pattern)
10. **Button** -- clickable with focus states (447 lines) -- EXISTS

#### Should-Have Widgets (match Textual's breadth)

11. **Modal/Dialog** -- overlay with confirm/cancel (310+ lines) -- EXISTS
12. **Select/Dropdown** -- pick from options (with pagination/search submodules) -- EXISTS
13. **Checkbox** -- toggle with label -- EXISTS
14. **Menu** -- nested menu with keyboard navigation
15. **StatusBar/Footer** -- bottom bar with key hints

#### Additional Widgets (beyond original plan)

- **MultiLineInput** -- exists as separate widget from TextArea
- **CodeBlock** -- syntax-highlighted code display
- **MarkdownRenderer** -- terminal markdown rendering

#### Widget Architecture

- Each widget is a module implementing a behaviour: `init/1`, `update/2`, `render/2` (state, context)
- `render/2` returns flat maps: `%{type: atom, content: string, style: map, children: list}` -- compatible with TreeDiffer
- Use `Raxol.View.Components.text(content: ...)` to build text elements (returns `%{type: :text, content: ..., style: %{}, id: nil}`)
- Do NOT use `Raxol.Core.Renderer.Element.new` (returns `%Element{tag:, attributes:, children:}` which is incompatible with TreeDiffer)
- Widgets receive focused/unfocused events
- Widgets declare their minimum/preferred size for the layout engine
- Widgets are composable -- a Modal contains other widgets, a List contains Text items

### Phase 3: Framework Polish (Priority: HIGH)

#### 3.1 Focus Management

- Tab order (automatic from tree position, overridable)
- Focus rings (visual indicator of focused widget)
- `Tab`/`Shift+Tab` navigation
- `useFocus` / `focus_next` / `focus_prev` API
- No framework in the Elixir ecosystem has this

#### 3.2 Event System

- Keyboard events: key press, key release, modifiers
- Mouse events: click, scroll, drag (termbox2 supports this)
- Resize events
- Event bubbling: events propagate up the component tree until handled
- Event capture: parent can intercept before children

#### 3.3 Styling System

- Declarative style maps: `%{fg: :green, bold: true, padding: 1}`
- Theme support: named themes with color palettes
- Style inheritance: children inherit parent styles unless overridden
- Focus/active/disabled pseudo-states

#### 3.4 Terminal Compatibility

- Color downsampling: truecolor -> 256 -> 16 -> monochrome (detect terminal capability)
- Unicode width detection: handle CJK double-width, emoji
- Mode 2026 synchronized output for flicker-free rendering
- Graceful degradation on limited terminals

### Phase 4: OTP Differentiators (Priority: MEDIUM)

These are what make raxol impossible to replicate in Rust/Go/Python.

#### 4.1 Process-Per-Component (Optional)

- Heavy widgets (e.g., file browser doing I/O) can run as separate processes
- Crash in one component doesn't take down the app (supervision)
- Natural back-pressure via GenServer mailboxes
- NOT required for simple widgets -- this is opt-in for complex cases

#### 4.2 Hot Code Reload

- Change a widget module, see it update in the running TUI
- Elixir's code reloading + the TEA model (pure render from state) makes this trivial
- No other TUI framework can do this
- Game-changer for development speed

#### 4.3 LiveView Bridge (Terminal + Browser)

- Same app logic renders to terminal via buffer OR to browser via LiveView
- The bridge already exists and works (`lib/raxol/live_view/`)
- Need to unify the component model so widgets work in both targets
- Unique selling point: deploy to SSH AND web from one codebase

#### 4.4 SSH App Serving

- Erlang `:ssh` module is built-in, battle-tested
- Garnish (github.com/ausimian/garnish) proved this works for Elixir TUIs
- Serve TUI apps over SSH with zero client requirements
- Combined with LiveView bridge: one app -> terminal + browser + SSH

### Phase 5: Ecosystem (Priority: LOW -- after core is solid)

- Package as hex package that actually installs and works
- Generator: `mix raxol.new my_app` scaffolds a working project
- Documentation site with widget gallery, tutorials, examples
- VS Code extension for component previews
- Benchmark suite comparing against Ratatui/Bubble Tea/Textual

## Research Methodology

When investigating improvements, use parallel search agents for:

1. **Ratatui source** -- study their widget implementations, layout engine, buffer diffing
   - Repo: github.com/ratatui/ratatui (Rust)
   - Focus: `src/widgets/`, `src/layout/`, `src/buffer/`

2. **Bubble Tea source** -- study their Elm Architecture runtime, component model
   - Repo: github.com/charmbracelet/bubbletea (Go)
   - Focus: `tea.go` (runtime), Bubbles repo for widgets

3. **Textual source** -- study their CSS layout engine, widget library, DOM model
   - Repo: github.com/Textualize/textual (Python)
   - Focus: `src/textual/widgets/`, `src/textual/css/`, `src/textual/_layout.py`

4. **Ink source** -- study their React-to-terminal renderer, Yoga layout integration
   - Repo: github.com/vadimdemedes/ink (TypeScript)
   - Focus: `src/render.ts`, `src/dom.ts`, Ink UI for widgets

5. **Ratatouille source** -- study the only existing Elixir TUI framework
   - Repo: github.com/ndreynolds/ratatouille (Elixir)
   - Focus: `lib/ratatouille/runtime.ex`, `lib/ratatouille/view.ex`

When implementing a widget or feature, search at least 2 competing implementations first to understand the design space, then adapt to idiomatic Elixir/OTP patterns.

## Rules

- Every feature must have tests before it ships
- Every widget must have a runnable example in `examples/`
- No empty modules or stubs checked in -- if it doesn't work, don't ship it
- No marketing claims in docs/moduledocs about unimplemented features
- TEA (init/update/view) is the canonical app model -- do not add competing models
- Cut scope aggressively -- a working counter app beats 100 stub modules
- Prefer pure functions over GenServers unless concurrency is genuinely needed
- Follow existing code conventions in CLAUDE.md
