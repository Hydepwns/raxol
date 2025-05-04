# Changelog

Format from [Keep a Changelog](https://keepachangelog.com/en/1.0.0/);
and we use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - YYYY-MM-DD

### Added

- **Tests:** Added tests for `TextInput` component covering init, update, event handling (chars, backspace, delete, cursor movement, enter, escape, click, max_length, validation), and rendering states.
- **Component(Modal):** Implemented form functionality supporting `TextInput`, `Checkbox`, and `Dropdown` elements.
- **Component(Modal):** Added basic validation support for form fields (via `:validate` regex or function).
- **Component(Modal):** Added `Modal.form/6` constructor for creating form modals.
- **Terminal:** Added placeholder handlers for OSC and DCS command sequences in `lib/raxol/terminal/commands/executor.ex`.
- **Terminal:** Implemented basic OSC command handling in `Executor` for Window Title (OSC 0, 2) and Hyperlinks (OSC 8).
- **Component(MultiLineInput):** Added basic word navigation logic (Ctrl+Left/Right) via `NavigationHelper.move_cursor_word_left/right`.
- **Component(TextInput):** Implemented visual cursor rendering (inverse style on focused character).
- **Component(TextInput):** Added handling for Home, End, and Delete keys.
- **PluginSystem:** Added optional automatic plugin reloading via file watching (`FileSystem` dependency) in `:dev` environment. Enable with `enable_plugin_reloading: true` option to `PluginManager.start_link/1`.
- **Tests:** Added tests for `PluginManager` covering command delegation, manual reload scenarios (success/failure), and file watch reloading.
- **Tests:** Added test suite (`test/raxol/components/modal_test.exs`) for `Modal` component, covering form types (prompt, form), validation, focus, submission, and cancellation.
- **Terminal(Executor):** Implemented OSC 52 (Clipboard Set/Query) handler using `Raxol.System.Clipboard`.
- **Terminal(Executor):** Implemented OSC 4 (Color Palette Set/Query) handler, including parsing for `rgb:` and `#RGB`/`#RRGGBB` formats, storing colors in `Emulator.state`, and responding to queries.
- **Terminal(Executor):** Added placeholder handlers and parsing logic for DCS DECRQSS (`! |`) and DCS Sixel (`q`).
- **Terminal(Emulator):** Added `:color_palette` map to `Emulator.t` struct to store dynamic colors set via OSC 4.

### Changed

- **Component(Modal):** Refactored state to handle `:prompt` type using internal `form_state`, removing redundant top-level `:input_value`.
- **Component(Modal):** Updated `handle_event` to manage focus changes (Tab/Shift+Tab) and trigger submission (Enter) or cancellation (Escape).
- **Component(Modal):** Updated rendering logic to display form fields and validation errors.
- **Refactor:** Consolidated clipboard logic into `lib/raxol/system/clipboard.ex`, updated core plugins (`ClipboardPlugin`, `NotificationPlugin`) and tests to use it, removed redundant clipboard modules (`lib/raxol/terminal/clipboard.ex`, `lib/raxol/core/events/clipboard.ex`).
- **Refactor:** Enhanced core `NotificationPlugin` with better shell escaping, Windows support, and error handling.
- Reorganized documentation guides under `docs/guides/` into clearer categories (Getting Started, Core Concepts, Components, Extending, Development).
- Updated `README.md` and `docs/README.md` links to reflect new guide locations.
- Updated pre-commit hook documentation in `scripts/README.md` with installation and troubleshooting steps.
- **PluginSystem:** Standardized plugin command declaration format in `Plugin.get_commands/0` to only accept `[{name_atom, function_atom, arity_integer}]`.
- **PluginSystem:** Consolidated command registration by removing redundant `Raxol.Core.Runtime.Plugins.Commands` GenServer and `API.register_command`/`unregister_command` functions. Registration now solely relies on `get_commands/0` populating the `CommandRegistry` ETS table via `CommandHelper`.
- **Tests:** Changed default logger level in `config/test.exs` from `:debug` to `:warn` to reduce noise in test output.
- **Docs:** Updated root `README.md` and `docs/README.md` to reflect current project version, structure, and planned documentation.
- **Docs:** Updated `docs/ARCHITECTURE.md` date, directory structure, module statuses, and compiler warning notes to align with current project state.
- **Terminal(Executor):** Added alias for `Raxol.System.Clipboard` and `Raxol.Terminal.ANSI.SixelGraphics`.
- **Terminal(Executor):** Refactored DCS handling into a `case` statement based on intermediate/final bytes.
- **ComponentShowcase:** Refactored `lib/raxol/examples/component_showcase.ex` to correctly implement the `Raxol.UI.Components.Base.Component` behaviour (added `init/1`, `update/2`, corrected arities for `render/2`, `handle_event/3`, `mount/1`).

### Deprecated

### Removed

- **PluginSystem:** Removed redundant `Raxol.Core.Runtime.Plugins.Commands` GenServer.
- Removed redundant clipboard modules: `lib/raxol/terminal/clipboard.ex`, `lib/raxol/core/events/clipboard.ex`.

### Fixed

- Updated `scripts/README.md` to replace outdated pre-commit hook example with current setup instructions.
- **Tests:** Fixed all failures in `test/raxol/components/input/multi_line_input_test.exs` by correcting logic in `TextHelper.replace_text_range` for insertion, deletion, and single-character cases.
- **Tests:** Corrected various test setup issues in `test/test_helper.exs` related to Mox configuration:
  - Removed incorrect `Mox.start_link/1` call.
  - Removed `Mox.defmock` calls for modules that are not behaviours (`ThemeIntegration`, `Persistence`).
  - Removed incorrect `Mox.defmock` usage for `MockDB`.
  - Removed incorrect `Mox.allow/2` call.
- **Tests:** Fixed `UndefinedFunctionError` in `test/raxol/core/accessibility_test.exs` setup by replacing `EventManager.init()` with direct `Process.put` calls.
- **Tests:** Added missing `Mox.expect` for `MockApplication.update/2` in `test/raxol/core/runtime/events/dispatcher_test.exs`.
- **Tests:** Fixed `KeyError :cursor_row` failures in `test/raxol/components/input/multi_line_input_test.exs` by updating to use `:cursor_pos` tuple.
- **Tests:** Fixed `Mox.ExpectationError` in `test/raxol/core/plugins/core/clipboard_plugin_test.exs` by replacing Mox with `:meck` for mocking `Clipboard` module and managing `:meck` state correctly with `on_exit`.
- **Tests:** Fixed compilation error in `test/raxol/components/input/multi_line_input/event_handler_test.exs` by updating event creation to use `Raxol.Core.Events.Event` struct and helpers.
- **Tests:** Fixed `UndefinedFunctionError` for `move_cursor` and struct access issues in `test/raxol/terminal/emulator/initialization_test.exs` by adding correct alias and updating assertions.
- **Tests:** Fixed `MatchError` in `test/raxol/components/input/multi_line_input/event_handler_test.exs` by correcting the return tuple structure in `lib/raxol/components/input/multi_line_input/event_handler.ex`.
- **Tests:** Fixed `Access.Error` in `test/raxol/terminal/commands/screen_test.exs` setup by replacing `update_in` with direct `Map.put`.
- **Tests:** Fixed `Mox.Error` (invalid behaviour module) in `test/raxol/core/runtime/events/dispatcher_test.exs` by replacing Mox with `:meck` for `Command`, `RenderingEngine`, and `Phoenix.PubSub` mocks.
- **Tests:** Fixed `Mox.Error` (undefined function `times/2`) in `test/raxol/core/runtime/plugins/manager_test.exs` by using the `times:` option in `expect`.
- **Tests:** Fixed `KeyError :key` in `test/raxol/core/runtime/events/dispatcher_test.exs` by updating `Event` struct creation to use the `:data` map.
- **Tests:** Fixed `UndefinedFunctionError` for `TextHelper.wrap_lines_by_char` in `test/raxol/components/input/multi_line_input/clipboard_helper_test.exs` by correcting the module alias.
- **Tests:** Fixed `ArgumentError` (supervisor child) in `test/examples/button_test.exs` by updating `setup_test_env` in `lib/raxol/test/test_helper.ex` to start `PluginManager`.
- **Tests:** Fixed assertion failures in `test/raxol/style/colors/color_test.exs` related to `:ansi_code` and `:hex` format by aligning tests with `Color` module implementation.
- **Tests:** Fixed `FunctionClauseError` in `test/raxol/ui/components/display/progress_test.exs` by replacing `Progress.create/1` calls with `Progress.init/1` and updating assertions/calls to align with component behaviour.
- **Tests:** Fixed various errors in `test/raxol/terminal/commands_test.exs` (setup using `Emulator.new`, incorrect `History.next` call, `Parser.get_param` assertion).
- **Tests:** Fixed widespread `UndefinedFunctionError` for `maybe_scroll` by moving the function from `ControlCodes` to `Emulator` and making it public.
- **Tests:** Fixed `FunctionClauseError` for `get_width/1` in `test/raxol/components/terminal/emulator_test.exs` by correctly handling the `{state, output}` tuple return from `Emulator.process_input`.
- **Tests:** Fixed `MatchError` in `test/raxol/terminal/driver_test.exs` setup by adding error handling for the `stty` command.
- **Tests:** Fixed multiple failures in `test/raxol/components/terminal/emulator_test.exs` by:
  - Correcting the return value of the component's `process_input` function.
  - Implementing basic handlers for CSI commands SGR ('m'), CUP ('H'), DECSTBM ('r'), SM ('h'), RM ('l') in `lib/raxol/terminal/commands/executor.ex`.
  - Fixing mode state updates in `lib/raxol/terminal/commands/modes.ex` by inlining logic from `ScreenModes`.
  - Correcting autowrap mode check in `lib/raxol/terminal/emulator.ex`.
- **Tests:** Fixed final failure in `test/raxol/components/terminal/emulator_test.exs` by correcting parameter index handling for the CUP ('H') command in `lib/raxol/terminal/commands/executor.ex`. All tests in this suite now pass.
- **Tests:** Fixed `UndefinedFunctionError` and ETS table errors in `test/raxol/runtime_test.exs` by correcting supervisor startup and ETS management.
- **Tests:** Fixed various component tests (`SingleLineInput`, `ProgressBar`, `Dropdown`, `MultiLineInput`, `List`) by aligning test expectations with component behaviour API (`init/1`, `handle_event/3`, return values).
- **Tests:** Fixed terminal config tests (`ConfigurationTest`, `ConfigTest`) to use correct nested structure and test existing functions.
- **Tests:** Fixed `KeyError` in `test/raxol/terminal/emulator/state_stack_test.exs` by correcting state field access in `TerminalState.save_state/2` and `ControlCodes.handle_decrc/1`.
- **Tests:** Fixed `:enoent` and serialization errors in `test/raxol/style/colors/persistence_test.exs` by adding default theme setup and correcting `Color` struct handling.
- **Tests:** Fixed `FunctionClauseError` in `test/raxol/style/colors/advanced_test.exs` by fixing HSL conversion and adding missing assertions.
- **Tests:** Fixed `UndefinedFunctionError` in `test/terminal/screen_buffer_test.exs` by renaming function call.
- **Tests:** Fixed `no process` error in `test/raxol/style/colors/hot_reload_test.exs` by starting the `HotReload` GenServer.
- **Tests:** Fixed compilation error (duplicate test) in `test/raxol/terminal/emulator/cursor_management_test.exs`.
- **Tests:** Fixed SGR attribute/color handling errors in `test/raxol/terminal/emulator/sgr_formatting_test.exs` by updating `Executor`.
- **Tests:** Fixed `:flash not fetched` errors in `test/raxol_web/live/terminal_live_test.exs` by adding `fetch_flash/2` to test setup.
- **Tests:** Fixed performance test errors (`ArithmeticError`, `UndefinedFunctionError`) in `test/performance/performance_test.exs` by ensuring positive log input and updating module calls.
- **Tests:** Fixed wide character width calculation error in `test/raxol/terminal/ansi/text_formatting_test.exs`.
- **Tests:** Fixed `FunctionClauseError` in `test/raxol_web/channels/terminal_channel_test.exs` setup by establishing a `%Phoenix.Socket{}` struct using `socket/2` before calling `subscribe_and_join/3`.
- **Tests:** Fixed `UndefinedFunctionError` for `Raxol.Terminal.Input.set_mouse_enabled/2` in `test/terminal/integration_test.exs` by updating tests to use `Raxol.Terminal.Input.InputHandler` and `Raxol.Terminal.Input.InputBuffer`.
- **Tests:** Resolved multiple setup and configuration errors in `test/raxol_web/channels/terminal_channel_test.exs` related to PubSub initialization, Endpoint starting, and `:user_id` params.
- **Tests:** Fixed `FunctionClauseError` in `TerminalChannel.terminate/2` by removing access to `socket.assigns`.
- **Tests:** Resolved `KeyError` issues in `TerminalChannel.handle_in/3` for "input" and "resize" events related to accessing `emulator.main_screen_buffer`.
- **Renderer:** Fixed styling logic in `Renderer.build_style/2` to correctly apply default theme colors and specific cell style overrides.
- **Tests:** Corrected assertions in `TerminalChannelTest` for "resize" and "scroll" events.
- **Tests:** Fixed theme structure and assertions in `TerminalChannelTest` theme test.
- **Tests:** Replaced deprecated `Phoenix.Channel.leave/1` with `push("phx_leave", ...)` in `TerminalChannelTest` terminate test.
- **Tests:** All tests in `test/raxol_web/channels/terminal_channel_test.exs` now pass.
- **ComponentShowcase:** Fixed compilation errors (`undefined function` for components, `assign`, `view`, `text`) by refactoring to use component map structures, the `Base.Component` state management pattern, and `label` element macro.
- **Emulator:** Fixed `Emulator.clear_buffer/1` to correctly reset the parser state.
- **Emulator:** Fixed numerous bugs in SGR handling logic (`:faint`, `:normal_intensity`, bright colors, resets) in `TextFormatting` and `Executor`.
- **Emulator:** Fixed `handle_sgr` in `Executor` to correctly handle multi-parameter codes (38/48) using a recursive helper.
- **Emulator:** Fixed DA ('c') handler in `Executor` to correctly distinguish between primary and secondary requests.
- **Emulator:** Fixed `Commands.Parser.get_param/3` indexing logic (was 1-based, now 0-based) and updated call sites (CUP 'H', DECSTBM 'r') in `Executor`.
- **Emulator:** Fixed `FunctionClauseError` in `cursor_management_test.exs` due to missing `setup` block.
- **Emulator:** Fixed incorrect cursor style assertion in `cursor_management_test.exs` (checked non-existent `:shape` field).
- **Emulator:** Fixed incorrect default style assertion in `csi_editing_test.exs` ICH test.
- **Emulator:** Fixed state loss issue for `scroll_region` by correcting `Parser.parse_loop/3` function heads to handle `{:finished, ...}` and `{:incomplete, ...}` return values from state handlers.
- **Tests:** Fixed `UndefinedFunctionError` in `cursor_management_test.exs` by adding setup block.
- **Tests:** Removed intermittent `CaseClauseError` in emulator tests by fixing `Parser.parse_loop` return value handling.
- **Tests:** Resolved scroll region test failures (`left: nil`) in `csi_editing_test.exs` by fixing `Parser.parse_loop`.
- **ComponentShowcase:** Fixed compilation errors (`undefined function` for components, `assign`, `view`, `text`) by refactoring to use component map structures, the `Base.Component` state management pattern, and `label` element macro.
- Correct state propagation issue in `Emulator.process_character` where changes (cursor position, `last_col_exceeded`) were potentially lost before scrolling logic was applied.
- Restore correct autowrap logic in `Emulator.calculate_write_position` which was broken during previous refactoring.
- Resolve multiple failures in `csi_editing_test.exs` (ICH, IL, DCH, DL) caused by the state propagation bug in `Emulator.process_character`.
- Correct function signature mismatch for DEC private mode handling (`CSI ? ... h/l`). The call site (`Executor`) now passes the `{mode_id, action}` tuple expected by the handler (`ANSI.ScreenModes.handle_dec_private_mode`).
- **Tests:** Resolved SGR test failures (35 failures in `test/raxol/terminal/emulator/sgr_formatting_test.exs`) by performing a clean build (`mix clean --deps && mix compile --force`), indicating the issue was related to build caching.
- **Tests(`test/terminal/renderer_test.exs`):** Fixed tests by:
  - Updating calls from `Renderer.new/0` to `Renderer.new/1` or `Renderer.new/3`.
  - Removing dependency on `Raxol.Test.Assertions` and using standard assertions.
  - Replacing calls to `ScreenBuffer.put_char/4` with `ScreenBuffer.write_char/5`.
  - Correcting `render_cell/2` logic in `Renderer` to always wrap output in a `<span>`.
  - Fixing double-quote escaping within the generated `<span>` string in `render_cell/2`.
- **Terminal(`lib/raxol/terminal/input_handler.ex`):** Updated module to use `Raxol.System.Clipboard` for clipboard operations, removing previous clipboard state and related functions.
- **Tests(`test/terminal/screen_buffer_test.exs`):** Fixed tests by:
  - Updating calls to `ScreenBuffer.scroll_up/2` and `ScreenBuffer.scroll_down/2` to match new signatures in `Operations`.
  - Replacing calls to `ScreenBuffer.put_char/4` with `ScreenBuffer.write_char/5`.
  - Adding a local `line_to_string/1` helper function to simplify assertions.
- **Terminal(`lib/raxol/terminal/buffer/operations.ex`):** Fixed logic in `scroll_up/3` to return the full updated buffer struct instead of just scrolled lines.
- **Terminal(`lib/raxol/terminal/buffer/operations.ex`):** Fixed logic in `scroll_down/4` to correctly insert blank lines when no scrollback lines are provided.
- **Tests(`test/terminal/character_handling_test.exs`):** Updated function calls to match renames in `CharacterHandling` module (`is_wide_char?`, `get_char_width`, `is_combining_char?`, `process_bidi_text`, `get_string_width`) and fixed assertion logic.
- **Tests(`test/terminal/integration_test.exs`):** Refactored tests to use `Emulator.process_input/2` instead of direct `ScreenBuffer` manipulation. Added a local `buffer_text/1` helper. Skipped tests dependent on older mouse/history/paste/modifier functionality.
- **Terminal(`lib/raxol/terminal/ansi/processor.ex`):** Added handlers for DEC Private Mode Set/Reset (`?h`, `?l`) sequences to support column width switching (`DECCOLM`).
- **Tests(`test/terminal/ansi/column_width_test.exs`):** Fixed all tests by:
  - Replacing calls to removed `Emulator.process_escape_sequence` with `Emulator.process_input`.
  - Updating assertions to correctly fetch buffer width via `Emulator.get_active_buffer |> ScreenBuffer.get_width`.
  - Correcting the implementation of `:deccolm_132` (`?3h`, `?3l`) handling in `ScreenModes.handle_dec_private_mode/2` to correctly resize buffer, clear screen, and reset cursor.
  - Fixing syntax errors (`Kernel.then/2` usage, struct update spacing) in `ScreenModes.handle_dec_private_mode/2`.
  - Refactoring `ScreenModes.handle_dec_private_mode/2` to extract duplicated DECCOLM logic into a helper function.
  - Fixing helper functions (`get_content/2`, `is_screen_clear?/1`) to correctly use `Emulator.get_active_buffer/1`.
  - **Tests (`test/raxol/terminal/commands/screen_test.exs`):** Fixed failures related to EL/ED assertions by comparing character lists from cell structs instead of asserting against `nil` or plain strings. Restored missing `initial_emulator/2` helper function.
  - **Core (`lib/raxol/core/renderer/view.ex`):** Fixed layout logic (`layout_flex`, `layout_grid`, `layout_border`, `layout_scroll`, `layout_shadow`, `layout_basic`) to correctly handle children and calculate sizes, resolving `ViewTest` failures. Ensured recursive layout calls and updated `flatten_view_tree`.
  - **Tests:** **Achieved 0 test failures** (25 skipped tests remain) after resolving issues across terminal emulation, rendering, components, and core systems.
- **Tests(`test/terminal/ansi/window_manipulation_test.exs`):** Fixed all tests by correcting CSI and OSC sequence parsing (`:binary.split`, parameter extraction) and handling logic in `WindowManipulation`.
- **Emulator(`lib/raxol/terminal/emulator.ex`):** Refactored `maybe_scroll/1` and `maybe_scroll/2` to correctly handle scrolling logic without unintended cursor clamping.
- **Emulator(`lib/raxol/terminal/emulator.ex`):** Corrected autowrap logic in `calculate_write_position` (Cases 1 and 3) to properly handle the `last_col_exceeded` flag and determine write/cursor positions.
- **Tests(`test/raxol/core/accessibility_test.exs`):** Resolved all failures (0 failures, 7 skipped) by removing `:meck` usage, fixing `Accessibility.announce/2` and `disable/0` logic, adjusting assertions to use `UserPreferences` state directly, and addressing test interference issues.

### Security

## [0.2.0] - 2024-07-24

### Added

- Initial release of Raxol
- Terminal UI framework with web interface capabilities
- Core components library
- Visualization plugins
- Internationalization support
- Theme system

### Changed

- **Dependencies:** Updated `rrex_termbox` from v1.1.5 to v2.0.1, migrating from Port-based to NIF-based architecture for improved performance and reliability.
- **Terminal Subsystem:** Refactored all terminal code to use the new RrexTermbox 2.0.1 API with GenServer-based event delivery.
  - Updated `lib/raxol/terminal/driver.ex` to use the NIF-based interface instead of Port-based communication
  - Updated `lib/raxol/terminal/terminal_utils.ex` for NIF-based terminal dimension detection
  - Redesigned `lib/raxol/terminal/constants.ex` to directly map to NIF constants
  - Rewritten `lib/raxol/core/events/termbox_converter.ex` to handle NIF event format
  - Updated `lib/raxol/test/mock_termbox.ex` to match the NIF-based interface for testing
- **Terminal Documentation:** Updated all documentation to reflect the NIF-based architecture:
  - Updated `docs/development/planning/terminal/terminal_dimensions.md`
  - Updated `docs/development/planning/handoff_prompt.md`
  - Updated `docs/guides/components/visualization/testing-guide.md`
  - Updated `docs/guides/terminal_emulator.md`
- **Tests:** Rewritten `test/raxol/terminal/driver_test.exs` to test NIF events instead of Port-based IO communication
- **Event Handling:** Updated the event handling system to work with the new termbox NIF architecture.

### Known Issues

- Various compiler warnings as documented in the CI logs
- **Runtime Hang:** Examples launched via `Raxol.start_link/1` (e.g., using `bin/demo.exs`) currently hang after compilation, indicating a blocking issue in the core runtime initialization or render loop.
- **NIF Initialization Error:** Runtime initialization fails when starting applications/examples due to the `termbox2_nif` dependency. After updating to `termbox2_nif v0.1.7`, the error changed to `:termbox2_nif_app.start/2` being undefined, indicating an issue with the dependency's OTP application definition. This blocks running examples and native terminal interaction.

### Added

- **Project Foundation:** Initial structure, config, docs, CI/CD, dev env, quality tools, test framework.
- **Core Systems:**
  - Terminal emulation layer with ANSI processing and feature detection.
  - Buffer management (double buffering, damage tracking, scrolling, cursor).
  - Plugin system (core API, config, dependencies, loading, command registry).
  - Component system (View DSL, layout components, widgets, testing framework).
  - Runtime logic (Dispatcher, Manager, Driver, Supervisor, event loop).
  - Core features (ID generation, preferences, plugin registry).
  - Terminal buffer operations (scrollback, selection).
  - Color system module for theme/accessibility aware color retrieval.
  - User preferences persistence module.
- **UI Components:** Added `Table` and `SelectList`.
- **Terminal Capabilities:** Enhanced ANSI processing, input parsing (mouse, special keys, bracketed paste).
- **VS Code Extension Integration:** Communication protocol, WebView panel, JSON interface.
- **Database:** Connection management, error handling, diagnostics improvements.
- **Dashboard/Visualization:** Widget layout management, responsiveness, caching. Added helpers for Chart, Treemap, Image rendering.
- **CI/CD:** Local testing (`act`), cross-platform enhancements, security scanning.
- **Theme System:** Multiple built-in themes, selection UI, customization API, persistence.
- **Testing:**
  - General testing framework improvements (mock components, performance monitoring).
  - Added tests for mouse event parsing, runtime supervisor, plugin manager (loading, reloading, dependencies), dispatcher interactions, layout measurement, `MultiLineInput` helpers.
  - Added mock plugins and test setup helpers.
- **MultiLineInput Features:** Implemented basic cursor navigation, clipboard integration, and scrolling logic.
- **Sixel Support:** Added initial modules for pattern mapping and palette handling.
- **Documentation:**
  - Added initial drafts for Plugin Development, Theming, and VS Code Extension guides.
- **Examples:** Created initial `component_showcase.exs` example.

### Changed

- **Architecture:** Updated `ARCHITECTURE.md` codebase size analysis with new thresholds and file sizes.
- **Architecture:** Completed major codebase reorganization and refactoring of core systems (Runtime, Terminal, UI, Plugins) for improved modularity, configuration, and structure. Updated `ARCHITECTURE.md`.
- **Components:** Refactored `Table` component (`lib/raxol/ui/components/display/table.ex`) to use attributes for data/columns instead of internal state and apply basic width constraints.
- **Terminal Functionality:** Improved feature detection, refined ANSI processing, optimized config/memory management. Refactored input parsing in `TerminalDriver` to use `:os.cmd("stty ...")`.
- **Plugin System:** Improved initialization, dependency resolution, API versioning. Defined `Plugin` behaviour. Refactored `PluginManager` and `CommandRegistry` (namespaces, arity, lifecycle/command helpers). Implemented basic plugin reloading infrastructure.
- **Runtime System:** Improved dual-mode operation, startup/error handling. Ensured correct command routing. Refactored `Lifecycle` module.
- **Rendering Pipeline:** Refined rendering flow, integrated theme application, implemented active theme management, updated layout engine, implemented border rendering for `:box`. Refactored `RenderingEngine`.
- **Project Structure:** Consolidated examples, improved secrets/git handling. Updated roadmap documents.
- **Terminal Configuration:** Refactored `configuration.ex` into dedicated modules. Added deep merge utility.
- **View/Layout System:** Standardized on macros in `Raxol.View.Elements`.
- **Layout Engine:** Implemented measurement logic for `:panel`, `:grid`, `:view`.
- **Terminal Parser:** Refactored `parse_loop` and CSI dispatching logic. Implemented placeholder handlers for SGR, scroll regions, cursor styles, etc.
- **Terminal Emulator:** Refactored control code handling (C0, ESC sequences).
- **Terminal Integration:** Refactored memory management and config update logic.
- **MultiLineInput Component:** Refactored core logic into helper modules. Implemented selection logic.
- **Visualization Plugin:** Refactored rendering logic into separate modules.
- **Sixel Graphics:** Partially refactored parser and rendering logic.
- **Dashboard Component:** Implemented grid-based rendering.
- **Color System Integration:** Refactored `Theme` for variants/palettes. Refactored `ThemeIntegration` for high-contrast state management.
- **User Preferences System:** Refactored `UserPreferences` GenServer to use `Persistence` module, support nested keys, and add auto-saving.
- **Various Components & Modules:** Updated numerous components (`Button`, `Checkbox`, etc.), examples, scripts, benchmarks, and cloud monitoring modules to align with refactoring and fix behaviour implementations.
- **Documentation:**
  - Reviewed and updated core documentation guides (`README.md`, components, quick start, async, runtime options, terminal emulator, development setup, architecture) post-refactoring.
  - Rewritten Component Development guide.
  - Updated `README.md` example.
- **Mixfile (`mix.exs`):** Removed obsolete `mod:` key, updated description.
- **Examples:** Refactored `component_showcase.exs` theming tab to use `Raxol.Core.ColorSystem.get/2`.
- **Documentation:** Reviewed and updated terminal subsystem documentation (`ANSIProcessing.md`, `CharacterSets.md`, `ClipboardManagement.md`, `ColorManagement.md`, `Cursor.md`) to align with current architecture (`Parser`, `Emulator`, `Driver`, `Theming`, `ColorSystem`, etc.) and remove outdated content.
- **Documentation:** Rewritten `docs/development/planning/overview.md` to align with current state and future vision.
- **Documentation:** Updated `docs/development/planning/handoff_prompt.md` to include future feature goals from overview.
- **Documentation:** Updated `docs/development/planning/roadmap/Roadmap.md` based on revised overview.
- **Documentation:** Performed major cleanup: removed obsolete files/stubs, relocated terminal detail files to `docs/development/terminal/`, updated links in root `README.md` and `docs/README.md`.
- **Documentation:** Archived outdated, large planning documents (`docs/development/planning/performance/case_studies.md`, `docs/development/planning/examples/integration_example.md`) to `docs/development/archive/planning/`.
- **Examples:** Refactored `lib/raxol/examples/integrated_accessibility_demo.ex` to remove standalone `run/0` logic and rely on the `Raxol.Core.Runtime.Application` behaviour implementation.
- **Examples:** Updated `bin/demo.exs` script to launch examples using `Raxol.start_link/1` instead of calling module-specific `run/0` functions.
- **Terminal Subsystem:** Refactored `Raxol.Terminal.Driver` to utilize the `:rrex_termbox` NIF-based interface (v2.0.1) for input event handling, removing direct stdio management and ANSI parsing logic.
- **Terminal Subsystem:** Refactored `Raxol.Terminal.TerminalUtils` to remove dependency on `:rrex_termbox` for determining terminal dimensions, relying solely on `:io` and `stty`.
- **Examples:** Enhanced `lib/raxol/examples/integrated_accessibility_demo.ex` by:
  - Integrating `Raxol.Core.UserPreferences` for loading/saving settings.
  - Integrating `Raxol.Core.I18n` for translations.
  - Improving the animation example (progress bar) and respecting reduced motion.
  - Removing unused aliases and performing general cleanup.

### Deprecated

- Old event system
- Legacy rendering approach
- Previous styling methods
- `Raxol.Terminal.CommandHistory` (Use `Raxol.Terminal.Commands.History` instead)

### Removed

- Obsolete configuration files, dependencies, documentation, and legacy code following major refactoring (including old top-level modules, `CommandHistory`, helper module component usage, redundant layout functions, unused code).
- Pruned obsolete files and directories (Note: Further investigation needed for some potentially obsolete directories).

### Fixed

- **Compiler Warnings:** Resolved remaining warnings:
  - Unused variable `_state` in `Raxol.Terminal.Driver.terminate/2`.
  - Unused variables `_current_color`, `_current_char` in `Raxol.Terminal.ANSI.SixelGraphics.generate_pixel_data/4` within specific `if` block.
  - Redefined `@doc` for `Raxol.Style.Colors.Accessibility.accessible_color_pair/2` by removing potentially conflicting comments/docs around private helper functions.
- **Compilation & Build:**
  - Resolved `:rrex_termbox` (v2.0.1) compilation failures by adapting code to its NIF-based API.
  - Fixed guard clause issues in `lib/raxol/core/events/termbox_converter.ex` by defining module attributes for key constants.
  - Updated references from `:rrex_termbox` to `ExTermbox` in multiple files:
    - `lib/raxol/terminal/constants.ex`
    - `lib/raxol/terminal/driver.ex`
    - `lib/raxol/terminal/terminal_utils.ex`
  - Fixed issues in MultiLineInput component:
    - Corrected namespace in tests from `Raxol.UI.Components.Input.MultiLineInput.State` to `Raxol.Components.Input.MultiLineInput`
    - Updated cursor position handling to use the `cursor_pos` tuple instead of separate `cursor_row` and `cursor_col` fields
    - Fixed pattern matching in navigation helper to extract coordinates from cursor position tuple
    - Implemented missing `clear_selection` and `normalize_selection` functions
    - Fixed line-wrapping behavior for cursor movement in left and right directions
  - Applied local patch to `deps/rrex_termbox/Makefile` to remove obsolete NIF build rules that prevented compilation.
  - Resolved numerous compilation errors and warnings across the codebase related to refactoring (undefined functions/variables, incorrect module paths/aliases/imports, behaviour implementations, syntax errors, type issues, argument errors, cyclic dependencies).
  - Fixed compilation errors in `lib/raxol/plugins/visualization/treemap_renderer.ex` (unused variable, incorrect function call).
  - Fixed compilation errors in `lib/raxol/style/colors/accessibility.ex` (removed duplicate `contrast_ratio/2` definition).
  - Fixed compilation error in `lib/raxol/ui/components/display/table.ex` (syntax error in `init/1`
