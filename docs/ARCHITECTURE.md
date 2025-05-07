---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2024-08-08
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

1. **Application Model**: Inspired by The Elm Architecture, with clear update/view separation
2. **NIF-based Terminal Interface**: Uses rrex_termbox NIF for improved performance
3. **Component System**: Reusable, stateful components with lifecycle hooks
4. **Plugins**: Extensible through a plugin system

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
└── web/                   # Web interface modules
    └── ...
```

## Core Subsystems & Status

- **Runtime System (`Core.Runtime.*`)**: Manages application lifecycle (`Application` behaviour), event dispatch (`Dispatcher`), plugin management (`Plugins.Manager`), and rendering orchestration (`Rendering.Engine`). **Largely functional, tested.**
- **Plugin System (`Core.Runtime.Plugins.*`, `Raxol.Plugins.*`)**: Handles plugin discovery, loading, lifecycle (`Lifecycle`), event dispatch (`EventHandler`), cell processing (`CellProcessor`), command registration/execution (`CommandHelper`, `CommandRegistry`), and reloading. The core `PluginManager` now delegates most responsibilities to specialized modules. **Refactored, Functional, Tested.**
- **Event Handling (`Terminal.Driver`, `Core.Runtime.Events.Dispatcher`, `Raxol.Plugins.EventHandler`)**: `Driver` receives events from `:rrex_termbox` NIF, translates them, sends to `Dispatcher`. `Dispatcher` manages state and routes events/commands to `Application` or `PluginManager`. `EventHandler` dispatches relevant events to loaded plugins. **Refactored.**
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions (measurement logic implemented for core elements, panel measurement fixed), `Renderer` converts to styled cells using active theme (now includes direct handling for `:table` elements), `Terminal.Renderer` outputs diff to terminal. **Functional, tested.**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `handle_event/3` returns `{new_state, commands}`, `render/1` returns element map/list) and use `View.Elements` macros (e.g., `label`, `panel`). Requires explicit component map rendering (`%{type: ...}`) rather than direct function calls for non-Element components. `ComponentShowcase` example refactored to follow this pattern. **Refactoring ongoing.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored into sub-modules. **Refactored.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules (Metrics, Errors, Health, Alerts). **Refactored.**
- **Compiler Warnings**: Addressed numerous compilation errors/warnings during refactoring. Some warnings persist (unused aliases/variables, duplicate docs, etc.) and require manual cleanup (see `CHANGELOG.md`). Project compiles without `--warnings-as-errors`.
- **Terminal Parser (`Terminal.Parser`):** Refactored `parse_loop` by extracting logic for each state into separate `handle_<state>_state` functions. Refactored `dispatch_csi` into category-specific sub-dispatcher functions. **Implemented handlers for core CSI sequences needed for tests.**
- **Sixel Graphics (`Terminal.ANSI.SixelGraphics`):** Extracted pattern map and palette logic. Stateful parser implemented with parameter parsing for key commands. RLE optimization implemented. **Fully functional and tested, with recent verification of ST escape sequences in tests.**
- **MultiLineInput Component (`UI.Components.Input.MultiLineInput`):** Core logic refactored into helper modules (`Text`, `Navigation`, `Render`, `Event`, `Clipboard`). Basic navigation, clipboard, scroll, selection, and basic mouse handling implemented. Basic tests added. **Refactored, Enhanced.**
- **Visualization Plugin (`Plugins.VisualizationPlugin`):** Extracted rendering logic into helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`). Core plugin now delegates rendering via `handle_placeholder`. **Refactored.**
- **User Preferences (`Core.Preferences.*`)**: Manages user preference loading, saving, and access via `UserPreferences` GenServer and `Persistence` module. Integrated with core modules. **Functional, Integrated.**
- **Accessibility (`Core.Accessibility.*`)**: Provides core accessibility features (`announce`, specific setters like `set_high_contrast`). Options are read via `UserPreferences.get/1`. `ThemeIntegration` connects settings to themes. **API usage across codebase needs review/cleanup based on available public functions.**
- **System Interaction (`Raxol.System.Interaction`)**: Behaviour for abstracting system interactions (commands, OS type, etc.) for testability. **Added.**
- **System Interaction Implementation (`Raxol.System.InteractionImpl`)**: Default implementation of `System.Interaction` using Elixir/Erlang functions. **Added.**

## Key Modules

| Module                                 | Description                                                                                     | Status                                    |
| -------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `Raxol.Core.Runtime.Application`       | Defines the application behaviour (init, update, view)                                          | Defined                                   |
| `Raxol.Core.Runtime.Events.Dispatcher` | Manages application state, routes events/commands                                               | Functional                                |
| `Raxol.Core.Runtime.Plugins.Manager`   | Manages plugin state and delegates lifecycle, events, etc., to specialized modules.             | Refactored, Functional                    |
| `Raxol.Plugins.Lifecycle`              | Handles plugin loading, unloading, enabling, disabling, dependencies.                           | Added, Functional                         |
| `Raxol.Plugins.EventHandler`           | Dispatches events (input, mouse, resize, output, etc.) to plugins.                              | Added, Functional                         |
| `Raxol.Plugins.CellProcessor`          | Processes rendered cells, allowing plugins to handle placeholders.                              | Added, Functional                         |
| `Raxol.Core.Runtime.Rendering.Engine`  | Orchestrates rendering: App -> Layout -> Renderer -> Terminal                                   | Functional                                |
| `Raxol.UI.Components.Base.Component`   | Base behaviour for UI components                                                                | Defined, Adopted                          |
| `Raxol.UI.Layout.Engine`               | Calculates element positions                                                                    | Functional, Tested                        |
| `Raxol.UI.Renderer`                    | Converts layout elements to styled cells using active theme. Handles `:box`, `:text`, `:table`. | Functional                                |
| `Raxol.UI.Theming.Theme`               | Theme data structure and retrieval                                                              | Functional                                |
| `Raxol.Terminal.Driver`                | Manages `:rrex_termbox` NIF interface, receives/translates events to Raxol events.              | Stable (**Test Env. Workaround**)         |
| `Raxol.Terminal.Parser`                | Main parser state machine and state handlers                                                    | Stable                                    |
| `Raxol.Terminal.Commands.Executor`     | Dispatches parsed terminal commands (CSI, OSC, DCS) to dedicated handler modules.               | Stable (Core Handlers Tested)             |
| `Raxol.Terminal.Emulator`              | Core terminal emulator logic, state, and input processing.                                      | Stable (Core Handlers/Response Tested)    |
| `Raxol.View.Elements`                  | Macros (`panel`, `row`, `column`, `box`, `label`, input macros) for defining UI views.          | Defined, Used (Note: `text` not included) |
| `Raxol.Core.Preferences.Persistence`   | Handles preference file I/O                                                                     | Stable                                    |
| `Raxol.Core.ColorSystem`               | Centralized theme/accessibility-aware color retrieval                                           | Added, Functional                         |
| `Raxol.System.Interaction`             | Behaviour for abstracting system interactions (commands, OS type, etc.) for testability.        | Added                                     |

## Plugin System

- **Lifecycle**: Discovery (`Loader`), sorting (`LifecycleHelper`), `init/1`, `terminate/2`.
- **Commands**: Register via `get_commands/0` (namespaced), handled by `handle_command/3`, efficient lookup via ETS (`CommandRegistry`).
- **Metadata**: Optional `PluginMetadataProvider` behaviour for `id`, `version`, `dependencies`. Used by `Loader`/`LifecycleHelper`.
- **Reloading**:
  - Manual: `PluginManager.reload_plugin/1` calls `LifecycleHelper.reload_plugin_from_disk/8`, which unloads, purges code, recompiles source, reloads, reinitializes, handling failures.
  - Automatic (Dev Only): Optionally uses the `file_system` library to watch plugin source files. Changes trigger the manual reload process after a short debounce. Enabled via `enable_plugin_reloading: true` option to `PluginManager.start_link/1`.
- **Core Plugins**: `ClipboardPlugin`, `NotificationPlugin` in `lib/raxol/core/plugins/core/`. (Tests passing for both after mocking improvements).
- **Visualization Plugin**: Uses `handle_placeholder` hook to render charts, treemaps, images via helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`).

## Efficient Runtime Flow

1. **Init**: Supervisor starts processes. `PluginManager` discovers, sorts, loads plugins (deps check, `init/1`, register commands). `Dispatcher` gets initial model/commands. `Driver` starts `:rrex_termbox` NIF.
2. **Event**: `:rrex_termbox` NIF sends event message -> `Driver` translates -> `Event` -> `Dispatcher` (async).
3. **Update**: `Dispatcher` calls `Application.update/2` -> new model, commands.
4. **Command**: `Dispatcher` handles core cmds or routes to `PluginManager` (async) -> `CommandHelper` -> ETS lookup -> `Plugin.handle_command/3`.
5. **Render**: `Scheduler` triggers `RenderingEngine`. Engine gets model/theme from `Dispatcher` -> `Application.view/1` -> `LayoutEngine` (positions) -> `UIRenderer` (styled cells) -> `Terminal.Renderer` (diff output).
6. **Reload**: `PluginManager` -> `LifecycleHelper` -> unload/purge/recompile/load/reinit sequence.

## Recent Changes Summary (Last Updated: 2024-08-08)

- **Testing:**
  - Addressed NIF loading issues (`rrex_termbox v2.0.4`).
  - Resolved numerous invalid tests (~28 related to `ScreenModes` deprecation, ~11 related to `UserPreferences` setup).
  - Fixed all failures in `writing_buffer_test.exs`, `ColorSystemTest`, `AdvancedTest`, `NotificationPluginTest`, `ModeManager`, `Screen`, `Renderer` (HTML escaping).
  - Addressed issues in `AccessibilityTest` and fixed 5 of 6 targeted EL/ED tests in `screen_test.exs`.
  - Verified and corrected Sixel string terminator sequences in `test/terminal/ansi/sixel_graphics_test.exs`, ensuring all tests pass.
  - Current Status: **260 failures, 24 skipped** (as of 2024-08-08). The `Mox.VerificationError` for `TerminalStateMock.save_state/2` in `test/terminal/mode_manager_test.exs` and related control flow issues in the `set_mode` path for alternate buffers are still under active investigation.
- **Runtime:**
  - Introduced basic plugin lifecycle management (`Manager`, `Loader`, `LifecycleHelper`).
  - Added `CommandRegistry` for dynamic command dispatch.
- **UI / Components:**
  - Deprecated `ScreenModes` in favor of direct manipulation via `FrameBuffer`.
  - Minor fixes in `InputHandler` related to test failures.

## Testing

- **Status:** High failure count (**260 failing, 24 skipped**). Stability and resolving remaining issues in `screen_test.exs` and `AccessibilityTest` are top priorities.
- **Strategy:** Unit tests (`ExUnit`), property-based tests (`Properties.Case`), integration tests.
- **Frameworks:** `ExUnit`, `Mox` (for behaviours), `meck` (for non-behaviours), `Briefly` (for temp files/dirs).
- **Challenges:** Testing components involving `async: false` and GenServer interactions with mocking libraries like `:meck` has proven difficult (see `AccessibilityTest`). The `Mox.VerificationError` in `test/terminal/mode_manager_test.exs` highlights ongoing challenges with mock verification or control flow in specific test scenarios.
- **Key Areas:**
  - Core terminal emulation (`VT100`, `CSIHandlers`, etc.)
  - Runtime components (`Manager`, `Loader`, `LifecycleHelper`, `CommandRegistry`)
  - UI components (`Component`, `InputHandler`, `OutputHandler`)
  - NIF interaction (`rrex_termbox`)

## Codebase Size & Refactoring Candidates

**Note:** Last updated: 2024-08-01. Focus is on modules potentially needing refactoring due to size/complexity.

**Large Modules (> 900 LOC):**

- `./docs/development/planning/performance/case_studies.md` (~999 lines) - _Documentation_
- `./lib/raxol/docs/interactive_tutorial.ex` (~915 lines) - _Documentation/Example_

_(Detailed breakdown of smaller files removed for brevity. Focus on modules over ~900 lines)_

## Module Overview

_(Detailed table removed. Please refer to ExDoc or explore the codebase for module-specific details.)_
