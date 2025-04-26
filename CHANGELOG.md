# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2023-05-24

### Added

- Initial release of Raxol
- Terminal UI framework with web interface capabilities
- Core components library
- Visualization plugins
- Internationalization support
- Theme system

### Known Issues

- Various compiler warnings as documented in the CI logs

## [Unreleased] - YYYY-MM-DD

### Added

- **Project Foundation:** Initial structure, config, docs, CI/CD, dev env, quality tools, test framework.
- **Terminal Capabilities:** Emulation layer, ANSI processing, platform/feature detection (colors, mouse, etc.).
- **Buffer Management:** Double buffering, damage tracking, virtual scrolling, cursor management.
- **Plugin System:** Core API, configuration, dependency management, clipboard/notification plugins.
- **Enhanced ANSI Processing:** Advanced formatting, device status reports, screen modes, character sets.
- **Component System:** Refactored View DSL, dashboard/layout components, specialized widgets (Info, Chart, etc.), testing framework.
- **VS Code Extension Integration:** Communication protocol, WebView panel, JSON interface.
- **Database Improvements:** Connection management, error handling, diagnostics.
- **Testing Framework:** Test plan, scripts (VS Code/native), mock components, performance monitoring.
- **Dashboard/Visualization:** Widget positioning/resizing, layout persistence, responsive components, drag-and-drop, caching.
- **CI/CD Improvements:** Local testing (`act`), cross-platform enhancements, security scanning.
- **Theme System:** Multiple built-in themes, selection UI, customization API, persistence.
- **Core Features:** Added ID generation (`Core.ID`), preferences infrastructure (`Core.Preferences`), plugin registry/loader/command registry (`Core.Runtime.Plugins.*`).
- **Terminal Buffer Features:** Added modules for buffer operations, scrollback, and selection (`Terminal.Buffer.*`).
- **UI Components:** Added Table and SelectList components (`UI.Components.Display.Table`, `UI.Components.Input.SelectList`).
- **Testing Enhancements:** Added basic mouse event parsing tests (VT200, SGR) to `TerminalDriverTest`. Expanded `RuntimeTest` to better cover supervisor behavior and basic input-to-update flow.
- **Runtime Logic Implementation:**
  - Implemented basic plugin loading in `Raxol.Core.Runtime.Plugins.Loader`.
  - Removed unused `Registry`.
  - Implemented `Raxol.Core.Runtime.Plugins.CommandRegistry` using ETS.
  - Implemented core `Raxol.Core.Runtime.Plugins.Manager` logic (placeholder discovery, loading, event filtering via `handle_call`, command registration).
  - Implemented `Raxol.Core.Runtime.Events.Dispatcher` (GenServer managing application state/model, event routing, command execution via `Raxol.Core.Runtime.Command`, PubSub via `Registry`, `handle_cast` for event dispatch).
  - Implemented `Raxol.Core.Runtime.Application` behaviour delegation.
  - Reviewed `Raxol.Core.Runtime.Debug` (simple Logger wrapper).
  - Created `Raxol.Runtime` module skeleton to orchestrate runtime components.
  - Created `Raxol.Terminal.Driver` module skeleton (GenServer, raw mode setup via `stty`, basic IO subscription).
  - Completed basic input parsing (chars, arrows, Ctrl+C) and resize handling (`SIGWINCH`) in `Raxol.Terminal.Driver`.
  - Completed `Raxol.Runtime.main_loop` including event routing, resize handling, and quit signal processing.
  - Added `Raxol.Runtime.Supervisor` to manage core processes.
- **Core Plugins:** Created placeholder core plugins for Clipboard (`lib/raxol/core/plugins/core/clipboard_plugin.ex`) and Notifications (`lib/raxol/core/plugins/core/notification_plugin.ex`) to handle `:clipboard_write`, `:clipboard_read`, and `:notify` commands.
- **PluginManager Tests:** Created basic test file `test/raxol/core/runtime/plugins/manager_test.exs`.
- **Mock Plugins:** Created `mock_plugin_a.ex` and `mock_plugin_b.ex` in `priv/plugins` for testing.
- **PluginManager Test Setup:** Added `setup_all` and `on_exit` to `manager_test.exs` to manage mock plugin files and compilation for tests.
- **Basic PluginManager Tests:** Added tests for plugin loading and command registration verification in `manager_test.exs`.
- **PluginManager Reloading Tests:** Added comprehensive tests for plugin reloading (success, init failure, compile failure, non-existent plugin reload) in `test/raxol/core/runtime/plugins/manager_test.exs` using mocks.
- **PluginManager Dependency Tests:** Added tests for handling unmet and circular dependencies during initialization in `test/raxol/core/runtime/plugins/manager_test.exs`.
- **PluginManager Reload Edge Case Test:** Added test for state consistency when code purge fails during reload in `test/raxol/core/runtime/plugins/manager_test.exs`.
- **Dispatcher Interaction Tests:** Started adding tests for `Dispatcher` interactions with `Command`, `RenderingEngine`, and `PubSub` in `test/raxol/core/runtime/events/dispatcher_test.exs`.
- **View/Layout Macros:** Added `box/2` macro to `Raxol.View.Elements`.
- **Testing:** Added measurement tests for `:box`, `:checkbox`, `:panel`, and `:grid` elements in `LayoutEngineTest`.
- **MultiLineInput Features:** Implemented basic cursor navigation (arrows, line/doc start/end, page up/down, word left/right), clipboard integration (copy/cut/paste via commands), and scroll offset adjustment logic (`handle_scroll`, `ensure_cursor_visible`).
- **MultiLineInput Tests:** Added basic test coverage for `TextHelper`, `NavigationHelper`, `RenderHelper`, `EventHandler`, and `ClipboardHelper` modules.
- **Visualization Plugin Helpers:** Created `ChartRenderer`, `TreemapRenderer`, `ImageRenderer`, and `DrawingUtils` modules.
- **Terminal Config Utils:** Added `Config.Utils` module with deep merging logic (`lib/raxol/terminal/config/utils.ex`).
- **Sixel Support Modules:** Added `SixelPatternMap` and `SixelPalette` modules (`lib/raxol/terminal/ansi/sixel_pattern_map.ex`, `lib/raxol/terminal/ansi/sixel_palette.ex`).
- **Color System:** Created `Raxol.Core.ColorSystem` module for centralized theme/accessibility-aware color retrieval.
- **User Preferences:** Created `Raxol.Core.Preferences.Persistence` module for preference file handling.

### Changed

- **Architecture:** Improved modularity, configuration management, development workflow, documentation structure.
  - Completed comprehensive codebase reorganization following REORGANIZATION_PLAN.md
  - Refactored ANSI, Command Executor, Runtime, Layout, and Component modules
  - Implemented new directory structure with logical subsystems
  - Created detailed ARCHITECTURE.md documentation
  - **Refactored `lib/raxol/terminal/configuration.ex`**: Moved logic to dedicated modules (`Defaults`, `Profiles`, `AnimationCache`, `Validation`, `Pipeline`) and implemented missing color conversion utilities in `lib/raxol/ui/theming/colors.ex`, integrating them into `Profiles`.
- **Terminal Functionality:** Improved feature detection, refined ANSI processing, optimized config/memory.
  - **Input Parsing:** Implemented parsing in `TerminalDriver` for sequences covered by existing tests (F-keys, Home/End, PgUp/Dn, Del, Backspace, Tab, Enter, Esc, Ctrl+Arrows, Ctrl+Chars, VT200/SGR Mouse). Added parsing and tests for Alt+keys, Shift+Arrows, Focus In/Out, and Bracketed Paste mode.
- **Plugin System:** Improved initialization, dependency resolution, API versioning, maintainability.
  - Defined `Plugin` behaviour (`lib/raxol/core/runtime/plugins/plugin.ex`).
  - Implemented basic plugin discovery (from `priv/plugins/`), loading (`init/1`), and command registration (`get_commands/0`) in `PluginManager`.
  - Added `handle_command/3` callback to `Plugin` behaviour.
  - Implemented command lookup in `PluginManager` using `CommandRegistry`.
  - Refactored command delegation in `PluginManager` to call `handle_command/3`.
  - Implemented dependency sorting (topological sort) in `PluginManager`.
  - **Refactored `CommandRegistry` and `PluginManager` to support command namespaces and store arity.**
  - **Refactored `PluginManager`:** Extracted lifecycle logic into `LifecycleHelper` and command logic into `CommandHelper`.
  - **Implemented Basic Plugin Reloading:** Added logic to `LifecycleHelper.reload_plugin_from_disk/7` using `Code.purge`, `Code.compile_file`, etc. (with placeholder source path finding).
- **Runtime System:** Dual-mode operation (native/VS Code), conditional init, improved startup/error handling.
  - Ensured commands returned by `Application.update` are correctly routed and handled (`:quit` example verified).
- **Rendering Pipeline:** Refined rendering flow:
  - Integrated theme application into `Raxol.UI.Renderer`, using component-specific styles from `theme.component_styles` where available.
  - Implemented active theme management via application state in `Dispatcher`.
  - Updated `LayoutEngine` to pass `component_type` information and remove hardcoded styles for decomposed elements (`:button`, `:text_input`, etc.).
  - `RenderingEngine` now uses the active theme provided by `Dispatcher`.
  - **Implemented border rendering for `:box` elements in `Raxol.UI.Renderer` based on theme styles.**
  - Created `Raxol.UI.Renderer` module with basic `render_to_cells` implementation (handles `:text`, `:box` primitives).
  - Located `Raxol.UI.Theming.Theme` and using `Theme.get(:default)` as a placeholder for `Theme.current()`.
  - Refactored `Raxol.Core.Runtime.Rendering.Engine`:
    - Uses `Raxol.UI.Layout.Engine` for layout calculation.
    - Uses `Raxol.UI.Renderer` to convert positioned elements to cells.
    - Uses `IO.write` for basic terminal output.
    - Removed `@doc` from private functions.
  - Integrated components (`Manager`, `Dispatcher`, `Driver`, `RenderingEngine`) into `Raxol.Runtime` startup sequence.
  - Established basic event/render flow: `Driver` -> `Dispatcher` -> `Runtime` -> `RenderingEngine`.
  - Refactored `Raxol.Core.Runtime.Rendering.Engine` to fetch model from `Dispatcher` before rendering.
- **Project Structure:** Consolidated examples, dedicated frontend dir, normalized extensions, improved secrets/git handling.
- **Roadmap Documentation:** Updated files in `docs/roadmap/` (TODO, Timeline, Phases, NextSteps) to reflect current project status based on `CHANGELOG.md` and `handoff_prompt.md`.
- **Core Runtime Refactoring:** Moved core runtime modules (`Application`, `Debug`, `Events`, `Lifecycle`, `Plugins`, `Rendering`) under `lib/raxol/core/`. Removed obsolete `lib/raxol/runtime*` files.
- **Terminal Components Refactoring:** Reorganized modules within `lib/raxol/terminal/` (e.g., `ANSI`, `Commands`, `Config`, `Buffer`) and updated corresponding tests.
- **UI Components Update:** Updated various UI components (`Button`, `Checkbox`, `TextInput`, etc.) and related tests.
- **Examples & Scripts:** Updated example applications and run scripts to reflect refactoring.
- **Project Files:** Updated `README.md`, `CHANGELOG.md`, `mix.exs`.
- **Terminal IO:** Refactored `lib/raxol/terminal/driver.ex` to use `:os.cmd("stty ...")` for terminal raw mode setup and size detection, removing usage of deprecated `System.group_leader` and unreliable `IO.ioctl`.
- **Plugin System:** Added placeholder logic for `reload_plugin_from_disk/2` in `lib/raxol/core/runtime/plugins/manager.ex`, including TODOs for actual code purging and reloading.
- **View/Layout System:** Standardized on macros in `Raxol.View.Elements` for view definition. Removed redundant functions from `Raxol.View.Layout`.
- **Layout Engine:** Added placeholder `measure_element/2` function.
- Fixed core plugin behaviour implementation (added missing callbacks, corrected signatures and `@impl` annotations for `Plugin` behaviour).
- Removed duplicate core plugin files from `lib/raxol/plugins/core/`.
- Fixed calls to `CommandRegistry` functions (`new/0` vs `create_table/0`, `register_command/6` vs `/5`, `unregister_commands_by_module/2` vs `unregister_plugin_commands/2`).
- Added placeholder implementations for missing `Loader` functions (`discover_plugins/1`, `sort_plugins/1`, `extract_metadata/1`, `load_code/1`).
- Fixed issues in `Terminal.Driver`: replaced `IO.put_chars` with `IO.write`, fixed deprecated charlist syntax (`'stty -g'`), replaced `System.cmd` calls for `stty` with `:os.cmd` and removed associated type warnings.
- Fixed unreachable code warnings in `LifecycleHelper` and `CommandHelper` related to function return types (`Loader.load_code`, `Loader.sort_plugins`, `CommandRegistry.lookup_command`).
- Fixed call in `Rendering.Scheduler` to use `GenServer.cast` for triggering `Rendering.Engine` frame renders.
- Removed some unused variables, aliases, and functions across multiple modules (`Manager`, `CommandHelper`, `Driver`, `Renderer`).
- Addressed duplicate `@doc` warnings in `Application.ex`.
- Fixed cascading compilation errors following major refactoring:
  - Fixed `:rrex_termbox` dependency build failure due to Python 3.9+ incompatibility by patching its `waf` script.
  - Fixed multiple `(ArgumentError) cannot invoke @/1 outside module` errors in component files (`table.ex`, `progress.ex`, `modal.ex`, `hint_display.ex`, `focus_ring.ex`, `base.ex`) by ensuring `defmodule` is the first statement and removing problematic `@dialyzer` directives.
  - Fixed `undefined function` errors (`to_element/1`, `box/2`) in components (`spinner.ex`, `focus_ring.ex`, `dashboard.ex`, `widget_container.ex`) by adding missing `require` statements or `Raxol.Core.Renderer.View` module prefixes.
  - Fixed `module ... is not loaded` errors for `Raxol.View`, `Raxol.Component`, `Raxol.App`, `Raxol.Runtime.Plugin` in various components and examples by updating `use`, `require`, and `alias` statements to correct post-refactor paths (`Raxol.Core.Renderer.View`, `Raxol.UI.Components.Base.Component`, `Raxol.Core.Runtime.Application`, `Raxol.Core.Runtime.Plugins.Plugin`).
  - Fixed `UndefinedFunctionError ... __using__/1` by removing incorrect `use Raxol.Core.Runtime.Plugins.Plugin` from `ux_refinement_demo.ex`.
  - Project now compiles, but numerous unused code warnings remain.
- Fixed compilation errors related to missing `Raxol.Component` and `Raxol.View` modules by updating component files to use correct module paths (`Raxol.UI.Components.Base.Component`, `Raxol.Core.Renderer.View`). (Note: This revealed a new compilation error `(ArgumentError) cannot invoke @/1 outside module` in `lib/raxol/components/table.ex`.)
- Fixed compiler warnings and errors in multiple component and example files (`Dropdown`, `Button`, `Terminal`, `Modal`, `Base`, `WidgetContainer`, `TextInput`, `HintDisplay`, `MultiLineInput`, `Form`) by correcting behaviour implementations (`Component`, `Application`), updating module paths/aliases/imports (`View`, `Layout`, `Event`, `Style`, `Platform`), fixing function signatures/return values, removing unused code, and refactoring helper modules (`Modal`, `Base`, `WidgetContainer`) to remove incorrect component behaviour usage.
- Refactored `Lifecycle` module (`lib/raxol.ex`, `lib/raxol/core/runtime/lifecycle.ex`) to remove GenServer usage, fix undefined function calls, update aliases/paths, and remove obsolete VS Code StdioInterface logic.
- **Layout Engine:** Implemented measurement logic for `:panel`, `:grid`, and `:view` elements in `LayoutEngine`, replacing placeholders. Renamed measurement functions in `Panels` and `Grid` modules (to `measure_panel`, `measure_grid`) and updated call sites.
- **Terminal Parser:** Refactored `parse_loop` by extracting logic for each state into separate `handle_<state>_state` functions. Refactored `dispatch_csi` into category-specific sub-dispatcher functions (`dispatch_csi_graphics`, `dispatch_csi_scrolling`, etc.).
- **MultiLineInput Component:** Refactored core logic into helper modules (`TextHelper`, `NavigationHelper`, `RenderHelper`, `EventHandler`, `ClipboardHelper`) within `lib/raxol/components/input/multi_line_input/` to improve modularity. Implemented selection logic via Shift+Movement keys and basic mouse click handling.
- **UX Refinement Demo:** Updated `view` function to fetch hints dynamically based on focus using `UXRefinement` and `FocusManager`, and render the `HintDisplay` component accordingly.
- **Performance Benchmarks:** Refactored `lib/raxol/benchmarks/performance.ex` by extracting benchmark categories (Rendering, Event Handling, Memory Usage, Animation), validation logic, and reporting logic into separate modules within `lib/raxol/benchmarks/performance/`.
- **Cloud Monitoring:** Refactored `lib/raxol/cloud/monitoring.ex` by extracting nested modules (Metrics, Errors, Health, Alerts) into separate files within `lib/raxol/cloud/monitoring/`.
- **Terminal Parser:** Implemented placeholder functions (`handle_sgr`, `handle_set_scroll_region`, `handle_cursor_style`, `handle_device_status_report`) using logic derived from emulator state and standard terminal behavior.
- **Visualization Plugin:** Refactored by extracting rendering logic for charts, treemaps, and images into separate modules (`ChartRenderer`, `TreemapRenderer`, `ImageRenderer`) and shared drawing logic into `DrawingUtils`. Updated plugin to use `handle_placeholder` hook and delegate rendering.
- **Terminal Emulator:** Refactored by moving C0 control code handlers (LF, CR, BS, HT, SO, SI) and simple ESC sequence handlers (IND, NEL, HTS, RI, DECSC, DECRC, RIS) to `ControlCodes`. Extracted autowrap logic into a private helper.
- **Terminal Integration:** Refactored `lib/raxol/terminal/integration.ex` by extracting memory management (`MemoryManager`) and config update logic (using `Config.Utils`), removing obsolete helpers.
- **Sixel Graphics:** Partially refactored `lib/raxol/terminal/ansi/sixel_graphics.ex`: Extracted pattern mapping (`SixelPatternMap`), palette initialization (`SixelPalette`). Sketched stateful parser (`ParserState`, `parse_sixel_data`) and implemented parameter parsing for core commands (`"`, `#`, `!`). Removed old parser logic. Implemented basic `render_image/1` structure and `generate_pixel_data/4` logic (without RLE optimization).
- **Dashboard Component:** Implemented `render/2` function in `Raxol.Components.Dashboard.Dashboard` to use `UI.grid` and `UI.grid_item` for layout based on state.
- **Color System Integration:** Refactored `Raxol.Style.Theme` to support variants with distinct color palettes. Refactored `Raxol.Core.Accessibility.ThemeIntegration` to manage high-contrast state via process dictionary and remove hardcoded palettes. Updated `Theme.create_high_contrast_variant`.
- **User Preferences System:** Refactored `Raxol.Core.UserPreferences` GenServer to use the new `Persistence` module, implement structured defaults, support nested key access (`get/1`, `set/2`), and add automatic saving with delay.
- **Documentation:** Updated `docs/ARCHITECTURE.md` to reflect latest structure, module statuses, and refactoring efforts.
- **User Preferences Integration**: Integrated `UserPreferences` loading/saving into core modules (`Accessibility`, `ThemeIntegration`, `Dispatcher`, `ColorSystem`) for persisting theme and accessibility settings. Refactored modules to read settings from `UserPreferences` instead of process dictionary.
- **Sixel Graphics Optimization**: Implemented Run-Length Encoding (RLE) in `SixelGraphics.generate_pixel_data/4` to optimize the output size of Sixel image data by compressing repeated character sequences.

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods
- `Raxol.Terminal.CommandHistory` (Use `Raxol.Terminal.Commands.History` instead)

### Removed

- Outdated configuration files and dependencies
- Redundant documentation
- Legacy terminal handling code
- `use Raxol.Component` from helper modules
- Deprecated `Raxol.Terminal.CommandHistory` module and associated tests (`lib/raxol/terminal/command_history.ex`, `test/raxol/terminal/command_history_test.exs`).
- **(Current Date - YYYY-MM-DD):** Pruned obsolete files and directories after core refactoring, including top-level `lib/raxol/runtime.ex`, `lib/raxol/application.ex`, `lib/raxol/renderer.ex`, `lib/raxol/view.ex`, `lib/raxol/theme.ex`, `lib/raxol/theme_config.ex`, `lib/raxol/component.ex`, `lib/raxol/components.ex`, `lib/raxol/plugin.ex`, `lib/raxol/event.ex`, `lib/raxol/focus.ex`, `lib/raxol/accessibility.ex`, `lib/raxol/stdio_interface.ex`, `lib/raxol/my_app.ex`, `lib/raxol/app.ex`, backup test files (`test/terminal/*.bak*`), and `erl_crash.dump`. (Note: Many potentially obsolete directories like `lib/raxol/plugins/`, `lib/raxol/style/`, `lib/raxol/database/`, `lib/raxol/web/`, `lib/raxol/cloud/`, etc. remain and require further investigation.)
- Redundant layout functions from `lib/raxol/view/layout.ex`.
- Various unused functions and aliases across multiple modules (`lifecycle.ex`, `terminal.ex`, `dashboard/widgets/*.ex`, `progress_bar.ex`, `multi_line_input.ex`).

### Fixed

- Numerous fixes across core system stability, components, database connections, VS Code integration, runtime issues, CI/CD, ANSI processing, and test suites (details below).
- Fixed compilation errors in `lib/raxol/core/runtime/plugins/command_helper.ex`: resolved missing `end` keyword, replaced invalid `elif` with `else if`, and refactored conditional logic to use `cond`.
- Fixed compilation errors in core plugin modules (`notification_plugin.ex`, `clipboard_plugin.ex`, `notify_plugin.ex`) by removing incorrect `use Raxol.Core.Runtime.Plugins.Plugin` statements.
- Fixed compilation errors (`undefined variable state`, `undefined variable rest`) in `lib/raxol/terminal/driver.ex` by refactoring the `parse_loop/2` function to correctly handle return values and remove internal event dispatching logic.
- Fixed core compilation error (`module Event is not loaded`) in `lib/raxol/core/runtime/events/dispatcher.ex` by correcting the `require` statement.\*\*
- Fixed compile error (`undefined function return/1`) and unused variable warnings (`_final_queue`, `_plugin_id`, `_cycles`) in `lib/raxol/core/runtime/plugins/manager.ex`.\*\*
- Addressed all remaining compiler warnings and errors, including previously blocking issues related to cyclic dependencies and ungrouped clauses.\*\*
- Addressed compiler errors and warnings:
  - Fixed syntax errors (`pass`, invalid map syntax) and an invalid match error in `PluginManager`.
  - Fixed undefined function errors (`&&&`) in `TerminalDriver` by importing `Bitwise`.
  - Addressed warnings for unused variables/aliases (`config`, `plugin_module`, `CommandRegistry`, `TerminalDriver`, `Cell`, `element`).
  - Resolved unreachable clause warnings in `Dispatcher`.
  - Attempted to fix ungrouped clause warnings and private `@doc` warnings (edits failed, requires manual fix).
  - Added `require Event` in `Dispatcher` (did not fix struct expansion error, likely cyclic dependency).
- Fixed cascading compilation errors originating in `manager.ex` and `driver.ex` involving mismatched delimiters, invalid `cond` usage, incorrect binary matching, missing aliases, and function header defaults.
- Refactored showcase and advanced examples:
  - Updated `examples/showcase/architecture_demo.exs`
- Resolved cascading compilation errors by fixing cyclic dependencies (changing `Event` struct expansion to map matching in component `handle_event`
