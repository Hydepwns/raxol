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

_Last updated: 2024-07-17_ # Updated Date

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
- **Rendering Pipeline (`Core.Runtime.Rendering.Engine`, `UI.Layout.Engine`, `UI.Renderer`, `Terminal.Renderer`)**: `Engine` gets view from `Application`, `LayoutEngine` calculates positions (measurement logic implemented for core elements), `Renderer` converts to styled cells using active theme (now includes direct handling for `:table` elements), `Terminal.Renderer` outputs diff to terminal. **Functional, tested.**
- **Component System (`UI.Components.*`)**: Components implement `UI.Components.Base.Component` behaviour (`init/1`, `update/2`, `handle_event/3`, `render/2`) and use `View.Elements` macros. **Refactoring ongoing; `MultiLineInput` refactored into helpers, `Table` refactored to return raw map for `Renderer`, multiple core components updated.**
- **Theming (`UI.Theming.*`, `UI.Renderer`)**: Defines and applies styles. Integrated into `Renderer`. **Functional.**
- **Benchmarking (`Benchmarks.*`)**: Initial performance benchmark structure refactored into sub-modules. **Refactored.**
- **Cloud Monitoring (`Cloud.Monitoring.*`)**: Monitoring module refactored into sub-modules (Metrics, Errors, Health, Alerts). **Refactored.**
- **Compiler Warnings**: Project compiles successfully, but **numerous warnings remain** related to unused aliases/variables, potential API mismatches (especially around Accessibility), type issues, and deprecated calls. Needs cleanup.
- **Terminal Parser (`Terminal.Parser`):** Refactored `parse_loop` by extracting logic for each state into separate `handle_<state>_state` functions. Refactored `dispatch_csi` into category-specific sub-dispatcher functions. **Implemented placeholders for SGR, DECSTBM, DECSCUSR, DSR.**
- **Sixel Graphics (`Terminal.ANSI.SixelGraphics`):** Extracted pattern map and palette logic. Stateful parser implemented with parameter parsing for key commands. **RLE optimization implemented.**
- **MultiLineInput Component (`UI.Components.Input.MultiLineInput`):** Core logic refactored into helper modules (`Text`, `Navigation`, `Render`, `Event`, `Clipboard`). Basic navigation, clipboard, scroll, selection, and basic mouse handling implemented. Basic tests added. **Refactored, Enhanced.**
- **Visualization Plugin (`Plugins.VisualizationPlugin`):** Extracted rendering logic into helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`). Core plugin now delegates rendering via `handle_placeholder`. **Refactored.**
- **Terminal Emulator (`Terminal.Emulator`):** Primarily manages terminal state (buffers, cursor, modes, charsets, etc.). C0/simple ESC sequence handling moved to `ControlCodes`. Autowrap logic extracted into helper. **Refactored.**
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
| `Raxol.Terminal.Driver`                        | Handles terminal input/output, raw mode, basic parsing                                          | Functional         |
| `Raxol.Terminal.Emulator`                      | Manages terminal state (buffers, cursor, modes, etc.)                                           | Refactored         |
| `Raxol.Terminal.Parser`                        | Main parser state machine and state handlers                                                    | Refactored         |
| `Raxol.Terminal.ControlCodes`                  | Handles C0 and simple ESC control codes                                                         | Refactored         |
| `Raxol.Terminal.ANSI.SixelGraphics`            | Stateful Sixel graphics parser with RLE optimization                                            | Refactored, Opt.   |
| `Raxol.View.Elements`                          | Macros (`box`, `text`, etc.) for defining UI views                                              | Defined, Used      |
| `Raxol.Plugins.VisualizationPlugin`            | Handles visualization placeholders, delegates rendering                                         | Refactored         |
| `Raxol.Plugins.Visualization.ChartRenderer`    | Helper for rendering chart visualizations                                                       | Added              |
| `Raxol.Plugins.Visualization.TreemapRenderer`  | Helper for rendering treemap visualizations. Uses `DrawingUtils`.                               | Added              |
| `Raxol.Plugins.Visualization.ImageRenderer`    | Helper for rendering image visualizations                                                       | Added              |
| `Raxol.Plugins.Visualization.DrawingUtils`     | Shared drawing helpers (`draw_box_borders`, `draw_text_centered/3`, `draw_text/4`, `put_cell`). | Added              |
| `Raxol.UI.Components.Input.MultiLineInput.*`   | Helper modules for `MultiLineInput` component                                                   | Added              |
| `Raxol.UI.Components.Display.Table`            | Displays tabular data. `render/2` returns map for `Renderer`. Needs testing/validation.         | Refactored         |
| `Raxol.Terminal.Integration/memory_manager.ex` | Helper for memory management in Terminal Integration                                            | Added              |
| `Raxol.Terminal.Config/utils.ex`               | Utilities for terminal configuration merging                                                    | Added              |
| `Raxol.Core.Preferences.Persistence`           | Handles preference file I/O                                                                     | Added              |
| `Raxol.Core.ColorSystem`                       | Centralized theme/accessibility-aware color retrieval                                           | Added              |
| `Raxol.Core.Accessibility.ThemeIntegration`    | Connects accessibility settings (read via `UserPreferences`) with themes                        | Refactored         |
| `Raxol.Core.UserPreferences`                   | GenServer for managing user preferences state (reads/writes via `Persistence`)                  | Refactored         |
| `Raxol.Core.Accessibility`                     | Core accessibility logic (announcements, setters). Options read via `UserPreferences`.          | Refactored         |

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
- **`Table` component refactored:** `render/2` now returns a map for `Renderer`, internal helpers removed.
- **`Renderer` updated:** Now handles `:table` elements directly.
- Measurement logic implemented and tested in `LayoutEngine`.
- **Compiler status:** Project compiles, but **numerous warnings exist** (Accessibility API, unused code, type issues).
- Resolved specific errors: duplicate `Application` behaviour, syntax errors (`SingleLineInput`, `ux_refinement_demo`), cyclic dependencies (`Spinner`, others via map matching).
- Refactored `Benchmarks.Performance` and `Cloud.Monitoring` into sub-modules.
- Refactored `VisualizationPlugin` into core plugin and helper modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, `DrawingUtils`).
- Corrected calls to `DrawingUtils` in `TreemapRenderer`.
- Refactored `Terminal.Emulator` (moved C0/ESC to `ControlCodes`, extracted autowrap).
- Refactored `Terminal.Parser` (extracted state handlers and CSI dispatchers).
- Refactored `Terminal.Integration` (extracted `MemoryManager`, updated config merging).
- Refactored `Terminal.ANSI.SixelGraphics` (extracted `SixelPalette`, `SixelPatternMap`; implemented stateful parser and parameter handling).
- Refactored `MultiLineInput` into core component and helper modules (`TextHelper`, `NavigationHelper`, `RenderHelper`, `EventHandler`, `ClipboardHelper`).
- Added features to `MultiLineInput`: basic navigation, clipboard, scrolling, selection, mouse clicks.
- Added basic tests for `MultiLineInput` helpers.
- Integrated `UserPreferences` loading/saving into core modules. Calls to `Accessibility` options updated to use `UserPreferences`.
- Implemented Run-Length Encoding (RLE) optimization in `SixelGraphics`.
- Focus: **Address remaining compiler warnings**, test `Table` rendering, continue refactoring large modules, implement core UX features (Animation, i18n), enhance component tests, address remaining placeholders (`MultiLineInput` mouse drag, Sixel rendering refinements).

## Codebase Size & Refactoring Candidates

**Note:** LOC counts are approximate and based on `find . -type f \( -path './lib/*' -or -path './docs/*' \) -not -path '*/.git/*' -exec wc -l {} + | sort -nr`. Thresholds adjusted based on current distribution. Last updated: YYYY-MM-DD (Update this date).

**Critical (> 1200 LOC):**

(None currently)

**Huge (900 - 1199 LOC):**

- `./docs/development/planning/performance/case_studies.md` (~999 lines)
- `./lib/raxol/plugins/plugin_manager.ex` (~962 lines)
- `./docs/development/planning/examples/integration_example.md` (~915 lines)

**Big (600 - 899 LOC):**

- `./lib/raxol/terminal/integration.ex` (~813 lines)
- `./lib/raxol/terminal/buffer/operations.ex` (~812 lines)
- `./lib/raxol/cloud/edge_computing.ex` (~795 lines)
- `./lib/raxol/docs/interactive_tutorial.ex` (~701 lines)
- `./lib/raxol/docs/component_catalog.ex` (~695 lines)
- `./lib/raxol/terminal/command_executor.ex` (~680 lines)
- `./lib/raxol/components/progress.ex` (~663 lines)
- `./lib/raxol/terminal/ansi/sixel_graphics.ex` (~628 lines) # Refactored
- `./lib/raxol/terminal/driver.ex` (~618 lines)
- `./lib/raxol/core/focus_manager.ex` (~617 lines)
- `./docs/guides/examples/typescript/visualization/ChartExample.ts` (~611 lines) # Example file
- `./lib/raxol/cloud/monitoring.ex` (~600 lines) # Refactored

**Notable Shrinkage:** Several files previously listed as "Big" have been significantly refactored or had content moved:

- `lib/raxol/terminal/parser.ex` (now ~244 lines)
- `lib/raxol/style/colors/utilities.ex` (now ~225 lines)
- `lib/raxol/ui/components/display/table.ex` (now ~253 lines)

**Newly Extracted/Refactored Modules:**

- `./lib/raxol/plugins/visualization/chart_renderer.ex` (~168 lines)
- `./lib/raxol/plugins/visualization/treemap_renderer.ex` (~271 lines) # Updated
- `./lib/raxol/plugins/visualization/image_renderer.ex` (~62 lines)
- `./lib/raxol/plugins/visualization/drawing_utils.ex` (~140 lines)
- `./lib/raxol/components/input/multi_line_input/text_helper.ex` (~270 lines)
- `./lib/raxol/components/input/multi_line_input/navigation_helper.ex` (~246 lines)
- `./lib/raxol/components/input/multi_line_input/render_helper.ex` (~135 lines)
- `./lib/raxol/components/input/multi_line_input/event_handler.ex` (~148 lines)
- `./lib/raxol/components/input/multi_line_input/clipboard_helper.ex` (~68 lines)
- `./lib/raxol/terminal/ansi/sixel_palette.ex` (~81 lines)
- `./lib/raxol/terminal/ansi/sixel_pattern_map.ex` (~131 lines)
- `./lib/raxol/terminal/control_codes.ex` (~231 lines)
- `./lib/raxol/terminal/memory_manager.ex` (~87 lines)
- `./lib/raxol/terminal/config/utils.ex` (~70 lines)

**Test Files (New/Extracted):**

- `./test/raxol/terminal/emulator/screen_modes_test.exs` (~200 lines) # Example - update counts if needed
- `./test/raxol/terminal/emulator/character_sets_test.exs` (~81 lines) # Example - update counts if needed
- `./test/raxol/terminal/emulator/initialization_test.exs` (~95 lines)
- `./test/raxol/terminal/emulator/writing_buffer_test.exs` (~86 lines)
- `./test/raxol/terminal/emulator/cursor_management_test.exs` (~35 lines)
- `./test/raxol/terminal/emulator/state_stack_test.exs` (~111 lines)
- `./test/raxol/terminal/emulator/getters_setters_test.exs` (~69 lines)
- `./test/raxol/terminal/emulator/sgr_formatting_test.exs` (~210 lines)
- `./test/raxol/terminal/emulator/process_input_test.exs` (~80 lines)
- `./test/raxol/terminal/emulator/csi_editing_test.exs` (~258 lines)
- `./test/raxol/terminal/emulator/response_test.exs` (~63 lines)
- `./test/raxol/components/input/multi_line_input/text_helper_test.exs` (~135 lines) # Example - update counts if needed
- `./test/raxol/components/input/multi_line_input/navigation_helper_test.exs` (~235 lines) # Example - update counts if needed
- `./test/raxol/components/input/multi_line_input/render_helper_test.exs` (~156 lines) # Example - update counts if needed
- `./test/raxol/components/input/multi_line_input/event_handler_test.exs` (~176 lines) # Example - update counts if needed
- `./test/raxol/components/input/multi_line_input/clipboard_helper_test.exs` (~161 lines) # Example - update counts if needed
- `./test/support/emulator_helpers.ex` (~29 lines) # Example - update counts if needed
