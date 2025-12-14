# Raxol Roadmap

This document outlines planned features and enhancements for Raxol.

## Current Version: v2.0.1

### Released Features
- Multi-framework UI support (React, LiveView, HEEx, Raw)
- VT100/ANSI terminal emulation
- Cross-platform support (macOS, Linux, Windows)
- VIM navigation patterns
- Command parser with tab completion
- Fuzzy search functionality
- Virtual filesystem
- Cursor effects and animations
- Modular package architecture

## v2.0.2 - Quality & Simplicity Sprint (Q1 2025)

**Goal**: Address expert feedback to improve CLI UX, reduce accidental complexity, and embrace purely functional patterns idiomatic to Elixir.

**Expert Panel**: Mitchell Hashimoto, TJ Holowaychuk, Rich Hickey, Charity Majors, Chris McCord

---

### Sprint 1: CLI Polish (Mitchell + TJ)

**Focus**: Immediate user-facing improvements with minimal effort

| Task | File | Description |
|------|------|-------------|
| Fuzzy command matching | `lib/mix/tasks/raxol.ex` | Use Jaro distance to suggest corrections for typos (`chek` -> `check`) |
| Consistent severity labels | `lib/mix/tasks/raxol.check.ex` | Align `[FAIL]`/`[WARN]` display with actual status codes |
| CLI color palette | `lib/raxol/cli/colors.ex` | NEW - Centralized ANSI color definitions for consistent styling |
| Document all options | Multiple mix tasks | Add all `@switches` to `@moduledoc` help text |
| Test failure details | `lib/mix/tasks/raxol.test.ex` | Show failure count, suggest `--failed` flag |

**Success Criteria**:
- Zero unknown commands without suggestions
- All failures have actionable next steps
- Consistent visual language across CLI output

---

### Sprint 2: Simplify State (Rich Hickey)

**Focus**: Remove accidental complexity by converting GenServers to pure functions

**Problem**: 27% of core modules (49/180) are GenServers. Most don't need to be.

| Task | Current | Target | Rationale |
|------|---------|--------|-----------|
| ConfigServer | 410-line GenServer | Pure functions + ETS | Map lookups don't need mailbox serialization |
| Extract Debounce | Reimplemented 3x | `lib/raxol/core/utils/debounce.ex` | One reusable module for timer management |
| Split PluginManager | 17 state fields | Registry (pure) + Lifecycle (GenServer) | Separate concerns: lookup vs coordination |
| MetricsCollector | GenServer state | ETS tables | Write-heavy workloads need ETS, not serialization |

**Architecture After Refactoring**:
```
Pure Data Layer (no processes)
+-- Config (maps)
+-- Catalog (lists)
+-- Preview (rendering)
+-- CodeGenerator (strings)
+-- PluginRegistry (lookups)

Coordination Layer (necessary GenServers)
+-- ComponentManager (concurrent updates)
+-- PluginLifecycle (enable/disable)
+-- Playground REPL (session state)

Performance Layer (ETS-backed)
+-- MetricsCollector
+-- FocusState
+-- AccessibilityState
```

**Success Criteria**:
- < 15% of core modules are GenServers
- Zero pure data operations wrapped in processes
- All timer management uses shared Debounce module

---

### Sprint 3: Observability (Charity Majors)

**Focus**: Enable production debugging with request correlation

| Task | Description |
|------|-------------|
| Add trace_id | Generate unique ID per request, propagate through telemetry events |
| Wire up error_experience | Connect `lib/raxol/core/error_experience.ex` suggestions to terminal output |
| Implement real metrics | Replace MetricsServer stub with actual storage (ETS + periodic flush) |
| Debugging guide | Document production debugging workflow in `docs/debugging.md` |

**Telemetry Enhancement**:
```elixir
# Before: Events exist but aren't correlated
:telemetry.execute([:raxol, :terminal, :render], %{duration: 1234}, %{})

# After: trace_id links all events in a request
:telemetry.execute([:raxol, :terminal, :render], %{duration: 1234}, %{
  trace_id: "abc123",
  span_id: "def456",
  parent_span_id: "ghi789"
})
```

**Success Criteria**:
- Any request can be traced end-to-end
- Error reports include enough context to debug
- Metrics exportable to Prometheus

---

### Sprint 4: Framework Integration (Chris McCord)

**Focus**: Tighter LiveView integration and unified theming

| Task | Description |
|------|-------------|
| Unify theme sources | Single source of truth for `Raxol.LiveView.Themes` and terminal themes |
| LiveView streams | Use streams for component catalog (infinite scroll, better perf) |
| Document driver fallback | Explain termbox2_nif -> IOTerminal fallback in docs |
| Component framework sharing | Explore `use Raxol.Component, frameworks: [:terminal, :liveview]` |

**Theme Unification**:
```elixir
# Single theme definition used everywhere
defmodule Raxol.Themes do
  @themes %{
    dracula: %{fg: "#f8f8f2", bg: "#282a36", ...},
    nord: %{fg: "#eceff4", bg: "#2e3440", ...},
    # ... 10 themes
  }

  def get(name), do: Map.get(@themes, name)
  def list, do: Map.keys(@themes)

  # Adapters for different contexts
  def to_tailwind(theme), do: ...
  def to_ansi(theme), do: ...
end
```

**Success Criteria**:
- Single source of truth for themes
- Terminal and LiveView can share component definitions

---

## Upcoming Features

### v2.1.0 - Svelte Framework Support (Q1 2026)

**Goal**: Add Svelte-style reactive component patterns with compile-time optimization

**Features**:
- `use Raxol.UI, framework: :svelte` support
- Reactive state management with `state(:name, value)` macro
- Computed properties via `reactive :name do ... end`
- Two-way data binding
- Component lifecycle hooks (onMount, onDestroy, beforeUpdate, afterUpdate)
- Store pattern with derived values
- Compile-time optimizations for reactive dependencies

**Implementation**:
- `Raxol.Svelte.Component` module
- `Raxol.Svelte.Store` for reactive stores
- `Raxol.Svelte.Reactive` for reactive statements
- Component compiler to track dependencies
- Runtime for efficient updates

**Example**:
```elixir
defmodule MyCounter do
  use Raxol.UI, framework: :svelte

  state(:count, 0)
  state(:step, 1)

  reactive :doubled do
    @count * 2
  end

  def render(assigns) do
    ~H"""
    <Box>
      <Text>Count: {@count}</Text>
      <Text>Doubled: {@doubled}</Text>
      <Button on_click={increment}>+</Button>
    </Box>
    """
  end
end
```

### v2.2.0 - Enhanced Graphics (Q2 2026)

**Goal**: WebGL-style rendering capabilities in terminal

**Features**:
- Hardware-accelerated rendering via GPU
- Canvas API for custom graphics
- SVG-to-terminal conversion
- Image manipulation and filters
- Animation interpolation engine
- Particle effects system

**Use Cases**:
- Data visualizations and charts
- Terminal games with rich graphics
- Live dashboards with animations
- Interactive diagrams

### v2.3.0 - Multi-session Collaboration (Q3 2026)

**Goal**: Real-time shared terminal sessions

**Features**:
- CRDT-based state synchronization
- WebRTC peer-to-peer connections
- Session sharing and permissions
- Collaborative cursors
- User presence indicators
- Chat integration
- Session recording and playback

**Use Cases**:
- Pair programming in terminal
- Shared debugging sessions
- Remote system administration
- Live demonstrations

### v2.4.0 - Plugin Marketplace (Q4 2026)

**Goal**: Community-driven plugin ecosystem

**Features**:
- Plugin registry and discovery
- Version management
- Dependency resolution
- Plugin sandboxing and security
- Theme marketplace
- Component library sharing
- Plugin development toolkit

**Components**:
- Web interface for browsing plugins
- CLI tools for plugin management
- Plugin testing framework
- Documentation generator

### v3.0.0 - Mobile Terminal (Q1 2027)

**Goal**: iOS and Android terminal clients

**Features**:
- Native mobile apps
- Touch-optimized UI
- Mobile keyboard integration
- Cloud session sync
- Offline mode support
- Mobile-specific gestures
- Cross-device session handoff

**Platforms**:
- iOS (SwiftUI)
- Android (Compose)
- React Native (shared UI)

## Research & Exploration

### Under Consideration

- **AI Integration**: Natural language terminal commands, code suggestions
- **WebAssembly**: Browser-based terminal emulation
- **Voice Control**: Speech-to-command conversion
- **AR/VR**: Terminal in 3D space
- **Blockchain**: Decentralized session storage
- **Quantum**: Terminal for quantum computing interfaces

### Community Requests

Submit feature requests via [GitHub Issues](https://github.com/Hydepwns/raxol/issues) with the \`enhancement\` label.

## Contributing

Want to help implement these features? See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Version Naming

- **Minor versions** (2.x.0): New frameworks, major features
- **Patch versions** (2.0.x): Bug fixes, performance improvements
- **Major versions** (3.0.0): Breaking API changes, architectural shifts

## Timeline

This roadmap is aspirational. Actual release dates may vary based on:
- Community contributions
- Prioritization changes
- Technical challenges
- Resource availability
