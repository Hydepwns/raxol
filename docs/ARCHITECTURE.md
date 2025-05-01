---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2024-08-01
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
├── system/                # System utilities (updater, platform detection)
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
- **Plugin System (`Core.Runtime.Plugins.*`)**: Handles plugin discovery, loading (`Loader`), lifecycle (`LifecycleHelper`), command registration/execution (`CommandHelper`, `CommandRegistry`), and reloading. **Functional, tested.**
- **Event Handling (`Terminal.Driver`, `Core.Runtime.Events.Dispatcher`)**: `Driver` receives events from `:rrex_termbox` NIF, translates them, sends to `Dispatcher`. `Dispatcher` manages state and routes events/commands to `Application` or `PluginManager`. **Refactored.**
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions (measurement logic implemented for core elements), `Renderer` converts to styled cells using active theme (now includes direct handling for `:table` elements), `Terminal.Renderer` outputs diff to terminal. **Functional, tested.**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `update/2`, `handle_event/3`, `render/2`) and use `View.Elements` macros. **Refactoring ongoing; `MultiLineInput` refactored into helpers, `Table` refactored to return raw map for `Renderer`, multiple core components updated.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored into sub-modules. **Refactored.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules (Metrics, Errors, Health, Alerts). **Refactored.**
- **Compiler Warnings**: Addressed numerous compilation errors/warnings during refactoring. Some warnings persist (unused aliases/variables, duplicate docs, etc.) and require manual cleanup (see `CHANGELOG.md`). Project compiles without `--warnings-as-errors`.
- **Terminal Parser (`Terminal.Parser`):** Refactored `parse_loop` by extracting logic for each state into separate `handle_<state>_state` functions. Refactored `dispatch_csi` into category-specific sub-dispatcher functions. **Implemented handlers for core CSI sequences needed for tests.**
- **Sixel Graphics (`Terminal.ANSI.SixelGraphics`):** Extracted pattern map and palette logic. Stateful parser implemented with parameter parsing for key commands. **RLE optimization implemented.**
- **MultiLineInput Component (`UI.Components.Input.MultiLineInput`):** Core logic refactored into helper modules (`Text`, `Navigation`, `Render`, `Event`, `Clipboard`). Basic navigation, clipboard, scroll, selection, and basic mouse handling implemented. Basic tests added. **Refactored, Enhanced.**
- **Visualization Plugin (`Plugins.VisualizationPlugin`):** Extracted rendering logic into helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`). Core plugin now delegates rendering via `handle_placeholder`. **Refactored.**
- **User Preferences (`Core.Preferences.*`)**: Manages user preference loading, saving, and access via `UserPreferences` GenServer and `Persistence` module. Integrated with core modules. **Functional, Integrated.**
- **Accessibility (`Core.Accessibility.*`)**: Provides core accessibility features (`announce`, specific setters like `set_high_contrast`). Options are read via `UserPreferences.get/1`. `ThemeIntegration` connects settings to themes. **API usage across codebase needs review/cleanup based on available public functions.**

## Key Modules

| Module                                         | Description                                                                                     | Status             |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------ |
| `Raxol.Core.Runtime.Application`               | Defines the application behaviour (init, update, view)                                          | Defined            |
| `Raxol.Core.Runtime.Events.Dispatcher`         | Manages application state, routes events/commands                                               | Functional         |
| `Raxol.Core.Runtime.Plugins.Manager`           | Manages plugin lifecycle, command execution, reloading                                          | Functional, Tested |
| `Raxol.Core.Runtime.Rendering.Engine`          | Orchestrates rendering: App -> Layout -> Renderer -> Terminal                                   | Functional         |
| `Raxol.UI.Components.Base.Component`           | Base behaviour for UI components                                                                | Defined, Adopted   |
| `Raxol.UI.Layout.Engine`                       | Calculates element positions                                                                    | Functional, Tested |
| `Raxol.UI.Renderer`                            | Converts layout elements to styled cells using active theme. Handles `:box`, `:text`, `:table`. | Functional         |
| `Raxol.UI.Theming.Theme`                       | Theme data structure and retrieval                                                              | Functional         |
| `Raxol.Terminal.Driver`                        | Manages `:rrex_termbox` NIF interface, receives/translates events to Raxol events.              | Stable             |
| `Raxol.Terminal.Parser`                        | Main parser state machine and state handlers                                                    | Stable             |
| `Raxol.Terminal.Commands.Executor`             | Executes parsed CSI commands (SGR, CUP, ED/EL etc.). Basic OSC/DCS placeholders.                | Functional         |
| `Raxol.Terminal.ANSI.ScreenModes`              | Handles screen mode transitions (SM/RM, Alt Screen, Cursor Vis, Wrap). Incl. handle\_\*\_mode.  | Stable             |
| `Raxol.Terminal.ControlCodes`                  | Handles C0 and simple ESC control codes                                                         | Stable             |
| `Raxol.Terminal.ANSI.SixelGraphics`            | Stateful Sixel graphics parser with RLE optimization                                            | Refactored, Opt.   |
| `Raxol.View.Elements`                          | Macros (`box`, `text`, etc.) for defining UI views                                              | Defined, Used      |
| `Raxol.Plugins.VisualizationPlugin`            | Handles visualization placeholders, delegates rendering                                         | Refactored         |
| `Raxol.Plugins.Visualization.ChartRenderer`    | Helper for rendering chart visualizations                                                       | Added              |
| `Raxol.Plugins.Visualization.TreemapRenderer`  | Helper for rendering treemap visualizations. Uses `DrawingUtils`.                               | Added              |
| `Raxol.Plugins.Visualization.ImageRenderer`    | Helper for rendering image visualizations                                                       | Added              |
| `Raxol.Plugins.Visualization.DrawingUtils`     | Shared drawing helpers (`draw_box_borders`, `draw_text_centered/3`, `draw_text/4`, `put_cell`). | Added              |
| `Raxol.UI.Components.Input.MultiLineInput.*`   | Helper modules for `MultiLineInput` component                                                   | Added, Functional  |
| `Raxol.UI.Components.Display.Table`            | Displays tabular data via attributes. `render/2` returns map for `Renderer`.                    | Refactored         |
| `Raxol.Terminal.Integration/memory_manager.ex` | Helper for memory management in Terminal Integration                                            | Added              |
| `Raxol.Terminal.Config/utils.ex`               | Utilities for terminal configuration merging                                                    | Added              |
| `Raxol.Core.Preferences.Persistence`           | Handles preference file I/O                                                                     | Stable             |
| `Raxol.Core.ColorSystem`                       | Centralized theme/accessibility-aware color retrieval                                           | Added, Functional  |
| `Raxol.Core.Accessibility.ThemeIntegration`    | Connects accessibility settings (read via `UserPreferences`) with themes                        | Refactored         |
| `Raxol.Core.UserPreferences`                   | GenServer for managing user preferences state (reads/writes via `Persistence`)                  | Refactored         |
| `Raxol.Core.Accessibility`                     | Core accessibility logic (announcements, setters). Options read via `UserPreferences`.          | Refactored         |

## Plugin System

- **Lifecycle**: Discovery (`Loader`), sorting (`LifecycleHelper`), `init/1`, `terminate/2`.
- **Commands**: Register via `get_commands/0` (namespaced), handled by `handle_command/3`, efficient lookup via ETS (`CommandRegistry`).
- **Metadata**: Optional `PluginMetadataProvider` behaviour for `id`, `version`, `dependencies`. Used by `Loader`/`LifecycleHelper`.
- **Reloading**:
  - Manual: `PluginManager.reload_plugin/1` calls `LifecycleHelper.reload_plugin_from_disk/8`, which unloads, purges code, recompiles source, reloads, reinitializes, handling failures.
  - Automatic (Dev Only): Optionally uses the `file_system` library to watch plugin source files. Changes trigger the manual reload process after a short debounce. Enabled via `enable_plugin_reloading: true` option to `PluginManager.start_link/1`.
- **Core Plugins**: `ClipboardPlugin`, `NotificationPlugin` in `lib/raxol/core/plugins/core/`.
- **Visualization Plugin**: Uses `handle_placeholder` hook to render charts, treemaps, images via helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`).

## Efficient Runtime Flow

1. **Init**: Supervisor starts processes. `PluginManager` discovers, sorts, loads plugins (deps check, `init/1`, register commands). `Dispatcher` gets initial model/commands. `Driver` starts `:rrex_termbox` NIF.
2. **Event**: `:rrex_termbox` NIF sends event message -> `Driver` translates -> `Event` -> `Dispatcher` (async).
3. **Update**: `Dispatcher` calls `Application.update/2` -> new model, commands.
4. **Command**: `Dispatcher` handles core cmds or routes to `PluginManager` (async) -> `CommandHelper` -> ETS lookup -> `Plugin.handle_command/3`.
5. **Render**: `Scheduler` triggers `RenderingEngine`. Engine gets model/theme from `Dispatcher` -> `Application.view/1` -> `LayoutEngine` (positions) -> `UIRenderer` (styled cells) -> `Terminal.Renderer` (diff output).
6. **Reload**: `PluginManager` -> `LifecycleHelper` -> unload/purge/recompile/load/reinit sequence.

## Recent Changes Summary

- **Major Refactoring:** Completed significant refactoring across core systems (Runtime, Plugins, Rendering), Terminal subsystem (Parser, Sixel, Driver, Control Codes), UI components (`Table`, `MultiLineInput` extraction), Visualization Plugin (extracted renderers), and support modules (Benchmarking, Cloud Monitoring, User Preferences, Accessibility integration).
- **Documentation Alignment:** Reviewed and updated key planning documents (`overview.md`, `handoff_prompt.md`, `Roadmap.md`), core documentation (`README.md`, `docs/README.md`), specific guides (`docs/guides/components/README.md`, `docs/development/terminal/README.md`), and architecture documentation (`ARCHITECTURE.md` sections, including codebase size).
- **Compiler Status:** Addressed numerous compilation errors and warnings during refactoring. However, some warnings persist and require further investigation and cleanup.
- **Key Component Updates:** `Table` component refactored to take data via attributes; `MultiLineInput` core logic extracted into helper modules; `Renderer` updated to handle `:table` directly.
- **Feature Enhancements:** Added basic navigation, clipboard, scrolling, selection to `MultiLineInput`; implemented RLE optimization for Sixel graphics.
- **Dependency Integration:** Adapted terminal handling to use `:rrex_termbox` v2.0.1 NIF API, resolving build issues and refactoring `Terminal.Driver`.
- **Testing:** Resolved numerous setup, configuration, and logic errors in `RaxolWeb.TerminalChannelTest`, significantly reducing failures.
- **Updated `lib/raxol/terminal/terminal_utils.ex` for NIF-based terminal dimension detection**
- **Redesigned `lib/raxol/terminal/constants.ex` to directly map to NIF constants**
- **Rewritten `lib/raxol/core/events/termbox_converter.ex` to handle NIF event format**
- **Updated `lib/raxol/test/mock_termbox.ex` to match the NIF-based interface for testing**

## Codebase Size & Refactoring Candidates

**Note:** LOC counts are approximate and based on `find . -type f \( -path './lib/*' -or -path './docs/*' \) -not -path '*/.git/*' -exec wc -l {} + | sort -nr`. Thresholds adjusted based on current distribution. Last updated: 2024-07-31

**Critical (> 1200 LOC):**

(None currently)

**Huge (900 - 1199 LOC):**

- `./docs/development/planning/performance/case_studies.md` (~999 lines)
- `./lib/raxol/plugins/plugin_manager.ex` (~962 lines)
- `./lib/raxol/docs/interactive_tutorial.ex` (~915 lines)

**Big (600 - 899 LOC):**

- `./lib/raxol/terminal/integration.ex` (~813 lines)
- `./lib/raxol/terminal/buffer/operations.ex` (~812 lines)
- `./lib/raxol/cloud/edge_computing.ex` (~795 lines)
- `./lib/raxol/docs/component_catalog.ex` (~695 lines)
- `./lib/raxol/terminal/command_executor.ex` (~680 lines)
- `./lib/raxol/components/progress.ex` (~663 lines)
- `./lib/raxol/terminal/driver.ex` (~632 lines) # Updated count
- `./lib/raxol/terminal/ansi/sixel_graphics.ex` (~628 lines) # Refactored
- `./lib/raxol/core/focus_manager.ex` (~617 lines)
- `./examples/snippets/typescript/visualization/ChartExample.ts` (~611 lines) # Example file
- `./lib/raxol/cloud/monitoring.ex` (~600 lines) # Refactored

**Notable Shrinkage:** Several files previously listed as "Big" have been significantly refactored or had content moved:

- `lib/raxol/terminal/parser.ex` (now ~345 lines) # Updated count
- `lib/raxol/style/colors/utilities.ex` (now ~225 lines)
- `lib/raxol/ui/components/display/table.ex` (now ~253 lines)

**Newly Extracted/Refactored Modules:** (Counts updated where available in top list)

- `./lib/raxol/plugins/visualization/chart_renderer.ex` (~168 lines)
- `./lib/raxol/plugins/visualization/treemap_renderer.ex` (~271 lines)
- `./lib/raxol/plugins/visualization/image_renderer.ex` (~62 lines)
- `./lib/raxol/plugins/visualization/drawing_utils.ex` (~140 lines)
- `./lib/raxol/components/input/multi_line_input/text_helper.ex` (~270 lines)
- `./lib/raxol/components/input/multi_line_input/navigation_helper.ex` (~270 lines)
- `./lib/raxol/components/input/multi_line_input/render_helper.ex` (~139 lines)
- `./lib/raxol/components/input/multi_line_input/event_handler.ex` (~148 lines)
- `./lib/raxol/components/input/multi_line_input/clipboard_helper.ex` (~68 lines)
- `./lib/raxol/terminal/ansi/sixel_palette.ex` (~81 lines)

## Module Overview

| Module Path                          | Status         | Description                                                                                                      |
| ------------------------------------ | -------------- | ---------------------------------------------------------------------------------------------------------------- |
| `lib/raxol/application.ex`           | Stable         | Main application entry point, starts the top-level supervisor.                                                   |
| `lib/raxol/runtime/supervisor.ex`    | Stable         | Top-level supervisor for the core application runtime (non-web). Starts `PluginManager`, `UserPreferences`, etc. |
| **Core Runtime**                     |                |                                                                                                                  |
| `lib/raxol/core/runtime/...`         |                | **Namespace for the core application runtime logic.**                                                            |
| `.../supervisor.ex`                  | Stable         | Supervisor for core runtime services (`EventLoop`, `RenderLoop`, `PluginManager`).                               |
| `.../application.ex`                 | Stable         | Defines the application behaviour (`init`, `handle_event`, `render`).                                            |
| `.../event_loop.ex`                  | Stable         | GenServer responsible for processing incoming events and updating application state.                             |
| `.../render_loop.ex`                 | Stable         | GenServer responsible for triggering application rendering and outputting to the driver.                         |
| `.../state_manager.ex`               | **Removed**    | ~~Manages the application's core state.~~                                                                        |
| `.../dispatcher.ex`                  | Stable         | Handles dispatching events to the correct handler (application, components).                                     |
| **Core Events**                      |                |                                                                                                                  |
| `lib/raxol/core/events/...`          |                | **Namespace for defining event types.**                                                                          |
| `.../event.ex`                       | Stable         | Defines the core `Event` struct.                                                                                 |
| `.../input_event.ex`                 | Stable         | Defines input-specific event types (key, mouse, paste).                                                          |
| `.../system_event.ex`                | Stable         | Defines system-level event types (resize, focus, signal).                                                        |
| `.../clipboard.ex`                   | **Removed**    | ~~Defines clipboard-related events.~~                                                                            |
| **Core Plugins**                     |                |                                                                                                                  |
| `lib/raxol/core/runtime/plugins/...` |                | **Namespace for the plugin system.**                                                                             |
| `.../plugin.ex`                      | Stable         | Defines the `Plugin` behaviour that plugins must implement.                                                      |
| `.../manager.ex`                     | Development    | GenServer responsible for loading, managing, and coordinating plugins. (Reloading added & tested)                |
| `.../registry.ex`                    | Stable         | Handles the storage and lookup of loaded plugins.                                                                |
| `.../dependency_solver.ex`           | Stable         | Resolves plugin load order based on declared dependencies.                                                       |
| `.../command_registry.ex`            | Stable         | ETS-based registry for commands declared by plugins.                                                             |
| `.../command_helper.ex`              | Stable         | Helper functions for registering and handling commands from plugins.                                             |
| `.../commands.ex`                    | **Removed**    | ~~GenServer for managing command registration (replaced by ETS).~~                                               |
| `lib/raxol/core/plugins/core/...`    |                | **Namespace for built-in core plugins.**                                                                         |
| `.../clipboard_plugin.ex`            | **Refactored** | Core plugin for clipboard read/write commands. (Uses `System.Clipboard`, Tests Pass)                             |
| `.../notification_plugin.ex`         | **Refactored** | Core plugin for sending system notifications. (Improved robustness)                                              |
| `.../filesystem_plugin.ex`           | Stable         | Core plugin providing file system interaction commands.                                                          |
| `lib/raxol/system/clipboard.ex`      | **New/Stable** | **Consolidated module for system clipboard interaction (macOS, Linux, Windows).**                                |
| **Terminal**                         |                |                                                                                                                  |
| `lib/raxol/terminal/...`             |                | **Namespace for terminal emulation and interaction.**                                                            |
| `.../driver.ex`                      | Stable         | Defines the behaviour for terminal drivers (TTY, Mock).                                                          |
| `.../drivers/tty.ex`                 | Stable         | Driver for interacting with a real TTY via stdin/stdout. Uses `:rrex_termbox` NIF.                               |
| `.../emulator.ex`                    | Stable         | Core terminal emulator logic (state, input processing, screen buffer). (Many fixes applied)                      |
| `.../screen_buffer.ex`               | Stable         | Manages the terminal screen buffer (grid, cells, attributes, scrollback). (Verified via Emulator fixes/tests)    |
| `.../cell.ex`                        | Stable         | Represents a single cell in the screen buffer.                                                                   |
| `.../parser.ex`                      | Stable         | Parses incoming byte streams into terminal commands/text.                                                        |
| `.../commands/executor.ex`           | Stable         | Executes parsed terminal commands, updating emulator state. (Core CSI handlers fixed, basic OSC/DCS)             |
| `.../commands/modes.ex`              | **Removed**    | ~~Handles terminal mode settings (DECSM, DECRM).~~ (Logic moved into `ScreenModes`)                              |
| `.../ansi/screen_modes.ex`           | Stable         | Manages ANSI/DEC screen mode state (Alt screen, wrap, cursor visibility, etc.). (Refactored, fixed)              |
| `.../ansi/terminal_state.ex`         | Stable         | Manages saving/restoring terminal state (cursor, style, modes). (Fixed)                                          |
| `.../ansi/text_formatting.ex`        | Stable         | Handles SGR attributes and text formatting (colors, styles, width). (Fixed)                                      |
| `.../cursor/manager.ex`              | Stable         | Manages cursor state (position, style, visibility).                                                              |
| `.../cursor/movement.ex`             | Stable         | Logic for calculating cursor movements.                                                                          |
| `.../clipboard.ex`                   | **Removed**    | ~~Handles clipboard interaction.~~                                                                               |
| `.../input_mapper.ex`                | Stable         | Maps raw input bytes/sequences to `InputEvent` structs.                                                          |
| `.../output_encoder.ex`              | Stable         | Encodes terminal commands (ANSI sequences) for output.                                                           |
| **UI Components**                    |                |                                                                                                                  |
| `lib/raxol/ui/components/...`        |                | **Namespace for reusable UI components.**                                                                        |
| `.../base/component.ex`              | Stable         | Defines the core `Component` behaviour (`init`, `handle_event`, `render`).                                       |
| `.../display/text.ex`                | Stable         | Simple text display component.                                                                                   |
| `.../display/progress.ex`            | Stable         | Progress bar component. (Tests fixed)                                                                            |
| `.../input/text_input.ex`            | Stable         | Single-line text input component. (Features added, tests fixed)                                                  |
| `.../input/checkbox.ex`              | Development    | Checkbox component.                                                                                              |
| `.../input/button.ex`                | Development    | Button component.                                                                                                |
| `.../layout/box.ex`                  | Stable         | Basic layout container component.                                                                                |
| `.../selection/list.ex`              | Stable         | List selection component. (Tests fixed)                                                                          |
| `.../selection/dropdown.ex`          | Stable         | Dropdown selection component. (Tests fixed)                                                                      |
| **Style & Theming**                  |                |                                                                                                                  |
| `lib/raxol/style/...`                |                | **Namespace for styling and theming.**                                                                           |
| `.../colors/color.ex`                | Stable         | Defines color representation and manipulation functions.                                                         |
| `.../colors/palette.ex`              | Stable         | Represents a theme's color palette.                                                                              |
| `.../colors/theme.ex`                | Stable         | Defines the `Theme` struct.                                                                                      |
| `.../colors/persistence.ex`          | Stable         | Handles saving/loading themes and preferences. (Fixed)                                                           |
| `.../colors/advanced.ex`             | Stable         | Advanced color operations (blending, harmonies). (Fixed)                                                         |
| `.../border.ex`                      | Stable         | Defines border styles.                                                                                           |
| `.../style_map.ex`                   | Stable         | Applies styles based on component state/type.                                                                    |
| **Platform Integration**             |                |                                                                                                                  |
| `lib/raxol/platform/...`             |                | **Namespace for platform-specific integrations.**                                                                |
| `.../notification.ex`                | Development    | Platform-agnostic notification interface.                                                                        |
| **VS Code Extension**                |                |                                                                                                                  |
| `lib/raxol_vscode/...`               |                | **Namespace for VS Code extension specific logic.**                                                              |
| `.../bridge.ex`                      | Stable         | Handles communication between Raxol core and the VS Code extension.                                              |
| **Web Interface (Phoenix)**          |                |                                                                                                                  |
| `lib/raxol_web/...`                  |                | **Namespace for the optional Phoenix web UI.**                                                                   |
| `.../live/terminal_live.ex`          | Stable         | Phoenix LiveView for rendering the terminal interface in a browser. (Tests fixed)                                |
| `.../endpoint.ex`                    | Development    | Phoenix endpoint configuration.                                                                                  |
| `.../router.ex`                      | Development    | Phoenix router configuration.                                                                                    |
| `.../channels/terminal_channel.ex`   | Stable         | Phoenix channel for terminal interaction. (Tests pass)                                                           |
| **Utilities & Helpers**              |                |                                                                                                                  |
| `lib/raxol/utils/...`                |                | **Namespace for general utility functions.**                                                                     |
| `lib/raxol/test/...`                 | Stable         | Test helpers and utilities.                                                                                      |
