---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2025-05-08
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

Architecture, its components, and their relationships.
For subsystem details, see the referenced README files.

## System Overview

- **Layered architecture** with clear separation of concerns.
- Main layers:

```bash
┌───────────────┐
│ Application   │
├───────────────┤
│ View          │
├───────────────┤
│ Components    │
├───────────────┤
│ Runtime/Render│
├───────────────┤
│ Terminal      │
└───────────────┘
```

- Each layer is implemented as a subsystem (see below).

## Core Subsystems

### Terminal

- Specialized managers: Buffer, Cursor, State, Command, Style, Parser, Input.
- **Purpose:** Terminal I/O, state, and rendering.
- **Details:** See `lib/raxol/terminal/README.md` <!-- TODO: Link removed for pre-commit compatibility -->

### Runtime

- Coordinates app lifecycle, events, and state.
- Key modules: Application, Lifecycle, Events, Plugins.
- **Details:** See `lib/raxol/core/README.md` <!-- TODO: Link removed for pre-commit compatibility -->

### Plugins

- Modular/extensible via behaviors (Dependency, Command, State, Timer, Event, etc.).
- Uses Tarjan's algorithm for dependency resolution.
- **Details:** See `lib/raxol/plugins/README.md` <!-- TODO: Link removed for pre-commit compatibility -->

### Color System

- Centralized color/theme management.
- Modules: Color, ColorSystem, Theming, Utilities.
- **Details:** See `lib/raxol/style/README.md` <!-- TODO: Link removed for pre-commit compatibility -->

### Components & View

- All components implement a common behaviour (`Base.Component`).
- Lifecycle: `init`, `mount`, `update`, `render`, `handle_event`, `unmount`.
- Composed via `View.Elements` DSL.
- **Details:** See `lib/raxol/ui/README.md` <!-- TODO: Link removed for pre-commit compatibility -->

## Test & Performance Infrastructure

### Testing Principles

- **Event-based synchronization** for all async operations (no `Process.sleep`).
- **Custom assertion helpers** and event tracking for plugin/component lifecycle.
- **Systematic use of Mox** for mocking system/external dependencies.
- **Test isolation** via unique state tracking and `on_exit` cleanup.
- **Tests mirror source structure**; helpers/fixtures in `test/support/`.
- **Plugin tests**: Enhanced fixtures, metadata validation, resource cleanup.
- **Best practices:**
  - Use `assert_receive` for async
  - Clean up with `on_exit`
  - Use adapter pattern for system calls
  - Document test setup/requirements
  - Ensure isolation and meaningful errors
- **Status:**
  - All new code requires comprehensive test coverage
  - Event-based sync is mandatory for async tests
  - See subsystem and support docs for details

### Performance Testing

- **PerformanceHelper**: Utilities for setup, benchmarking, metrics, assertions.
- **Performance requirements:**
  - Event processing: < 1ms avg, < 2ms 95th percentile
  - Screen updates: < 2ms avg, < 5ms 95th percentile
  - Concurrent ops: < 5ms avg, < 10ms 95th percentile
- **Run via:**

```bash
  mix test test/raxol/terminal/manager_performance_test.exs
```

- **Metrics logged** for regression tracking.
- **References:** See `test/support/` and subsystem READMEs for details.

## Directory Structure (Key)

- `lib/raxol/core/` — Core runtime, events, plugins, rendering
- `lib/raxol/terminal/` — Terminal I/O, buffer, parser, commands
- `lib/raxol/ui/` — UI components, layout, theming, renderer
- `lib/raxol/style/` — Styling and color system
- `lib/raxol/plugins/` — Application-level plugins
- `test/` — Mirrors source, helpers in `test/support/`
- See each directory's README for details

## Core Subsystems & Status

- **Runtime:** App lifecycle, event dispatch, plugin management, rendering.
  _Core implemented._
- **Plugins:** Discovery, loading, lifecycle, event/command dispatch, reloading.
  _Modular, extensible, all behaviors complete._
- **Event Handling:** Terminal events → dispatcher → app/plugins.
  _Event-based sync standard; reliable._
- **Rendering:** Engine/layout/renderer/terminal output.
  _Functional, tested._
- **Components:** Reusable, stateful, lifecycle hooks, view macros.
  _Base defined, ongoing enhancements._
- **Theming:** Styles/themes integrated in renderer.
  _Robust, functional._

## Event & Rendering Pipeline

**Event and Rendering Flow:**

```bash
[Terminal Input/Event]
        ↓
[Terminal Driver] → [Event Struct]
        ↓
[Event Dispatcher]
        ↓
[Application.handle_event]
        ↓
[State Update]
        ↓
[View Render]
        ↓
[Terminal Buffer]
        ↓
[Terminal Output]
```

**Stepwise Flow:**

1. Terminal events captured by Terminal Driver (`:rrex_termbox` NIF).
2. Events translated to standard structs and dispatched.
3. Application's `handle_event` processes events, updates state.
4. View is re-rendered based on new state.
5. Terminal buffer is updated and flushed to output.

**References:**

- See subsystem READMEs for details on event handling, rendering, and buffer management.

## Status & Roadmap

- See `CHANGELOG.md` and project roadmap for current status, ongoing work, and next steps.
- Active focus: test stabilization, performance, documentation, and code quality.
- All new code requires comprehensive test coverage and event-based sync for async.

## Design Principles

- **Elm-style update/view separation**
- **NIF terminal I/O** (`rrex_termbox`)
- **Reusable, stateful components**
- **Modular, extensible plugins**
- **Adapter pattern for system/test**
- **Event-based async testing**
- **Comprehensive, isolated test infra**
- **Centralized, accessible color system**

_For details, see subsystem READMEs and the changelog._

## References

- Subsystem details: see respective README.md files
- API and guides: see `docs/components/api/`, `docs/guides/`
- Changelog and roadmap: see `CHANGELOG.md`, project management docs

## Current Status (2025-05-10)

- **Test Suite:** 49 doctests, 1528 tests, 279 failures, 17 invalid, 21 skipped
- **Terminal subsystem refactoring complete** (specialized managers, improved test coverage)
- **Plugin system modularization complete** (all behaviors implemented, Tarjan's algorithm for dependencies)
- **Color system refactoring complete** (centralized, accessible, robust)
- **Performance and event-based test infrastructure in place**
- **Ongoing:**
  - Addressing remaining test failures (focus: core/terminal, plugin, component, color, integration/performance)
  - Performance test stabilization
  - Documentation and code quality improvements

## Next Steps

1. Address remaining test failures and invalid/skipped tests
2. Complete OSC 4 handler implementation
3. Implement robust anchor checking in pre-commit script
4. Document test writing guide and update API documentation
5. Continue code quality and documentation improvements (refactor large files, improve error handling, extract utilities)

## Notes

- The codebase is now highly modular, with clear separation of concerns
- Test and performance infrastructure is a first-class concern
- Ongoing work focuses on test stabilization, performance, and documentation
- See the project roadmap and changelog for detailed progress and upcoming work

## Key Design Decisions

1. **Application Model**: Inspired by The Elm Architecture, with clear update/view separation.
2. **NIF-based Terminal Interface**: Uses rrex_termbox NIF for improved performance.
3. **Component System**: Reusable, stateful components with lifecycle hooks.
4. **Plugins**: Extensible through a plugin system.
5. **System Interaction Adapters**: For modules with direct operating system or external service interactions (e.g., file system, HTTP calls, system commands), an adapter pattern (a behaviour defining the interaction contract and an implementation module) is used. This allows for mocking these interactions in tests, improving test reliability and isolation. Examples include `Raxol.System.DeltaUpdater` with its `DeltaUpdaterSystemAdapterBehaviour`, and `Raxol.Terminal.Config.Capabilities` with its `EnvironmentAdapterBehaviour`.
6. **Event-Based Testing**: All asynchronous operations are tested using event-based synchronization, replacing arbitrary `Process.sleep` calls with deterministic event assertions. This improves test reliability and makes test failures more meaningful.
7. **Test Infrastructure**: Comprehensive test infrastructure with:
   - Event-based synchronization for async operations
   - Unique state tracking for test plugins
   - Proper resource cleanup in `on_exit` callbacks
   - Consistent use of Ecto Sandbox for database tests
   - Systematic use of Mox for mocking
   - Clear test organization and documentation
   - Performance testing with defined requirements
8. **Performance Requirements**: Strict performance requirements enforced through automated testing:
   - Event processing: < 1ms average, < 2ms 95th percentile
   - Screen updates: < 2ms average, < 5ms 95th percentile
   - Concurrent operations: < 5ms average, < 10ms 95th percentile
9. **Color System Architecture**: The color system is organized into specialized modules:
   - `Raxol.Style.Colors.Color`: Core color representation and manipulation
   - `Raxol.Core.ColorSystem`: Centralized theme and color management
   - `Raxol.UI.Theming.Colors`: UI-specific color operations
   - `Raxol.Style.Colors.Utilities`: Shared color utilities and accessibility
     This modular design provides clear separation of concerns, reduces code duplication, and improves maintainability.
