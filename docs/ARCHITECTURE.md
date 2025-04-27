---
title: Raxol Architecture
description: Overview of the Raxol system architecture
date: 2024-06-25
author: Raxol Team
section: documentation
tags: [architecture, documentation, design]
---

# Raxol Architecture

Overview of the Raxol architecture after the recent reorganization and refactoring.

_Last updated: 2024-06-25_ # Updated Date

## Overview

Raxol is organized into logical subsystems:

1. **Core**: Fundamental runtime, application lifecycle, plugin system, event dispatch, and rendering orchestration.
2. **UI**: Component model (`Base.Component` behaviour), layout engine, rendering logic, and theming.
3. **Terminal**: Low-level terminal driver (input/output, raw mode, ANSI parsing, Sixel support).
4. **View**: DSL (`Elements` macros) for defining UI structures.
5. **Support Modules**: Benchmarking, Cloud integration (partially refactored).

## Directory Structure

```bash
lib/raxol/
├── benchmarks/            # Performance benchmarks (Refactored)
│   └── performance/       # Extracted benchmark categories
├── cloud/                 # Cloud integration modules
│   └── monitoring/        # Extracted monitoring sub-modules (Refactored)
├── core/                  # Core runtime, application, plugins, events, rendering
│   ├── runtime/
│   │   ├── application.ex # Application behaviour definition
│   │   ├── dispatcher.ex  # Event/Command routing & State management
│   │   ├── plugins/       # Plugin Manager, Loader, Helpers, Registry
│   │   └── rendering/     # Rendering Engine & Scheduler
│   └── ...
├── plugins/
│   └── visualization/     # Visualization Plugin Renderers & Helpers (New)
│       ├── chart_renderer.ex
│       ├── treemap_renderer.ex
│       ├── image_renderer.ex
│       └── drawing_utils.ex
├── ui/                    # Components, Layout, Rendering, Theming
│   ├── components/        # UI Components (implementing Base.Component)
│   │   ├── base/
│   │   ├── display/
│   │   └── input/
│   │       └── multi_line_input/ # MultiLineInput Helpers
│   │           ├── text_helper.ex
│   │           ├── navigation_helper.ex
│   │           ├── render_helper.ex
│   │           ├── event_handler.ex
│   │           └── clipboard_helper.ex
│   ├── layout/            # Layout Engine (measure/position)
│   ├── renderer.ex        # Converts elements to styled cells
│   └── theming/           # Theme definitions and application
├── terminal/              # Terminal I/O and ANSI Processing
│   ├── ansi/              # ANSI sequence modules (Charsets, ScreenModes, etc.)
│   │   ├── sixel_graphics.ex # Stateful sixel parser
│   │   ├── sixel_palette.ex  # Sixel palette management (Extracted)
│   │   └── sixel_pattern_map.ex # Sixel pattern mapping (Extracted)
│   ├── buffer/            # ScreenBuffer logic
│   ├── cursor/            # Cursor management
│   ├── driver.ex          # Raw mode, Input parsing, Output writing
│   ├── emulator.ex        # Terminal state management (Refactored)
│   ├── parser.ex          # Main parser state machine
│   │   └── states/        # Individual state handlers for the parser
│   ├── control_codes.ex   # C0/Simple ESC handlers (Refactored)
│   └── ...
└── view/                  # View Definition DSL
    └── elements.ex        # Macros for UI elements (box, text, etc.)
```

## Core Subsystems & Status

- **Runtime System (`Core.Runtime.*`)**: Manages application lifecycle (`Application` behaviour), event dispatch (`Dispatcher`), plugin management (`Plugins.Manager`), and rendering orchestration (`Rendering.Engine`). **Largely functional, tested.**
- **Plugin System (`Core.Runtime.Plugins.*`)**: Handles plugin discovery, loading (`Loader`), lifecycle (`LifecycleHelper`), command registration/execution (`CommandHelper`, `CommandRegistry`), and reloading. **Functional, tested.**
- **Event Handling (`Terminal.Driver`, `Core.Runtime.Events.Dispatcher`)**: `Driver` parses input, sends events to `Dispatcher`. `Dispatcher` manages state and routes events/commands to `Application` or `PluginManager`. **Functional.**
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions (measurement logic implemented for core elements), `Renderer` converts to styled cells using active theme, `Terminal.Renderer` outputs diff to terminal. **Functional, tested.**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `update/2`, `handle_event/3`, `render/2`) and use `View.Elements` macros. **Refactoring ongoing; `MultiLineInput` refactored into helpers, multiple core components updated.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored into sub-modules. **Refactored.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules (Metrics, Errors, Health, Alerts). **Refactored.**
- **Compiler Warnings**: Project compiles cleanly with `--warnings-as-errors`.
- **Terminal Parser (`Terminal.Parser`):** Refactored `parse_loop` by extracting logic for each state into separate `handle_<state>_state` functions. Refactored `dispatch_csi` into category-specific sub-dispatcher functions. **Implemented placeholders for SGR, DECSTBM, DECSCUSR, DSR.**
- **Sixel Graphics (`Terminal.ANSI.SixelGraphics`):** Extracted pattern map and palette logic. Stateful parser implemented with parameter parsing for key commands. **RLE optimization implemented.**
- **MultiLineInput Component (`UI.Components.Input.MultiLineInput`):** Core logic refactored into helper modules (`Text`, `Navigation`, `Render`, `Event`, `Clipboard`). Basic navigation, clipboard, scroll, selection, and basic mouse handling implemented. Basic tests added. **Refactored, Enhanced.**
- **Visualization Plugin (`Plugins.VisualizationPlugin`):** Extracted rendering logic into helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`). Core plugin now delegates rendering via `handle_placeholder`. **Refactored.**
- **Terminal Emulator (`Terminal.Emulator`):** Primarily manages terminal state (buffers, cursor, modes, charsets, etc.). C0/simple ESC sequence handling moved to `ControlCodes`. Autowrap logic extracted into helper. **Refactored.**
- **User Preferences (`Core.Preferences.*`)**: Manages user preference loading, saving, and access. Integrated with core modules (`Accessibility`, `ThemeIntegration`, `Dispatcher`, `ColorSystem`). **Functional, Integrated.**

## Key Modules

| Module                                         | Description                                                          | Status             |
| ---------------------------------------------- | -------------------------------------------------------------------- | ------------------ |
| `Raxol.Core.Runtime.Application`               | Defines the application behaviour (init, update, view)               | Defined            |
| `Raxol.Core.Runtime.Events.Dispatcher`         | Manages application state, routes events/commands                    | Functional         |
| `Raxol.Core.Runtime.Plugins.Manager`           | Manages plugin lifecycle, command execution, reloading               | Functional, Tested |
| `Raxol.Core.Runtime.Rendering.Engine`          | Orchestrates rendering: App -> Layout -> Renderer -> Terminal        | Functional         |
| `Raxol.UI.Components.Base.Component`           | Base behaviour for UI components                                     | Defined, Adopted   |
| `Raxol.UI.Layout.Engine`                       | Calculates element positions                                         | Functional, Tested |
| `Raxol.UI.Renderer`                            | Converts layout elements to styled terminal cells using active theme | Functional         |
| `Raxol.UI.Theming.Theme`                       | Theme data structure and retrieval                                   | Functional         |
| `Raxol.Terminal.Driver`                        | Handles terminal input/output, raw mode, basic parsing               | Functional         |
| `Raxol.Terminal.Emulator`                      | Manages terminal state (buffers, cursor, modes, etc.)                | Refactored         |
| `Raxol.Terminal.Parser`                        | Main parser state machine and state handlers                         | Refactored         |
| `Raxol.Terminal.ControlCodes`                  | Handles C0 and simple ESC control codes                              | Refactored         |
| `Raxol.Terminal.ANSI.SixelGraphics`            | Stateful Sixel graphics parser with RLE optimization                 | Refactored, Opt.   |
| `Raxol.View.Elements`                          | Macros (`box`, `text`, etc.) for defining UI views                   | Defined, Used      |
| `Raxol.Plugins.VisualizationPlugin`            | Handles visualization placeholders, delegates rendering              | Refactored         |
| `Raxol.Plugins.Visualization.ChartRenderer`    | Helper for rendering chart visualizations                            | Added              |
| `Raxol.Plugins.Visualization.TreemapRenderer`  | Helper for rendering treemap visualizations                          | Added              |
| `Raxol.Plugins.Visualization.ImageRenderer`    | Helper for rendering image visualizations                            | Added              |
| `Raxol.Plugins.Visualization.DrawingUtils`     | Shared drawing helpers for visualization                             | Added              |
| `Raxol.UI.Components.Input.MultiLineInput.*`   | Helper modules for `MultiLineInput` component                        | Added              |
| `Raxol.Terminal.Integration/memory_manager.ex` | Helper for memory management in Terminal Integration                 | Added              |
| `Raxol.Terminal.Config/utils.ex`               | Utilities for terminal configuration merging                         | Added              |
| `Raxol.Core.Preferences.Persistence`           | Handles preference file I/O                                          | Added              |
| `Raxol.Core.ColorSystem`                       | Centralized theme/accessibility-aware color retrieval                | Added              |
| `Raxol.Core.Accessibility.ThemeIntegration`    | Connects accessibility settings with themes                          | Refactored         |
| `Raxol.Core.UserPreferences`                   | GenServer for managing user preferences state                        | Refactored         |

## Plugin System

- **Lifecycle**: Discovery (`Loader`), sorting (`LifecycleHelper`), `init/1`, `terminate/2`.
- **Commands**: Register via `get_commands/0` (namespaced), handled by `handle_command/3`, efficient lookup via ETS (`CommandRegistry`).
- **Metadata**: Optional `PluginMetadataProvider` behaviour for `id`, `version`, `dependencies`. Used by `Loader`/`LifecycleHelper`.
- **Reloading**: `LifecycleHelper.reload_plugin_from_disk/8` unloads, purges code, recompiles source, reloads, reinitializes, handling failures.
- **Core Plugins**: `ClipboardPlugin`, `NotificationPlugin` in `lib/raxol/core/plugins/core/`.
- **Visualization Plugin**: Uses `handle_placeholder` hook to render charts, treemaps, images via helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`).

## Efficient Runtime Flow

1. **Init**: Supervisor starts processes. `PluginManager` discovers, sorts, loads plugins (deps check, `init/1`, register commands). `Dispatcher` gets initial model/commands. `Driver` sets up terminal.
2. **Event**: `Driver` parses input -> `Event` -> `Dispatcher` (async).
3. **Update**: `Dispatcher` calls `Application.update/2` -> new model, commands.
4. **Command**: `Dispatcher` handles core cmds or routes to `PluginManager` (async) -> `CommandHelper` -> ETS lookup -> `Plugin.handle_command/3`.
5. **Render**: `Scheduler` triggers `RenderingEngine`. Engine gets model/theme from `Dispatcher` -> `Application.view/1` -> `LayoutEngine` (positions) -> `UIRenderer` (styled cells) -> `Terminal.Renderer` (diff output).
6. **Reload**: `PluginManager` -> `LifecycleHelper` -> unload/purge/recompile/load/reinit sequence.

## Recent Changes Summary (from handoff)

- Core runtime, plugin lifecycle, command handling, rendering pipeline functional/refactored.
- Multiple components refactored to use `Base.Component` behaviour and `View.Elements` macros.
- Measurement logic implemented and tested in `LayoutEngine`.
- Numerous compiler warnings fixed (unused code, duplicates, macro usage, behaviour implementations). Project compiles cleanly.
- Resolved specific errors: duplicate `Application` behaviour, syntax errors (`SingleLineInput`, `ux_refinement_demo`), cyclic dependencies (`Spinner`, others via map matching).
- Refactored `Benchmarks.Performance` and `Cloud.Monitoring` into sub-modules.
- Refactored `VisualizationPlugin` into core plugin and helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`).
- Refactored `Terminal.Emulator` (moved C0/ESC to `ControlCodes`, extracted autowrap).
- Refactored `Terminal.Parser` (extracted state handlers and CSI dispatchers).
- Refactored `Terminal.Integration` (extracted `MemoryManager`, updated config merging).
- Refactored `Terminal.ANSI.SixelGraphics` (extracted `SixelPalette`, `SixelPatternMap`; implemented stateful parser and parameter handling).
- Refactored `MultiLineInput` into core component and helper modules (`TextHelper`, `NavigationHelper`, `RenderHelper`, `EventHandler`, `ClipboardHelper`).
- Added features to `MultiLineInput`: basic navigation, clipboard, scrolling, selection, mouse clicks.
- Added basic tests for `MultiLineInput` helpers.
- Integrated `UserPreferences` loading/saving into core modules (`Accessibility`, `ThemeIntegration`, `Dispatcher`, `ColorSystem`).
- Implemented Run-Length Encoding (RLE) optimization in `SixelGraphics`.
- Focus: Continue refactoring large modules, implement core UX features (Animation, i18n), enhance component tests, address remaining placeholders (`MultiLineInput` mouse drag, Sixel rendering refinements).

## Codebase Size & Refactoring Candidates

**Note:** LOC counts are approximate and reflect state after recent refactoring.

**Critical (> 1500 LOC):**

(None currently)

**Huge (1000 - 1499 LOC):**

(None currently)

**Big (500 - 999 LOC):**

- `./docs/performance/case_studies.md` (999 lines)
- `./docs/examples/integration_example.md` (915 lines)
- `./lib/raxol/terminal/integration.ex` (811 lines) # Refactored
- `./lib/raxol/terminal/parser.ex` (896 lines) # Refactored
- `./lib/raxol/cloud/edge_computing.ex` (795 lines)
- `./lib/raxol/style/colors/utilities.ex` (791 lines)
- `./lib/raxol/terminal/ansi/sixel_graphics.ex` (591 lines) # Refactored
- `./lib/raxol/docs/interactive_tutorial.ex` (701 lines)
- `./lib/raxol/docs/component_catalog.ex` (695 lines)
- `./test/raxol/core/renderer/views/performance_test.exs` (690 lines)
- `./lib/raxol/terminal/command_executor.ex` (680 lines)
- `./lib/raxol/core/runtime/plugins/manager.ex` (730 lines)
- `./lib/raxol/components/table.ex` (662 lines)
- `./lib/raxol/core/focus_manager.ex` (617 lines)
- `./test/raxol/core/renderer/views/integration_test.exs` (605 lines)
- `./lib/raxol/terminal/character_sets.ex` (602 lines)
- `./lib/raxol/components/dashboard/dashboard.ex` (599 lines)
- `./frontend/docs/troubleshooting.md` (587 lines)
- `./lib/raxol/benchmarks/visualization_benchmark.ex` (578 lines)
- `./lib/raxol/terminal/buffer/manager.ex` (577 lines)
- `./lib/raxol/components/progress.ex` (574 lines)
- `./lib/raxol/cloud/integrations.ex`

**Newly Extracted/Refactored Modules:**

- `./lib/raxol/plugins/visualization/chart_renderer.ex` (~168 lines)
- `./lib/raxol/plugins/visualization/treemap_renderer.ex` (~244 lines)
- `./lib/raxol/plugins/visualization/image_renderer.ex` (~63 lines)
- `./lib/raxol/plugins/visualization/drawing_utils.ex` (~139 lines)
- `./lib/raxol/components/input/multi_line_input/text_helper.ex` (~200 lines)
- `./lib/raxol/components/input/multi_line_input/navigation_helper.ex` (~130 lines)
- `./lib/raxol/components/input/multi_line_input/render_helper.ex` (~100 lines)
- `./lib/raxol/components/input/multi_line_input/event_handler.ex` (~80 lines)
- `./lib/raxol/components/input/multi_line_input/clipboard_helper.ex` (~70 lines)
- `./lib/raxol/terminal/ansi/sixel_palette.ex` (~90 lines)
- `./lib/raxol/terminal/ansi/sixel_pattern_map.ex` (~60 lines)
- `./lib/raxol/terminal/control_codes.ex` (~150 lines)
- `./lib/raxol/terminal/integration/memory_manager.ex` (~50 lines)
- `./lib/raxol/terminal/config/utils.ex` (~40 lines)

**Test Files (New/Extracted):**

- `./test/raxol/terminal/emulator/screen_modes_test.exs` (~200 lines)
- `./test/raxol/terminal/emulator/character_sets_test.exs` (~81 lines)
- `./test/raxol/terminal/emulator/initialization_test.exs` (~95 lines)
- `./test/raxol/terminal/emulator/writing_buffer_test.exs` (~86 lines)
- `./test/raxol/terminal/emulator/cursor_management_test.exs` (~35 lines)
- `./test/raxol/terminal/emulator/state_stack_test.exs` (~111 lines)
- `./test/raxol/terminal/emulator/getters_setters_test.exs` (~69 lines)
- `./test/raxol/terminal/emulator/sgr_formatting_test.exs` (~210 lines)
- `./test/raxol/terminal/emulator/process_input_test.exs` (~80 lines)
- `./test/raxol/terminal/emulator/csi_editing_test.exs` (~258 lines)
- `./test/raxol/terminal/emulator/response_test.exs` (~63 lines)
- `./test/raxol/components/input/multi_line_input/text_helper_test.exs` (~135 lines)
- `./test/raxol/components/input/multi_line_input/navigation_helper_test.exs` (~235 lines)
- `./test/raxol/components/input/multi_line_input/render_helper_test.exs` (~156 lines)
- `./test/raxol/components/input/multi_line_input/event_handler_test.exs` (~176 lines)
- `./test/raxol/components/input/multi_line_input/clipboard_helper_test.exs` (~161 lines)
- `./test/support/emulator_helpers.ex` (~29 lines)
