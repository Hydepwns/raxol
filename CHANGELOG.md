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

## [Unreleased] - 2024-06-03

### Changed

- **Emulator/Test Plan Refinement (Internal):**
  - Initialized default tab stops in `Emulator.new/3`.
  - Corrected argument order in `Manager.move_to/3` calls within `Emulator.handle_lf/1` and `Emulator.process_character/2`.
  - Paused parser extraction (TEST_PLAN.md Issue 5).
  - Updated TEST_PLAN.md to reflect recent fixes and focus action items.

### Historical Fixes (Moved from TEST_PLAN.md Issue 3.1)

- **(2024-05-17):** Fixed failures in `emulator_test.exs` (missing public functions), resolved `set_scroll_region/3` conflict.
- **(2024-05-18):** Fixed `Emulator.init/0` alias conflict, syntax errors in `emulator.ex`.
- **(2024-05-22):** Replaced `Cursor.Manager.get_position/1` call with struct access. Replaced `ScreenModes.is_mode_set?/2` calls with `ScreenModes.mode_enabled?/2`.
- **(2024-05-23):** Deleted outdated `input_test.exs`.
- **(2024-05-23):** Added basic implementations/placeholders for numerous missing private helper functions (`handle_*`, `execute_*`, `accumulate_*`, `collect_*`) in `lib/raxol/terminal/emulator.ex`.
- **(2024-05-23):** Corrected misplaced `end` keyword syntax error in `lib/raxol/terminal/emulator.ex`.
- **(2024-05-23):** Performed clean build (`mix deps.get`, `mix compile`). Addressed `handle_*` definition order issue in `lib/raxol/terminal/emulator.ex`. Deleted obsolete `test/terminal/ansi/processor_test.exs`. Fixed several undefined function calls (`Movement.move_to_col`, `ScreenBuffer.scroll_up/down`, `Movement.move_to_row`, `CharacterSets.invoke_g*`, `TerminalState.push/pop`, `ScreenModes.set_mode`) within `lib/raxol/terminal/emulator.ex` based on compiler warnings.
- **(2024-05-24):** Added `IO.inspect` logging to `process_input/2` and `process_chunk/2` clauses to trace execution flow. Identified and fixed `FunctionClauseError` for simple text input (`"Line 1\\n"`) in `process_chunk/2` (ground state) by adding specific handlers (`handle_lf`, `handle_cr`) for C0 control characters.
- **(2024-05-25):** Fixed compilation error related to `List.last/1` call within guard in `accumulate_csi_param/2`. Corrected call from `Movement.move_to/3` to `Manager.move_to/3` in `process_character/2`. `mix test` now compiles.
- **(2024-05-25):** Resolved the `FunctionClauseError` in `process_chunk/2` (ground state fallback) by ensuring C0 control characters are correctly passed to `process_character/2`.
- **(2024-05-26):** Initialized default `tab_stops` in `Emulator.new/3`. Corrected argument order in `Manager.move_to/3` calls within `Emulator.handle_lf/1` and `Emulator.process_character/2`.
- **(2024-05-27):** Replaced all calls to the deprecated `Emulator.write/2` with `Emulator.process_input/2` in `test/raxol/terminal/emulator_test.exs`.
- **(2024-05-29/30):** Fixed compilation errors in `lib/raxol/terminal/parser.ex` related to using function calls within binary pattern matches/guards.
- **(2024-05-31):** Fixed `KeyError: :screen_buffer not found` in `test/raxol/components/terminal/emulator_test.exs` by using `Emulator.get_active_buffer/1`.
- **(2024-05-31):** Fixed `UndefinedFunctionError` for `TextFormatting.ansi_code_to_color_name/1` and `ScreenModes.switch_mode/3` by adding `require` directives in `lib/raxol/terminal/command_executor.ex`.
- **(2024-05-31):** Fixed `KeyError: :screen_buffer not found` in `test/raxol/terminal/emulator_test.exs` by using `Emulator.get_active_buffer/1`.
- **(2024-05-31):** Fixed `UndefinedFunctionError: function Raxol.Terminal.Cursor.Manager.get_position/1` by replacing calls with direct `cursor.position` access in `lib/raxol/terminal/emulator.ex`.
- **(2024-05-31):** Fixed incorrect cursor coordinate assignment (`{cursor_y, cursor_x}` vs `{cursor_x, cursor_y}`) in `Emulator.process_character/2`. This resolved all remaining test failures.

### Fixed

- **(2024-06-03):** Resolved remaining compilation warnings. Verified that previously listed warnings were mostly outdated or already fixed. Corrected `.screen_buffer` access in `lib/raxol/terminal/session.ex` to use `Emulator.get_active_buffer/1`.
