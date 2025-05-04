---
title: TODO List
description: List of pending tasks and improvements for Raxol Terminal Emulator
date: 2024-06-05
author: Raxol Team
section: roadmap
tags: [roadmap, todo, tasks]
---

# Raxol Project Roadmap

## Documentation Overhaul Plan (In Progress)

_Goal: Perform a comprehensive documentation update post-refactoring to ensure accuracy, consistency, and robustness._

**Goal 1: Ensure Documentation Accuracy and Consistency Post-Refactoring**

- [x] Task 1.1: Inventory Documentation Files (`docs/`)
- [x] Task 1.2a: Review Core Guide: `quick_start.md`
- [x] Task 1.2b: Review Core Guide: `components.md`
- [x] Task 1.2c: Review Core Guide: `async_operations.md`
- [x] Task 1.2d: Review Core Guide: `runtime_options.md`
- [x] Task 1.2e: Review Core Guide: `terminal_emulator.md`
- [x] Task 1.2f: Review Core Guide: `DevelopmentSetup.md`
- [x] Task 1.2g: Review Core Guide: `ARCHITECTURE.md` (Updated 2024-08-01)
- [x] Task 1.3: Verify Content (Code examples, links, terminology) (Ongoing, READMEs updated 2024-08-01)
- [x] Task 1.4: Apply Corrections (File edits for errors/inconsistencies) (Ongoing, READMEs/Arch updated 2024-08-01)

**Goal 2: Create Comprehensive Guides for Key Subsystems**

- [ ] Task 2.1: Plan Plugin Development Guide (`docs/guides/plugin_development.md` outline)
- [ ] Task 2.2: Write Plugin Development Guide (Content population)
- [ ] Task 2.3: Plan Theming Guide (`docs/guides/theming.md` outline)
- [ ] Task 2.4: Write Theming Guide (Content population)
- [ ] Task 2.5: Plan VS Code Extension Guide (`docs/guides/vscode_extension.md` outline) (If applicable)
- [ ] Task 2.6: Write VS Code Extension Guide (Content population)

**Goal 3: Enhance Practical Examples**

- [ ] Task 3.1: Improve README Example (Clarified start method 2024-08-01, needs full review)
- [x] Task 3.2: Develop Component Showcase (Enhance existing or create new example, document, link from `components.md`)
  - [x] Added `MultiLineInput`, `Table`, `SelectList`, `Spinner`, `Modal` demos.
  - [x] **Resolved:** Compilation error in `lib/raxol/components/input/multi_line_input/event_handler.ex` was fixed.
  - [x] Run and compile showcase example (`mix run examples/showcase_app.ex`). (**Refactored to compile & implement behaviour**)
  - [x] Visually verify showcase example rendering and functionality. (**Blocked by NIF Runtime Error** -> **Verified 2025-05-02**)

**Goal 4: Improve Generated API Documentation (ExDoc)**

- [ ] Task 4.1: Identify Key Public Modules
- [ ] Task 4.2: Review Module Docs (`@moduledoc`)
- [ ] Task 4.3: Review Function Docs (`@doc` & `@spec`)
- [x] Task 4.4: Test ExDoc Generation (`mix docs`)
- [x] Add optional plugin reloading via file watching.
- [ ] Fix large batches of test failures across various modules (**Runtime**, **Colors**, **Plugins (ClipboardPlugin fixed)**, Persistence, **Phoenix Channel Tests**, **Terminal Mouse Integration Tests**, **Emulator (Partial - see below)**, Config, Components, **Terminal (Partial - see below)**).
  - [x] Fixed `Emulator.put_text/4` usage in `test/terminal/integration_test.exs`.
  - [x] **Fixed:** All tests in `test/examples/button_test.exs` now pass (excluding skipped integration tests).
  - [x] **Checkbox Component Tests:** Completed.
  - [x] **Modal Component Tests:** Basic form tests added (`test/raxol/components/modal_test.exs`).
  - [x] **MultiLineInput Component Tests:** Completed (`test/raxol/components/input/multi_line_input_test.exs` passes).
- [x] **Phoenix Channel Tests (`TerminalChannelTest`)**: Resolved initial setup/config errors (PubSub, Endpoint, user_id). Fixed crashes in `terminate/2`, `handle_in` functions, theme handling, and assertions. **All tests now pass.**
- [x] **Core Plugin Tests**: Fixed tests for `NotificationPlugin` (using `System.Interaction` behaviour mock). ClipboardPlugin tests pass.
- [x] RUNTIME: Potential infinite loop mentioned in old TODO - **needs verification**. (**Resolved via rrex_termbox v2.0.4 polling fix**)
- [x] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification once examples can run**. (**Showcase runs, needs specific test/app**)
- [x] **EMULATOR TEST PROGRESS:** Fixed all tests in `test/terminal/ansi/window_manipulation_test.exs`. Investigating failures in `test/raxol/terminal/emulator/writing_buffer_test.exs` (scrolling, autowrap).
- [ ] IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification if `ImagePlugin` is used/intended.
- [ ] PLUGIN: Hyperlink `open_url` needs cross-OS testing.
- [!] **Investigation:** `mix run examples/...` fails (`:termbox2_nif_app.start/2` undefined) -> **(BLOCKER - NIF OTP App Issue)**
  - **Issue:** `termbox2_nif` v0.1.7 cannot be started as an OTP application. Previous NIF init errors resolved by update, but this app structure issue prevents runtime startup.
  - **Fix:** Needs investigation/fix within the `termbox2_nif` dependency's Erlang/rebar3 setup (likely `.app.src` or `_app.erl`).
  - **Status:** `mix run examples/...` compiles but fails at OTP application start for the NIF dependency. **(Resolved by updating to rrex_termbox v2.0.4)**
- [ ] **Benchmark Memory Tracking:** Investigate failure in memory data collection during visualization benchmark. (**New - Medium Priority**)

## Other In Progress Tasks

## In Progress

- [ ] Ensure 100% functional examples (@examples verification)
- [ ] Write More Tests (Runtime interactions: Dispatcher, Renderer; PluginManager edge cases - Partially Done)
- [ ] Benchmark performance with complex dashboards
- [ ] Profile visualization rendering with large datasets
- [ ] Implement caching for visualization calculations (if identified as bottleneck)
- [ ] Complete comprehensive cross-platform testing (Native Terminal & VS Code Extension)
- [ ] Create comprehensive user documentation and guides (Core concepts, Components, Plugins, Theming, Accessibility)
- [ ] Test native terminal environment functionality thoroughly

## Backlog

### High Priority

- [x] Implement core terminal command handling (CSI, OSC, DCS) (`lib/raxol/terminal/commands/executor.ex`).
  - [x] Implemented basic CSI: SGR, CUP, DECSTBM, SM/RM (in `ScreenModes`)
  - [x] Implemented CSI: ED, EL
  - [x] Implemented CSI: CUU, CUD, CUF, CUB
  - [x] Implemented CSI: CNL, CPL, CHA, VPA
  - [x] Implemented CSI: IL, DL, DCH, ICH
  - [x] Implemented CSI: SU, SD, ECH
  - [x] Implemented CSI: DA, DSR
  - [x] Implemented CSI: DECSCUSR
  - [x] Implement remaining core CSI sequences **(All core sequences for passing tests now handled)**
  - [x] Implement OSC handling **(Basic: WinTitle(0,2), Hyperlink(8), CWD(7); Clipboard(52) partially done; TODO: Colors(4))**
  - [x] Implement DCS handling **(Structure added; DECRQSS(!|) partially done; TODO: Sixel(q))**
- [x] Fix `MultiLineInput` callback invocation and add word movements (`lib/raxol/components/input/multi_line_input.ex`). **(Callback emits event, basic word move added)**
- [x] Implement `TextInput` visual cursor rendering and Home/End/Delete key support (`lib/raxol/components/input/text_input.ex`). **(Visual cursor added, Home/End/Del keys handled)**
- [x] Update `ANSI Facade` to reflect new state structure (`lib/raxol/terminal/ansi_facade.ex`). **(Done - Module deprecated)**
- [x] Fix plugin command declaration format.
- [x] Consolidate plugin command registration (remove `Commands` GenServer).
- [x] Add optional plugin reloading via file watching.
- [ ] Fix large batches of test failures across various modules (**Runtime**, **Colors**, **Plugins (ClipboardPlugin fixed)**, Persistence, **Phoenix Channel Tests**, **Terminal Mouse Integration Tests**, **Emulator (Partial - see below)**, Config, Components, **Terminal (Partial - see below)**).
  - [x] Fixed `Emulator.put_text/4` usage in `test/terminal/integration_test.exs`.
  - [x] **Fixed:** All tests in `test/examples/button_test.exs` now pass (excluding skipped integration tests).
  - [x] **Checkbox Component Tests:** Completed.
  - [x] **Modal Component Tests:** Basic form tests added (`test/raxol/components/modal_test.exs`).
  - [x] **MultiLineInput Component Tests:** Completed (`test/raxol/components/input/multi_line_input_test.exs` passes).
- [x] **Phoenix Channel Tests (`TerminalChannelTest`)**: Resolved initial setup/config errors (PubSub, Endpoint, user_id). Fixed crashes in `terminate/2`, `handle_in` functions, theme handling, and assertions. **All tests now pass.**
- [x] **Core Plugin Tests**: Fixed tests for `NotificationPlugin` (using `System.Interaction` behaviour mock). ClipboardPlugin tests pass.
- [ ] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification**. (**Showcase runs, needs specific test/app**)
- [x] EMULATOR: **Silent Crash / SGR Failures:** ~~All tests in `test/raxol/terminal/emulator/` fail to load, crashing `mix test` silently.~~ **(Resolved: Silent crash fixed)** ~~35 SGR failures remain.~~ **(Resolved: SGR failures were cache-related, fixed by clean build)**
- [ ] **Fix Skipped Tests (`mix test`):** Address the **25 skipped tests** remaining (0 failures) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- [ ] **Fix Test Failures (`mix test`):** Address the **~459 failures remaining** (down from 477) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- [x] **AccessibilityTest** (`test/raxol/core/accessibility_test.exs`): FIXED (0 failures / 7 skipped) - Addressed mocking issues and logic errors.

### Medium Priority

- [/] Implement Modal form rendering/interaction (`lib/raxol/components/modal.ex`). **(Basic TextInput, Checkbox, Dropdown rendering, interaction, and validation implemented. Needs further testing/refinement)**
- [ ] Implement Table features: pagination buttons, filtering, sorting (`lib/raxol/components/table.ex`).
- [ ] Implement Focus Ring styling based on state/effects (`lib/raxol/components/focus_ring.ex`).
- [ ] Implement Animation framework easing functions and interpolation (`lib/raxol/animation/framework.ex`).
- [ ] Implement AI content generation stubs (`lib/raxol/ai/content_generation.ex`).
- [ ] Add missing terminal feature detection checks (`lib/raxol/system/terminal_platform.ex`).
- [ ] Implement terminal input handling: tab completion, mouse events (`lib/raxol/terminal/input.ex`).
- [ ] Implement advanced terminal character set features (GR invocation, Locking/Single Shift) (`lib/raxol/terminal/character_sets.ex`).
- [ ] Enhance TUI rendering in native terminal with advanced styling techniques (beyond basic theme application).
- [x] **Enhance SelectList:** Consider stateful scroll offset, more robust focus management, search/filtering.
- [x] RUNTIME: Potential infinite loop mentioned in old TODO - **needs verification**. (**Resolved via rrex_termbox v2.0.4 polling fix**)
- [ ] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification once examples can run**. (**Showcase runs, needs specific test/app**)
- [x] **EMULATOR TEST PROGRESS:** Fixed all tests in `test/terminal/ansi/window_manipulation_test.exs`. Investigating failures in `test/raxol/terminal/emulator/writing_buffer_test.exs` (scrolling, autowrap).
- [ ] IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification if `ImagePlugin` is used/intended.
- [ ] PLUGIN: Hyperlink `open_url` needs cross-OS testing.
- [!] **Investigation:** `mix run examples/...` fails (`:termbox2_nif_app.start/2` undefined) -> **(BLOCKER - NIF OTP App Issue)**
  - **Issue:** `termbox2_nif` v0.1.7 cannot be started as an OTP application. Previous NIF init errors resolved by update, but this app structure issue prevents runtime startup.
  - **Fix:** Needs investigation/fix within the `termbox2_nif` dependency's Erlang/rebar3 setup (likely `.app.src` or `_app.erl`).
  - **Status:** `mix run examples/...` compiles but fails at OTP application start for the NIF dependency. **(Resolved by updating to rrex_termbox v2.0.4)**
- [ ] **Benchmark Memory Tracking:** Investigate failure in memory data collection during visualization benchmark. (**New - Medium Priority**)
- [ ] **Fix Test Failures (`mix test`):** Address the **~459 failures remaining** (down from 477) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- [ ] **Fix Skipped Tests (`mix test`):** Address the **25 skipped tests** remaining (0 failures) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- [x] **AccessibilityTest** (`test/raxol/core/accessibility_test.exs`): FIXED (0 failures / 7 skipped) - Addressed mocking issues and logic errors.

### Low Priority

- [ ] Investigate/Fix potential text wrapping off-by-one error (`lib/raxol/components/input/text_wrapping.ex`).
- [ ] Refactor large files identified in ARCHITECTURE.md (e.g., `terminal/parser.ex`).
- [ ] Deduplicate code / Extract common utilities.
- [x] RUNTIME: Potential infinite loop mentioned in old TODO - **needs verification**. (**Resolved via rrex_termbox v2.0.4 polling fix**)
- [x] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification once examples can run**. (**Showcase runs, needs specific test/app**)
- [x] **EMULATOR TEST PROGRESS:** Fixed all tests in `test/terminal/ansi/window_manipulation_test.exs`. Investigating failures in `test/raxol/terminal/emulator/writing_buffer_test.exs` (scrolling, autowrap).
- [ ] IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification if `ImagePlugin` is used/intended.
- [ ] PLUGIN: Hyperlink `open_url` needs cross-OS testing.
- [ ] **SIXEL:** Investigate potential minor rounding inaccuracies in HLS -> RGB conversion within `SixelGraphics`.
- [ ] **SIXEL:** Review `consume_integer_params` default value behavior in Sixel parsing context; ensure it matches expected terminal behavior if defaults differ from 0 or 1.
- [ ] **Fix Test Failures (`mix test`):** Address the **~459 failures remaining** (down from 477) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- [ ] **Fix Skipped Tests (`mix test`):** Address the **25 skipped tests** remaining (0 failures) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- **PERFORMANCE:** Potential degradation with multiple complex visualizations (**Unblocked**, needs testing).
- **PERFORMANCE:** Memory usage patterns with large datasets need analysis (**Benchmark ran, but memory tracking failed**).
- **COMPATIBILITY:** Specific cross-platform edge cases may exist.
- **RUNTIME:** Status of warnings like `Unhandled view element type` requires visual verification (Blocked by NIF -> **Showcase runs, needs specific test/app**).
- **NIF:** Resolved (`termbox2_nif` replaced by `rrex_termbox` v2.0.4).

## Issues to Investigate

- [x] **Investigate rrex_termbox NIF Loading Issue on ARM macOS:** ~~Runtime error (`:undef, :termbox2_nif.tb_init/0`, `:bad_lib` module name mismatch) preventing application start. Blocks running examples like component showcase.~~ **RESOLVED (2025-05-02)** - Fix applied to `deps/termbox2_nif` build files and Erlang source.
- [!] **Investigate NIF Runtime Initialization Error:** Runtime fails (`UndefinedFunctionError` for `:termbox2_nif_app.start/2`) because `termbox2_nif` (v0.1.7) cannot be started as an OTP application. Likely missing/incorrect definition in its `.app.src` or `_app.erl`. **(BLOCKER - High Priority)**
  - [ ] `ex_termbox` dependency: Can it be removed or replaced given direct `stty` usage in `Terminal.Driver`? (Seems likely removed/obsolete based on Changelog fixes, but verify). If kept, investigate dimension reporting inconsistencies.
  - [ ] Performance degradation with multiple complex visualizations.
  - [ ] Memory usage patterns with large datasets.
- [x] RUNTIME: Potential infinite loop mentioned in old TODO - **needs verification**.
- [ ] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification once examples can run**.
- [x] **EMULATOR TEST PROGRESS:** Fixed all tests in `test/terminal/ansi/window_manipulation_test.exs`. Investigating failures in `test/raxol/terminal/emulator/writing_buffer_test.exs` (scrolling, autowrap).
- [ ] IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification if `ImagePlugin` is used/intended.
- [ ] PLUGIN: Hyperlink `open_url` needs cross-OS testing.
- [!] **Investigation:** `mix run examples/...` fails (`:termbox2_nif_app.start/2` undefined) -> **(BLOCKER - NIF OTP App Issue)**
  - **Issue:** `termbox2_nif` v0.1.7 cannot be started as an OTP application. Previous NIF init errors resolved by update, but this app structure issue prevents runtime startup.
  - **Fix:** Needs investigation/fix within the `termbox2_nif` dependency's Erlang/rebar3 setup (likely `.app.src` or `_app.erl`).
  - **Status:** `mix run examples/...` compiles but fails at OTP application start for the NIF dependency. **(Resolved by updating to rrex_termbox v2.0.4)**
- [ ] **TESTS:** **25 skipped tests remain** (0 failures) across the suite. Requires investigation and fixes.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
- [ ] **Fix Skipped Tests (`mix test`):** Address the **25 skipped tests** remaining (0 failures) identified across the suite.
  - [x] **`WindowManipulationTest`:** FIXED (All tests pass)
  - [x] **`SixelGraphicsTest`:** FIXED (All tests pass)
  - [x] **`ColumnWidthTest`:** FIXED (All tests pass)
- **PERFORMANCE:** Memory usage patterns with large datasets need analysis (**Benchmark ran, but memory tracking failed**).
- **COMPATIBILITY:** Specific cross-platform edge cases may exist.
- **RUNTIME:** Status of warnings like `Unhandled view element type` requires visual verification (Blocked by NIF -> **Showcase runs, needs specific test/app**).
- **NIF:** Resolved (`termbox2_nif` replaced by `rrex_termbox` v2.0.4).

## Testing Needs (Consolidated)

- [x] **Native Terminal:** Comprehensive functional testing across different terminal emulators (gnome-terminal, iTerm2, Windows Terminal, etc.) and OSes (Linux, macOS, Windows/WSL). (**Now Unblocked**)
- [x] **VS Code Extension:** Verify rendering, input, resizing, and backend communication stability. (**Now Unblocked**)
- [ ] **Visualizations:** Validate rendering accuracy and behavior with various datasets (small, large, edge cases).
- [ ] **Performance:** Benchmark key operations (startup, rendering complex views, data processing) in both environments. Establish baseline and monitor regressions.
- [ ] **Plugins:** Test core plugin functionality (clipboard, notifications, hyperlinks) across platforms. Test plugin loading, unloading, reloading, and dependency handling robustness.
- [ ] **Accessibility:** Manual testing with screen readers (e.g., VoiceOver, NVDA), keyboard navigation checks, high contrast mode verification.
- **NIF:** Resolved (`termbox2_nif` replaced by `rrex_termbox` v2.0.4).
