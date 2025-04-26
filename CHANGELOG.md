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

## [Unreleased] - 2024-06-05

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
- **Runtime System:** Dual-mode operation (native/VS Code), conditional init, improved startup/error handling.
- **Rendering Pipeline:** Refined rendering flow:
  - Integrated theme application into `Raxol.UI.Renderer`, using component-specific styles from `theme.component_styles` where available.
  - Implemented active theme management via application state in `Dispatcher`.
  - Updated `LayoutEngine` to pass `component_type` information and remove hardcoded styles for decomposed elements (`:button`, `:text_input`, etc.).
  - `RenderingEngine` now uses the active theme provided by `Dispatcher`.
- **Project Structure:** Consolidated examples, dedicated frontend dir, normalized extensions, improved secrets/git handling.
- **Roadmap Documentation:** Updated files in `docs/roadmap/` (TODO, Timeline, Phases, NextSteps) to reflect current project status based on `CHANGELOG.md` and `handoff_prompt.md`.
- **Core Runtime Refactoring:** Moved core runtime modules (`Application`, `Debug`, `Events`, `Lifecycle`, `Plugins`, `Rendering`) under `lib/raxol/core/`. Removed obsolete `lib/raxol/runtime*` files.
- **Terminal Components Refactoring:** Reorganized modules within `lib/raxol/terminal/` (e.g., `ANSI`, `Commands`, `Config`, `Buffer`) and updated corresponding tests.
- **UI Components Update:** Updated various UI components (`Button`, `Checkbox`, `TextInput`, etc.) and related tests.
- **Examples & Scripts:** Updated example applications and run scripts to reflect refactoring.
- **Project Files:** Updated `README.md`, `CHANGELOG.md`, `mix.exs`.

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

### Fixed

- Numerous fixes across core system stability, components, database connections, VS Code integration, runtime issues, CI/CD, ANSI processing, and test suites (details below).
- **(Current Date - YYYY-MM-DD):** Addressed compiler errors and warnings:
  - Fixed syntax errors (`pass`, invalid map syntax) and an invalid match error in `PluginManager`.
  - Fixed undefined function errors (`&&&`) in `TerminalDriver` by importing `Bitwise`.
  - Addressed warnings for unused variables/aliases (`config`, `plugin_module`, `CommandRegistry`, `TerminalDriver`, `Cell`, `element`).
  - Resolved unreachable clause warnings in `Dispatcher`.
  - Attempted to fix ungrouped clause warnings and private `@doc` warnings (edits failed, requires manual fix).
  - Added `require Event` in `Dispatcher` (did not fix struct expansion error, likely cyclic dependency).
- **(Current Date - YYYY-MM-DD):** Fixed cascading compilation errors originating in `manager.ex` and `driver.ex` involving mismatched delimiters, invalid `cond` usage, incorrect binary matching, missing aliases, and function header defaults.
- **(Current Date - YYYY-MM-DD):** Refactored showcase and advanced examples:
  - Updated `examples/showcase/architecture_demo.exs` to use `Runtime.start_application`.
  - Updated `examples/advanced/commands.exs` to use `Runtime.start_application`.
  - Updated `examples/advanced/documentation_browser.exs` to use `Runtime.start_application`.
  - Updated `examples/advanced/snake.exs` to use `Runtime.start_application`.
  - Updated `examples/advanced/editor.exs` to use `Runtime.start_application`.
  - Skipped outdated `plugin_demo.exs` and non-application examples.
- **(Current Date - YYYY-MM-DD):** Refactored remaining basic examples:
  - Updated `examples/basic/rendering.exs` to use `Runtime.start_application`.
  - Updated `examples/basic/subscriptions.exs` to use `Runtime.start_application`.
  - Updated `examples/basic/multiple_views.exs` to use `Runtime.start_application`.
- **(Current Date - YYYY-MM-DD):** Added basic tests and refactored first example:
  - Created basic test suite for `TerminalDriver` (`driver_test.exs`), covering init, input parsing (chars, arrows, ctrl+c, buffering), SIGWINCH, and terminate.
  - Created basic test suite for `Runtime` (`runtime_test.exs`), covering `start_application` success/failure and basic supervisor/process checks.
  - Refactored `examples/basic/counter.exs` to use `Application` behaviour and `Runtime.start_application`.
- **(Current Date - YYYY-MM-DD):** Implemented core runtime loop and input/rendering flow:
  - Implemented initial terminal size query and SIGWINCH handling in `TerminalDriver`.
  - Implemented basic input parsing (chars, arrows, Ctrl+C) with buffering in `TerminalDriver`.
  - Completed basic `Runtime` main loop logic (event routing, resize, quit handling).
  - Refactored `RenderingEngine` to fetch the latest model from `Dispatcher` before rendering.
  - Introduced `Runtime.Supervisor` to manage core processes (`PluginManager`, `Dispatcher`, `RenderingEngine`, `TerminalDriver`).
- **(Current Date - YYYY-MM-DD):** Organized progress into logical commits. Addressed numerous compiler warnings encountered during refactoring and committing:
  - Fixed unreachable clauses in `plugins/manager.ex` by adjusting pattern matching for placeholder `load_plugin/2` return value.
  - Addressed various undefined function errors by correcting module paths/aliases (e.g., `Raxol.Terminal.Renderer`) or commenting out temporarily broken logic (e.g., `process_view` in `rendering/engine.ex`).
- **(Current Date - YYYY-MM-DD):** Addressed numerous compiler warnings:
  - Removed unused variables, aliases, functions (e.g., in `Rendering.Engine`, `Emulator`, UI components).
  - Fixed incorrect function calls & module references (e.g., `CommandExecutor`, `ANSIFacade`, `ANSI`, UI components `Style/Theme/Element` calls).
  - Corrected typing violations (keyboard event data access, unreachable clauses in `parser.ex`, `config/application.ex`, `plugins/manager.ex`).
  - Created placeholder `Raxol.Core.ID` module and updated components.
  - Created placeholder runtime modules (`Application`, `Debug`, `Loader`, `Registry`, `CommandRegistry`) and functions (`subscribe`, `broadcast`, `filter_event`, `update`, `get_env`, etc.) based on remaining warnings.
- **(Current Date - YYYY-MM-DD):** Fixed `@impl` and `@behaviour` mismatches in UI components (`Table`, `Checkbox`, `TextField`, `TextInput`):
  - Corrected `@behaviour Component` to `@behaviour Raxol.UI.Components.Base.Component`.
  - Replaced incorrect `@impl Component` with `@impl true` for implemented callbacks.
  - Added missing `@impl true` annotations for callbacks.
  - Added placeholder implementations for missing required callbacks (`render/2`, `handle_event/3`, `update/2`) in `TextField` and `TextInput`.
  - Fixed resulting compilation errors (undefined `elem/3`, unused variables, ungrouped clauses).
- **(Current Date - YYYY-MM-DD):** Fixed `TokenMissingError` in `lib/raxol/terminal/config/application.ex` caused by a missing `end`. Addressed several "unused function" warnings by prefixing function names with underscores and removing related `@dialyzer` directives (in `lib/raxol/terminal/emulator.ex`, `lib/raxol/ui/components/display/table.ex`, `lib/raxol/terminal/command_executor.ex`, `lib/raxol/terminal/ansi/processor.ex`).
- **(Current Date - YYYY-MM-DD):** Addressed multiple categories of compiler warnings:
  - Replaced deprecated `Logger.warn/1` with `Logger.warning/2` across multiple files.
  - Removed numerous unused aliases across the codebase (multiple iterations).
  - Fixed syntax errors related to alias definitions and heredoc termination.
  - Commented out imports of potentially non-existent modules (`ProcessUtils`, `FileUtils`) in `configuration.ex`.
  - Prefixed unused variables with `_` in `text_input.ex`, `containers.ex`, `config/application.ex`.
- **(Current Date - YYYY-MM-DD):** Fixed Theme Selector functionality and related theme handling:
  - Added `list_themes/0`, `get_theme_by_name/1`, and `apply_theme/1` functions to `lib/raxol/style/theme.ex`.
  - Updated `lib/raxol/ui/theming/selector.ex` to use the new theme functions.
  - Corrected `:background_color` key to `:background` in example themes within `lib/raxol/style/theme.ex`.
  - Resolved associated compilation warnings.
- **(Current Date - YYYY-MM-DD):** Addressed compilation warnings related to command execution refactoring:
  - Created placeholder module `lib/raxol/terminal/commands/executor.ex`.
  - Added placeholder functions (`execute_csi_command/4`, `execute_osc_command/2`, `execute_dcs_command/5`) to the new Executor module.
  - Updated alias in `lib/raxol/terminal/parser.ex` to point to the new Executor.
  - Updated delegation in deprecated `lib/raxol/terminal/command_executor.ex` to call the new Executor module.
  - Resolved compilation warnings related to undefined `Executor`
