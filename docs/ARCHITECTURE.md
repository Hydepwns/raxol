---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2025-05-08
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

This document provides an up-to-date overview of the Raxol architecture, its components, and how they interact, reflecting the latest refactoring.

## System Overview

Raxol is designed as a layered architecture with several key subsystems:

```text
┌────────────────────────────────────────┐
│              Application               │
├────────────────────────────────────────┤
│                 View                   │
├────────────────────────────────────────┤
│              Components                │
├────────────────────────────────────────┤
│         Runtime & Rendering            │
├────────────────────────────────────────┤
│              Terminal                  │
└────────────────────────────────────────┘
```

## Core Subsystems

### Terminal Subsystem (Refactored)

The Terminal subsystem has been fully refactored into specialized manager modules for clarity, maintainability, and testability:

- `Raxol.Terminal.Buffer.Manager`: Manages screen buffer operations and content
- `Raxol.Terminal.Cursor.Manager`: Handles cursor state and movement
- `Raxol.Terminal.State.Manager`: Manages terminal state and configuration
- `Raxol.Terminal.Command.Manager`: Handles command processing and execution
- `Raxol.Terminal.Style.Manager`: Manages text styling and formatting
- `Raxol.Terminal.Parser.State.Manager`: Handles parser state transitions
- `Raxol.Terminal.Input.Manager`: Processes keyboard and mouse input

This modularization has improved code organization, test coverage, and error handling.

### Runtime System

The Runtime system coordinates the application lifecycle, events, and state management. Key modules:

- `Raxol.Core.Runtime.Application`: Behaviour for Raxol applications
- `Raxol.Core.Runtime.Lifecycle`: Manages application startup and shutdown
- `Raxol.Core.Runtime.Events`: Handles event dispatching and subscriptions
- `Raxol.Core.Runtime.Plugins`: Provides plugin infrastructure

### Plugin System (Modular Behaviours & Dependency Management)

The plugin system is now fully modular and extensible, with all core behaviors implemented and documented:

- **Behaviours:**
  - `DependencyManager.Behaviour`: Plugin dependency management (now uses Tarjan's algorithm for cycle detection and topological sorting)
  - `CommandHelper.Behaviour`: Plugin command management
  - `PluginMetadataProvider.Behaviour`: Plugin metadata handling
  - `PluginReloader.Behaviour`: Plugin reloading functionality
  - `StateManager.Behaviour`: Plugin state management
  - `TimerManager.Behaviour`: Plugin timer management
  - `PluginEventFilter.Behaviour`: Plugin event filtering
  - `PluginCommandHandler.Behaviour`: Plugin command handling
  - `PluginCommandDispatcher.Behaviour`: Plugin command dispatching
  - `PluginCommandRegistry.Behaviour`: Plugin command registration
  - `PluginCommandHelper.Behaviour`: Plugin command registration and dispatch
- **Dependency Resolution:**
  - Enhanced version constraint handling (e.g., ">= 1.0.0 || >= 2.0.0")
  - Tarjan's algorithm for efficient cycle detection and load order
  - Implementation now guarantees only true cycles are flagged (not just any strongly connected component), load order is unique (no duplicate plugin IDs), and detailed error chains are reported for self-loops and mutual dependencies.
  - Optional dependencies with version mismatches are now ignored, allowing plugins to load even if optional dependencies do not meet version requirements.
  - Detailed error reporting for dependency issues
- **Reloading:**
  - Manual and automatic (dev) plugin reloading supported
- **Testing:**
  - Unique state tracking for test plugins
  - Event-based synchronization for async plugin operations

### Color System (Centralized & Accessible)

The color system is now organized into specialized modules for maintainability and accessibility:

- `Raxol.Style.Colors.Color`: Core color representation and manipulation
- `Raxol.Core.ColorSystem`: Centralized theme and color management
- `Raxol.UI.Theming.Colors`: UI-specific color operations
- `Raxol.Style.Colors.Utilities`: Shared color utilities and accessibility

This modular design provides clear separation of concerns, reduces code duplication, and improves accessibility (contrast, theming, high-contrast mode).

### Component & View System

Raxol's component system is central to its UI architecture.

- **Behaviour:** All components implement `Raxol.UI.Components.Base.Component`, defining the following callbacks:
  - `init/1` — Initialize state from props
  - `mount/1` — Set up resources after mounting
  - `update/2` — Update state in response to messages
  - `render/1` — Produce the component's view
  - `handle_event/2` — Handle user/system events
  - `unmount/1` — Clean up resources
- **Composition:** Components are composed using the `Raxol.View.Elements` DSL, supporting hierarchical parent-child relationships and explicit event propagation.
- **Lifecycle:** The system manages mounting, updating, and unmounting, ensuring predictable state and resource management.
- **Communication:** Events propagate up and down the component tree, enabling rich interactivity.
- **Testing:** Event-based test helpers and Mox-based system adapters ensure reliable, isolated tests.

See [Component API Reference](docs/components/api/component_api_reference.md) and [Component Architecture Guide](component_architecture.md) for full details on API, lifecycle, and best practices.

### Event & Rendering Pipeline

- Terminal events are captured, translated, and dispatched to the application via the Dispatcher
- Application state is updated and the view is re-rendered
- Terminal buffer is updated and changes are flushed to the terminal

## Test & Performance Infrastructure

### Event-Based Testing

- All asynchronous operations use event-based synchronization (no `Process.sleep`)
- Custom assertion helpers and event tracking for plugin lifecycle and state changes
- Systematic use of Mox for mocking system interactions
- Test isolation and resource cleanup via `on_exit` callbacks

### Performance Testing

- `Raxol.Test.PerformanceHelper` provides benchmarking utilities
- Performance requirements enforced:
  - Event processing: < 1ms avg, < 2ms 95th percentile
  - Screen updates: < 2ms avg, < 5ms 95th percentile
  - Concurrent operations: < 5ms avg, < 10ms 95th percentile
- Performance tests run via CLI or ExUnit, with metrics logged and regressions tracked in CI

## Directory Structure (Excerpt)

```bash
lib/raxol/
├── core/
│   ├── runtime/
│   │   ├── application.ex
│   │   ├── events/
│   │   ├── plugins/
│   │   └── rendering/
│   ├── color_system.ex
│   ├── focus_manager.ex
│   └── ...
├── terminal/
│   ├── buffer/
│   ├── cursor/
│   ├── state/
│   ├── command/
│   ├── style/
│   ├── parser/
│   ├── input/
│   └── ...
├── ui/
│   ├── components/
│   ├── layout/
│   ├── renderer.ex
│   └── theming/
└── ...
```

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

## Flow of Events

1. Terminal events are captured by the Terminal Driver
2. Events are translated into a standardized Event struct
3. Events are dispatched to the application via the Dispatcher
4. Application's `handle_event` callback processes the event
5. Application state is updated
6. View is re-rendered based on new state
7. Terminal buffer is updated with the new view
8. Changes are flushed to the terminal

## Directory Structure

```bash
lib/raxol/
├── accounts/              # User accounts related modules
│   └── ...
├── accounts.ex            # User accounts entry point
├── ai/                    # AI integration modules
│   └── ...
├── animation/             # Animation framework modules
│   └── ...
├── application.ex         # Top-level application definition
├── auth/                  # Authentication modules
│   └── ...
├── auth.ex                # Authentication logic entry point
├── benchmarks/            # Performance benchmarks
│   └── ...
├── cli/                   # Command Line Interface modules
│   └── ...
├── cloud/                 # Cloud integration modules
│   └── ...
├── cloud.ex               # Cloud integration entry point
├── components/            # Standalone UI Components (if distinct from UI layer)
│   └── ...
├── core/                  # Core runtime, application, events, rendering orchestration
│   ├── accessibility/     # Accessibility features
│   │   └── ...
│   ├── accessibility.ex   # Core Accessibility logic
│   ├── color_system.ex    # Theme/color management
│   ├── events/            # Core Event definitions
│   │   └── ...
│   ├── focus_manager.ex   # Focus management logic
│   ├── i18n.ex            # Internationalization
│   ├── id.ex              # Unique ID generation
│   ├── keyboard_navigator.ex # Keyboard navigation helper
│   ├── keyboard_shortcuts.ex # Shortcut management
│   ├── performance/       # Core performance modules
│   │   └── ...
│   ├── plugins/           # Core built-in plugin definitions
│   │   └── ...
│   ├── preferences/       # User preferences storage
│   │   └── ...
│   ├── renderer/          # Base rendering logic (if distinct from Runtime)
│   │   └── ...
│   ├── runtime/           # Primary Runtime behaviour, lifecycle, etc.
│   │   ├── application.ex
│   │   ├── events/        # Runtime Event dispatching logic
│   │   ├── plugins/       # Plugin Manager, Loader, Registry
│   │   └── rendering/     # Rendering Engine & Scheduler
│   ├── user_preferences.ex # User preferences GenServer
│   └── ux_refinement.ex   # UX refinement features
├── database/              # Database interaction modules
│   └── ...
├── database.ex            # Database interaction entry point
├── docs/                  # Embedded documentation generators & data
│   ├── catalog_data/
│   ├── component_catalog.ex
│   ├── interactive_tutorial.ex
│   └── tutorial_viewer.ex
├── dynamic_supervisor.ex  # Dynamic supervisor definition
├── metrics/               # Metrics collection modules
│   └── ...
├── metrics.ex             # Metrics collection entry point
├── plugins/               # Application-level plugins
│   ├── visualization/     # Visualization Plugin & Renderers
│   ├── ...                # Other plugins
│   ├── plugin.ex          # Plugin behaviour definition
│   └── ...                # Note: Primary manager is core/runtime/plugins/manager.ex
├── recording/             # Recording & playback modules
│   └── ...
├── repo.ex                # Ecto Repo definition
├── session.ex             # Session management entry point
├── style/                 # Styling and theming modules
│   └── ...
├── system/                # System utilities (updater, platform detection, interaction abstraction)
│   ├── interaction.ex     # Behaviour for system interactions (OS type, commands)
│   ├── interaction_impl.ex # Default implementation for system interactions
│   ├── delta_updater.ex   # Handles delta updates for the application
│   ├── delta_updater_system_adapter_behaviour.ex # Behaviour for DeltaUpdater system calls
│   ├── delta_updater_system_adapter_impl.ex    # Implementation for DeltaUpdater system calls
│   └── ...
├── terminal/              # Terminal I/O, NIF driver, ANSI Processing, Buffer
│   ├── ansi/              # ANSI sequence modules (Parser, Sixel, etc.)
│   │   └── ...
│   ├── buffer/            # ScreenBuffer logic
│   │   └── ...
│   ├── commands/          # Terminal command related modules
│   │   └── ...
│   ├── config/            # Terminal configuration helpers
│   │   └── ...
│   ├── ...                # Driver, Emulator, Parser, etc.
│   └── terminal_utils.ex  # Terminal utility functions
├── ui/                    # UI Components, Layout, Rendering, Theming (Primary UI layer)
│   ├── components/        # UI Components (implementing Base.Component)
│   │   ├── base/          # Base component behaviour
│   │   ├── display/       # Display components (Table, etc.)
│   │   └── input/         # Input components (Button, TextInput, etc.)
│   ├── layout/            # Layout Engine (measure/position)
│   │   └── ...
│   ├── renderer.ex        # Converts elements to styled cells
│   └── theming/           # Theme definitions and application
│       └── ...
├── view/                  # View Definition DSL
│   ├── elements.ex        # Macros for UI elements (box, text, etc.)
│   └── ...
└── web/                   # Web interface modules (Phoenix based)
    ├── channels/          # WebSocket channel handlers
    │   ├── user_socket.ex # Handles generic socket connections and routes to channels
    │   └── terminal_channel.ex # Manages real-time terminal communication
    ├── endpoint.ex        # Phoenix endpoint configuration
    ├── router.ex          # Phoenix router
    └── ...                # Other web-related files (controllers, views, templates for potential future admin UI)
```

## Core Subsystems & Status

- **Runtime System (`Core.Runtime.*`)**: Manages application lifecycle (`Application` behaviour), event dispatch (`Dispatcher`), plugin management (`Plugins.Manager`), and rendering orchestration (`Rendering.Engine`). **Core functionality designed and implemented.**
- **Plugin System (`Core.Runtime.Plugins.*`, `Raxol.Plugins.*`)**: Handles plugin discovery, loading, lifecycle (`Lifecycle`), event dispatch (`EventHandler`), cell processing (`CellProcessor`), command registration/execution (`CommandHelper`, `CommandRegistry`), and reloading. The core `PluginManager` now delegates most responsibilities to specialized modules. **Designed to be extensible; core features are functionally tested.**
  - All behavior modules are now complete and documented:
    - `DependencyManager.Behaviour`: Plugin dependency management
    - `CommandHelper.Behaviour`: Plugin command management
    - `PluginMetadataProvider.Behaviour`: Plugin metadata handling
    - `PluginReloader.Behaviour`: Plugin reloading functionality
    - `StateManager.Behaviour`: Plugin state management
    - `TimerManager.Behaviour`: Plugin timer management
    - `PluginEventFilter.Behaviour`: Plugin event filtering
    - `PluginCommandHandler.Behaviour`: Plugin command handling
    - `PluginCommandDispatcher.Behaviour`: Plugin command dispatching
    - `PluginCommandRegistry.Behaviour`: Plugin command registration
    - `PluginCommandHelper.Behaviour`: Plugin command registration and dispatch
  - Each behavior module has comprehensive documentation and clear callback specifications
  - All behaviors follow consistent patterns for error handling and state management
  - The plugin system is now fully modular and extensible
- **Event Handling (`Terminal.Driver`, `Core.Runtime.Events.Dispatcher`, `Raxol.Plugins.EventHandler`)**: `Driver` receives events from `:rrex_termbox` NIF, translates them, sends to `Dispatcher`. `Dispatcher` manages state and routes events/commands to `Application` or `PluginManager`. `EventHandler` dispatches relevant events to loaded plugins. **Core event flow established and refined.**
  - Event-based synchronization is now the standard for testing asynchronous operations
  - All tests use `assert_receive` or custom event assertions instead of `Process.sleep`
  - Event system includes comprehensive lifecycle events for better test reliability
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions, `Renderer` converts to styled cells using active theme, `Terminal.Renderer` outputs diff to terminal. **Pipeline is functional; key components like `Renderer` have seen significant recent fixes and testing (e.g., `renderer_edge_cases_test.exs` all pass).**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `handle_event/3` returns `{new_state, commands}`, `render/1` returns element map/list) and use `View.Elements` macros. `ComponentShowcase` example refactored to follow this pattern. **The foundational component behaviour is defined; new components and enhancements are ongoing.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional design, with `ColorSystem` made robust against undefined theme variants.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored. **Structure established.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules. **Structure established.**
- **Compiler Warnings**: Numerous compiler warnings (e.g., unused aliases/variables, duplicate docs) remain and require investigation. The project compiles, but addressing these warnings is an ongoing task.
- **Test Suite Health**: As of 2025-05-10, the test suite has a significant number of failures (279), invalid tests (17), and skipped tests (21). Active efforts are focused on addressing these, with a focus on high-impact/core areas first.
  - As of 2025-06-10, all dependency manager resolution tests pass.
- **Terminal Parser (`Terminal.Parser`):** Refactored `parse_loop` and `dispatch_csi`. **Core parsing logic for essential sequences is largely stable.**
- **Sixel Graphics (`Terminal.ANSI.SixelGraphics`):** Stateful parser with RLE optimization. **Feature complete and tested (all Sixel tests passing).**
- **MultiLineInput Component (`UI.Components.Input.MultiLineInput`):** Core logic refactored into helper modules. Basic navigation, clipboard, scroll, selection, and mouse handling implemented. **Refactored and enhanced; stable for current features.**
- **Visualization Plugin (`Plugins.VisualizationPlugin`):** Rendering logic extracted into helper modules. **Refactored design.**
- **User Preferences (`Core.Preferences.*`)**: Manages user preference loading, saving, and access. **Functional and integrated.**
- **Accessibility (`Core.Accessibility.*`)**: Implements `Raxol.Core.Accessibility.Behaviour`. Used by `UXRefinement`. **Core features implemented and refined, test coverage improved.**
- **Focus Manager (`Core.FocusManager.*`)**: Implements `Raxol.Core.FocusManager.Behaviour`. Used by `UXRefinement`. **Evolving.**
- **System Interaction (`Raxol.System.Interaction`)**: Behaviour for abstracting system interactions. **Pattern adopted.**
- **System Interaction Implementation (`Raxol.System.InteractionImpl`)**: Default implementation of `System.Interaction`. **Implemented.**
- **Delta Updater System Interaction (`Raxol.System.DeltaUpdater`, `Raxol.System.DeltaUpdaterSystemAdapterBehaviour`)**: Manages delta updates, using an adapter behaviour for testability. **Refactored to use adapter pattern.**
- **Environment Adapter (`Raxol.System.EnvironmentAdapterBehaviour`)**: Behaviour for abstracting system environment calls. **Implemented.**
- **RaxolWeb.UserSocket**: Phoenix Socket handler. **Stable.**

## Key Modules

| Module                                            | Description                                                                                                                            | Maturity |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `Raxol.Core.Runtime.Application`                  | Defines the application behaviour (init, update, view).                                                                                | Evolving |
| `Raxol.Core.Runtime.Events.Dispatcher`            | Manages application state, routes events/commands. (All tests in `dispatcher_test.exs` passing after fixes).                           | Stable   |
| `Raxol.Core.Runtime.Plugins.Manager`              | Manages plugin state and delegates to specialized modules. (Reloading tests in `manager_reloading_test.exs` passing).                  | Stable   |
| `Raxol.Plugins.Lifecycle`                         | Handles plugin loading, unloading, enabling, disabling, dependencies.                                                                  | Stable   |
| `Raxol.Plugins.EventHandler`                      | Dispatches events (input, mouse, resize, output, etc.) to plugins.                                                                     | Stable   |
| `Raxol.Plugins.CellProcessor`                     | Processes rendered cells, allowing plugins to handle placeholders.                                                                     | Stable   |
| `Raxol.Core.Runtime.Rendering.Engine`             | Orchestrates rendering: App -> Layout -> Renderer -> Terminal                                                                          | Stable   |
| `Raxol.UI.Components.Base.Component`              | Base behaviour for UI components                                                                                                       | Evolving |
| `Raxol.UI.Layout.Engine`                          | Calculates element positions.                                                                                                          | Evolving |
| `Raxol.UI.Renderer`                               | Converts layout elements to styled cells. (All 17 tests in `renderer_edge_cases_test.exs` passing).                                    | Stable   |
| `Raxol.UI.Theming.Theme`                          | Theme data structure and retrieval.                                                                                                    | Stable   |
| `Raxol.Terminal.Driver`                           | Manages `:rrex_termbox` NIF interface, receives/translates events.                                                                     | Stable   |
| `Raxol.Terminal.Parser`                           | Main parser state machine and state handlers.                                                                                          | Stable   |
| `Raxol.Terminal.Commands.Executor`                | Dispatches parsed terminal commands (CSI, OSC, DCS).                                                                                   | Stable   |
| `Raxol.Terminal.Emulator`                         | Core terminal emulator logic, state, and input processing.                                                                             | Stable   |
| `Raxol.View.Elements`                             | Macros (`panel`, `row`, `column`, `box`, `label`, input macros) for defining UI views.                                                 | Evolving |
| `Raxol.Core.Preferences.Persistence`              | Handles preference file I/O                                                                                                            | Stable   |
| `Raxol.Core.Accessibility.Behaviour`              | Defines the contract for accessibility services.                                                                                       | Stable   |
| `Raxol.Core.FocusManager.Behaviour`               | Defines the contract for focus management services.                                                                                    | Evolving |
| `Raxol.Core.ColorSystem`                          | Centralized theme/accessibility-aware color retrieval, robust against theme variants. Uses specialized modules for core functionality. | Stable   |
| `Raxol.Style.Colors.Color`                        | Core color representation and manipulation, handling format conversions and basic operations.                                          | Stable   |
| `Raxol.UI.Theming.Colors`                         | UI-specific color operations, maintaining backward compatibility while using the new color system.                                     | Stable   |
| `Raxol.Style.Colors.Utilities`                    | Shared color utilities, accessibility checks, and palette management.                                                                  | Stable   |
| `Raxol.System.Interaction`                        | Behaviour for abstracting system interactions.                                                                                         | Defined  |
| `Raxol.System.DeltaUpdaterSystemAdapterBehaviour` | Behaviour abstracting system interactions for `DeltaUpdater`.                                                                          | Defined  |
| `Raxol.System.EnvironmentAdapterBehaviour`        | Behaviour abstracting system environment calls.                                                                                        | Defined  |
| `RaxolWeb.UserSocket`                             | Phoenix Socket handler for WebSockets. (All tests in `terminal_channel_test.exs` related to this passing).                             | Stable   |

**Note on Module Maturity:**

- **Stable:** Core functionality is implemented and has significant passing tests for its current scope. Not expecting immediate major refactoring.
- **Evolving:** Actively under development, may be undergoing API changes, or has known limitations/tests failing.
- **Defined:** The foundational structure/behaviour is defined and implemented. Further features or refinements will evolve it.
- **Planned:** The module is planned for future development, but the core functionality is not yet implemented.
- **Experimental:** The module is new and not yet fully tested.
- **Deprecated:** The module is no longer maintained and will be removed in a future version.

---

## Plugin System

- **Lifecycle**: Discovery (`Loader`), sorting (`LifecycleHelper`), `init/1`, `terminate/2`.
- **Commands**: Register via `get_commands/0` (namespaced), handled by `handle_command/3`, efficient lookup via ETS (`CommandRegistry`).
- **Metadata**: Optional `PluginMetadataProvider` behaviour for `id`, `version`, `dependencies`. Used by `Loader`/`LifecycleHelper`.
- **Reloading**:
  - Manual: `PluginManager.reload_plugin/1` calls `LifecycleHelper.reload_plugin_from_disk/8`. (Process tested and working in `manager_reloading_test.exs`).
  - Automatic (Dev Only): Optionally uses `file_system` to watch plugin source files. Enabled via `enable_plugin_reloading: true` option to `PluginManager.start_link/1`.
- **Core Plugins**: `ClipboardPlugin`, `NotificationPlugin` in `lib/raxol/core/plugins/core/`. (Tests passing for both after mocking improvements).
- **Visualization Plugin**: Uses `handle_placeholder` hook to render charts, treemaps, images via helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`).

## Efficient Runtime Flow

1. **Init**: Supervisor starts processes. `PluginManager` discovers, sorts, loads plugins (deps check, `init/1`, register commands). `Dispatcher` gets initial model/commands. `Driver` starts `:rrex_termbox` NIF.
2. **Event**: `:rrex_termbox` NIF sends event message -> `Driver` translates -> `Event` -> `Dispatcher` (async).
3. **Update**: `Dispatcher` calls `Application.update/2` -> new model, commands.
4. **Command**: `Dispatcher` handles core cmds or routes to `PluginManager` (async) -> `CommandHelper` -> ETS lookup -> `Plugin.handle_command/3`.
5. **Render**: `Scheduler` triggers `RenderingEngine`. Engine gets model/theme from `Dispatcher` -> `Application.view/1` -> `LayoutEngine` (positions) -> `UIRenderer` (styled cells) -> `Terminal.Renderer` (diff output).
6. **Reload**: `PluginManager` -> `LifecycleHelper` -> unload/purge/recompile/load/reinit sequence.

## Test Infrastructure

The test infrastructure has been significantly improved to ensure reliability and determinism:

1. **Event-Based Testing:**

   - All asynchronous operations are tested using event-based synchronization
   - Custom assertion helpers in `test/support/` for common event patterns
   - Standardized event emission for component lifecycle and state changes
   - Replaced all `Process.sleep` calls with deterministic event assertions
   - Added comprehensive event tracking for plugin lifecycle events

2. **Test Isolation:**

   - Each test plugin has unique state tracking via `state_id` and timestamps
   - Proper cleanup of resources in `on_exit` callbacks
   - Consistent use of Ecto Sandbox for database tests
   - Unique test data generation to prevent interference
   - Plugin test fixtures designed for parallel test execution
   - Clear state boundaries between test runs

3. **Mocking Strategy:**

   - Systematic use of Mox for mocking external dependencies
   - System Interaction Adapter pattern for testable system calls
   - Consistent mock setup and verification across test files
   - Improved mock expectations with better error messages
   - Clear separation of mock responsibilities

4. **Test Organization:**

   - Tests mirror the source code structure
   - Dedicated test helpers and fixtures in `test/support/`
   - Clear separation of unit, integration, and system tests
   - Comprehensive plugin test fixtures with clear error scenarios
   - Better documentation of test requirements and setup

5. **Plugin Testing:**

   - Enhanced plugin test fixtures with better state management
   - Improved error handling and reporting
   - Better resource cleanup in plugin lifecycle
   - Comprehensive metadata validation testing
   - Clear test boundaries for plugin operations

6. **Current Status (2025-05-10):**

   - 279 failures (down from previous count)
   - 17 invalid tests
   - 21 skipped tests
   - All new code requires comprehensive test coverage
   - Event-based synchronization is mandatory for async tests

7. **Best Practices:**

   - Use `assert_receive` instead of `Process.sleep`
   - Track state changes with unique IDs and timestamps
   - Clean up resources in `on_exit` callbacks
   - Use adapter pattern for system interactions
   - Document test requirements and setup
   - Ensure proper test isolation
   - Use meaningful error messages
   - Track test coverage

8. **Recent Improvements:**
   - Replaced all `Process.sleep` calls with event-based synchronization
   - Enhanced plugin test fixtures with better state management
   - Improved error handling and reporting
   - Added comprehensive metadata validation testing
   - Better resource cleanup in plugin lifecycle
   - Clear test boundaries for plugin operations
   - Improved mock expectations with better error messages
   - Added unique state tracking for test plugins
   - All dependency manager resolution tests now pass, including cycle detection, duplicate ID, and optional version handling.

## Performance Testing and Benchmarking

The Raxol codebase includes a comprehensive performance testing infrastructure to ensure optimal performance across all components.
The performance testing system is built on top of ExUnit and provides utilities for benchmarking, metrics collection, and performance assertions.

### Performance Test Infrastructure

The performance testing infrastructure consists of:

1. `Raxol.Test.PerformanceHelper` - A module providing utilities for:

   - Setting up performance test environments
   - Running benchmarks with configurable iterations and warmup
   - Asserting performance requirements
   - Collecting and formatting performance metrics

2. Performance Test Cases - Specialized test modules that:
   - Use the performance helper
   - Define performance requirements
   - Generate realistic test scenarios
   - Log performance metrics for analysis

### Performance Requirements

Performance tests enforce the following requirements:

1. Event Processing

   - Average time: < 1ms per event
   - 95th percentile: < 2ms per event
   - Minimum iterations: 100

2. Screen Updates

   - Average time: < 2ms per update
   - 95th percentile: < 5ms per update
   - Minimum iterations: 100

3. Concurrent Operations
   - Average time: < 5ms per operation set
   - 95th percentile: < 10ms per operation set
   - Minimum iterations: 100

### Running Performance Tests

Performance tests can be run using:

```bash
mix test test/raxol/terminal/manager_performance_test.exs
```

Performance metrics are logged for analysis and can be used to track performance regressions over time.
