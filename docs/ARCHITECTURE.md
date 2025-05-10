---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2025-05-08
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

This document provides an overview of the Raxol architecture, its components, and how they interact.

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

### Terminal Subsystem

The Terminal subsystem handles direct interaction with the terminal through the NIF-based rrex_termbox library. Key modules:

- `Raxol.Terminal.Driver`: Manages the terminal interface via NIF
- `Raxol.Terminal.Buffer`: Implements double buffering for smooth rendering
- `Raxol.Terminal.ANSI`: Processes ANSI escape sequences
- `Raxol.Terminal.Input`: Handles keyboard and mouse input events

### Runtime System

The Runtime system coordinates the application lifecycle, events, and state management. Key modules:

- `Raxol.Core.Runtime.Application`: Behaviour for Raxol applications
- `Raxol.Core.Runtime.Lifecycle`: Manages application startup and shutdown
- `Raxol.Core.Runtime.Events`: Handles event dispatching and subscriptions
- `Raxol.Core.Runtime.Plugins`: Provides plugin infrastructure

### Component System

The Component system provides reusable UI components. Key modules:

- `Raxol.Components.*`: UI components like buttons, text inputs, etc.
- `Raxol.View.Elements`: DSL for component composition
- `Raxol.Core.ColorSystem`: Theme and color management
- `Raxol.Core.Focus`: Focus management for components

### View System

The View system handles layout and component composition. Key modules:

- `Raxol.View.Elements`: Macros for layout definition
- `Raxol.UI.Layout`: Layout algorithms for components
- `Raxol.UI.Rendering`: Rendering pipeline

## Key Design Decisions

1. **Application Model**: Inspired by The Elm Architecture, with clear update/view separation.
2. **NIF-based Terminal Interface**: Uses rrex_termbox NIF for improved performance.
3. **Component System**: Reusable, stateful components with lifecycle hooks.
4. **Plugins**: Extensible through a plugin system.
5. **System Interaction Adapters**: For modules with direct operating system or external service interactions (e.g., file system, HTTP calls, system commands), an adapter pattern (a behaviour defining the interaction contract and an implementation module) is used. This allows for mocking these interactions in tests, improving test reliability and isolation. Examples include `Raxol.System.DeltaUpdater` with its `Raxol.System.DeltaUpdaterSystemAdapterBehaviour`, and `Raxol.Terminal.Config.Capabilities` with its `Raxol.System.EnvironmentAdapterBehaviour`.

## Flow of Events

1. Terminal events are captured by the Terminal Driver
2. Events are translated into a standardized Event struct
3. Events are dispatched to the application via the Dispatcher
4. Application's `handle_event` callback processes the event
5. Application state is updated
6. View is re-rendered based on new state
7. Terminal buffer is updated with the new view
8. Changes are flushed to the terminal

## Overview

Raxol is organized into logical subsystems:

1. **Core**: Fundamental runtime, application lifecycle, plugin system, event dispatch, and rendering orchestration.
2. **UI**: Component model (`Base.Component` behaviour), layout engine, rendering logic, and theming.
3. **Terminal**: Low-level terminal interaction via `:rrex_termbox` NIF, ANSI parsing/emulation (`Parser`, `Emulator`), Sixel support.
4. **View**: DSL (`Elements` macros) for defining UI structures.
5. **Support Modules**: Benchmarking, Cloud integration (partially refactored).

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
- **Event Handling (`Terminal.Driver`, `Core.Runtime.Events.Dispatcher`, `Raxol.Plugins.EventHandler`)**: `Driver` receives events from `:rrex_termbox` NIF, translates them, sends to `Dispatcher`. `Dispatcher` manages state and routes events/commands to `Application` or `PluginManager`. `EventHandler` dispatches relevant events to loaded plugins. **Core event flow established and refined.**
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions, `Renderer` converts to styled cells using active theme, `Terminal.Renderer` outputs diff to terminal. **Pipeline is functional; key components like `Renderer` have seen significant recent fixes and testing (e.g., `renderer_edge_cases_test.exs` all pass).**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `handle_event/3` returns `{new_state, commands}`, `render/1` returns element map/list) and use `View.Elements` macros. `ComponentShowcase` example refactored to follow this pattern. **The foundational component behaviour is defined; new components and enhancements are ongoing.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional design, with `ColorSystem` made robust against undefined theme variants.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored. **Structure established.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules. **Structure established.**
- **Compiler Warnings**: Numerous compiler warnings (e.g., unused aliases/variables, duplicate docs) remain and require investigation. The project compiles, but addressing these warnings is an ongoing task.
- **Test Suite Health**: As of 2025-05-08, the test suite has a significant number of failures (225) and skipped tests (27). Active efforts are focused on addressing these.
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

| Module                                            | Description                                                                                                           | Maturity |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | -------- |
| `Raxol.Core.Runtime.Application`                  | Defines the application behaviour (init, update, view).                                                               | Evolving |
| `Raxol.Core.Runtime.Events.Dispatcher`            | Manages application state, routes events/commands. (All tests in `dispatcher_test.exs` passing after fixes).          | Stable   |
| `Raxol.Core.Runtime.Plugins.Manager`              | Manages plugin state and delegates to specialized modules. (Reloading tests in `manager_reloading_test.exs` passing). | Stable   |
| `Raxol.Plugins.Lifecycle`                         | Handles plugin loading, unloading, enabling, disabling, dependencies.                                                 | Stable   |
| `Raxol.Plugins.EventHandler`                      | Dispatches events (input, mouse, resize, output, etc.) to plugins.                                                    | Stable   |
| `Raxol.Plugins.CellProcessor`                     | Processes rendered cells, allowing plugins to handle placeholders.                                                    | Stable   |
| `Raxol.Core.Runtime.Rendering.Engine`             | Orchestrates rendering: App -> Layout -> Renderer -> Terminal                                                         | Stable   |
| `Raxol.UI.Components.Base.Component`              | Base behaviour for UI components                                                                                      | Evolving |
| `Raxol.UI.Layout.Engine`                          | Calculates element positions.                                                                                         | Evolving |
| `Raxol.UI.Renderer`                               | Converts layout elements to styled cells. (All 17 tests in `renderer_edge_cases_test.exs` passing).                   | Stable   |
| `Raxol.UI.Theming.Theme`                          | Theme data structure and retrieval.                                                                                   | Stable   |
| `Raxol.Terminal.Driver`                           | Manages `:rrex_termbox` NIF interface, receives/translates events.                                                    | Stable   |
| `Raxol.Terminal.Parser`                           | Main parser state machine and state handlers.                                                                         | Stable   |
| `Raxol.Terminal.Commands.Executor`                | Dispatches parsed terminal commands (CSI, OSC, DCS).                                                                  | Stable   |
| `Raxol.Terminal.Emulator`                         | Core terminal emulator logic, state, and input processing.                                                            | Stable   |
| `Raxol.View.Elements`                             | Macros (`panel`, `row`, `column`, `box`, `label`, input macros) for defining UI views.                                | Evolving |
| `Raxol.Core.Preferences.Persistence`              | Handles preference file I/O                                                                                           | Stable   |
| `Raxol.Core.Accessibility.Behaviour`              | Defines the contract for accessibility services.                                                                      | Stable   |
| `Raxol.Core.FocusManager.Behaviour`               | Defines the contract for focus management services.                                                                   | Evolving |
| `Raxol.Core.ColorSystem`                          | Centralized theme/accessibility-aware color retrieval, robust against theme variants.                                 | Stable   |
| `Raxol.System.Interaction`                        | Behaviour for abstracting system interactions.                                                                        | Defined  |
| `Raxol.System.DeltaUpdaterSystemAdapterBehaviour` | Behaviour abstracting system interactions for `DeltaUpdater`.                                                         | Defined  |
| `Raxol.System.EnvironmentAdapterBehaviour`        | Behaviour abstracting system environment calls.                                                                       | Defined  |
| `RaxolWeb.UserSocket`                             | Phoenix Socket handler for WebSockets. (All tests in `terminal_channel_test.exs` related to this passing).            | Stable   |

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
