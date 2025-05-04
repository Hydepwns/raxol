---
title: Next Steps
description: Documentation of next steps in Raxol Terminal Emulator development
date: 2025-05-02
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning]
---

# Next Steps for Raxol Development

## Current Status Overview

The project has completed its foundational phases and significant parts of the refactoring efforts outlined previously. The documentation overhaul is well underway, with core guides reviewed and updated.
Key recent accomplishments include:

- **Major Codebase Reorganization & Refactoring:** Largely completed.
- **Test Suite Progress:** Significant progress reducing test failures. However, a recent run (**2024-08-01**) shows **~459 failures** and **25 skipped tests**, indicating regressions or previously undetected issues. Major failures previously resolved in:
  - `WindowManipulationTest` (Corrected CSI/OSC parsing)
  - `ClipboardPluginTest` (Switched Mox -> :meck -> Mox with Behaviour/DI, **All tests now pass.**)
  - `MultiLineInputTest` (Cursor refactoring, **Text manipulation/wrapping fixed**)
  - `MultiLineInput.EventHandlerTest` (Event struct usage, return values)
  - `Emulator.InitializationTest` (**Fixed: All tests pass.**)
  - `Commands.ScreenTest` (Setup fixes)
  - `DispatcherTest` (Mox -> :meck, Event struct usage)
  - `Plugins.ManagerTest` (Mox times option)
  - `Style.Colors.ColorTest` (Assertion fixes)
  - `Style.Colors.PersistenceTest` (**Fixed: All tests pass.**)
  - `Components.Display.ProgressTest` (Component API changes)
  - `Terminal.CommandsTest` (Setup/call fixes)
  - `Terminal.DriverTest` (stty handling, **NIF init workaround, All tests pass.**)
  - `examples/button_test.exs` (Supervisor setup)
  - `RuntimeTest` (Supervisor startup, ETS management)
  - `Core.Runtime.LifecycleTest` (**Fixed: All tests pass.**)
  - Core Component Tests: `SingleLineInputTest`, `ProgressBarTest`, `DropdownTest`, `MultiLineInputTest`, `ListTest` (API alignment)
  - Terminal Config Tests: `ConfigurationTest`, `ConfigTest` (API alignment)
  - Color System Tests: `PersistenceTest` (Setup, serialization), `AdvancedTest` (ETS, HSL, assertions)
  - Terminal State Tests: `StateStackTest` (State field access)
  - Terminal Support Tests: `ScreenBufferTest` (Function rename), `HotReloadTest` (GenServer start), `SgrFormattingTest` (Executor logic), `TextFormattingTest` (Wide char width)
  - Web Interface Tests: `TerminalLiveTest` (Flash fetch), `TerminalChannelTest` (**Fixed: All tests pass.**)
  - Performance Tests: `PerformanceTest` (Module paths, math error)
  - Emulator Tests: `CursorManagementTest` (Duplicate test), `SgrFormattingTest` (**Fixed: Cache issue**), `WritingBufferTest` (**DONE**). **All tests in `test/raxol/terminal/emulator/` now pass.**
  - **Terminal ANSI Tests:** `ColumnWidthTest` (**Fixed: All tests pass.**)
  - Component Tests: Fixed `Button` tests. **Checkbox component tests completed.** **Modal form functionality implemented (TextInput, Checkbox, Dropdown) with tests.** **TextInput tests completed.**
  - ANSI Formatting Tests: Fixed `text_formatting_test.exs` CondClauseError.
  - Terminal Driver Tests: Fixed `driver_test.exs` using workarounds for NIF initialization in test env. (**All tests now pass.**)
- **Core Component Implementation:** Basic `Modal` form rendering, interaction, and validation added. `ComponentShowcase` refactored to implement `Base.Component` behaviour.
- **Core Terminal Emulation:** Functional parser (state propagation fixed), command executor for many core CSI sequences, screen mode handling, state management fixes.
- **Core Runtime Implementation:** Functional runtime loop, event dispatch, rendering pipeline. Supervisor startup fixed. **Runtime Application Start Blocked by NIF OTP App issue.**
- **Plugin System Enhancements:** Core features functional (dependency sorting, command handling, basic reloading). Clipboard and Notification plugins refactored.
- **VS Code Extension Integration:** Core communication bridge functional.
- **Dashboard & Visualization:** Layout system, core visualizations, and persistence implemented.
- **Testing Framework:** Comprehensive framework and tooling in place. Fixed many test setup/API misalignment issues. Added `Modal` tests.
- **Theme System:** Core functionality implemented. Persistence and color struct handling fixed.
- **Documentation Overhaul:** Core guides reviewed; Plugin/Theming/VSCode guides planned.
- **Documentation Alignment:** Updated core `README.md`, `docs/README.md`, and `docs/ARCHITECTURE.md` to better reflect current project state, version, and structure.

**Resolved Blockers / Issues:**

- **`:rrex_termbox` NIF Loading Issue:** Resolved build/load issues on ARM macOS (Initial fix).
- **`mix run` Example Failures (Compilation):** Resolved compilation issues in `ComponentShowcase`.
- **Emulator Test Silent Crash:** Resolved (was combination of Mox setup error and parser state propagation bug).
- **Emulator SGR Test Failures:** Resolved (was build cache issue).
- **NIF OTP App Startup Error:** Resolved by updating `rrex_termbox` dependency to v2.0.4, which includes polling fixes.
- **Terminal Test Failures:** Previously resolved, but regressions likely exist given the current failure count. (**Status: 0 Failures / 25 Skipped**)

**Immediate Focus & Blockers:**

- **Fix Test Failures:** Address remaining test failures across the suite. Status: **0 Failures / 25 Skipped** as of 2025-05-02 (after `MultiLineInput` fixes). (**New - Top Priority: Address Skipped Tests**)
- **Run Full Test Suite:** Verify fixes. (**Status: Passes with 25 skipped**)
- **Comprehensive Cross-Platform Testing.** (**Unblocked**) (High Priority)
- **Benchmark performance and profile rendering.** (**Benchmark ran, memory tracking failed.** Revisit after tests pass.) (High Priority)
- **Verify Core Command Plugin Reliability.** (**Unblocked**) (Medium Priority)
- **Implement Remaining Command Handlers (OSC Colors, DCS Sixel).** (Medium Priority)
- **Write More Tests (Runtime, Plugins).** (Medium Priority)
- **Investigate Benchmark Memory Tracking Failure.** (Medium Priority)
- **Documentation Expansion (Guides, ExDoc, TODOs).** (Medium Priority)
- **Address remaining medium/low priority TODOs:** From `TODO.md`. (Low Priority)

## Tactical Next Steps (Revised Priorities)

- **Fix Test Failures:** Address remaining test failures across the suite. Status: **0 Failures / 25 Skipped** as of 2025-05-02 (after `MultiLineInput` fixes). (**New - Top Priority: Address Skipped Tests**)
- **Run Full Test Suite:** Verify fixes. (**Status: Passes with 25 skipped**)
- **Comprehensive Cross-Platform Testing.** (**Unblocked**) (High Priority)
- **Benchmark performance and profile rendering.** (**Benchmark ran, memory tracking failed.** Revisit after tests pass.) (High Priority)
- **Verify Core Command Plugin Reliability.** (**Unblocked**) (Medium Priority)
- **Implement Remaining Command Handlers (OSC Colors, DCS Sixel).** (Medium Priority)
- **Write More Tests (Runtime, Plugins).** (Medium Priority)
- **Investigate Benchmark Memory Tracking Failure.** (Medium Priority)
- **Documentation Expansion (Guides, ExDoc, TODOs).** (Medium Priority)
- **Address remaining medium/low priority TODOs.** (Low Priority)

1. **Fix Test Failures:** Address remaining test failures across the suite. Status: **0 Failures / 25 Skipped** as of 2025-05-02 (after `MultiLineInput` fixes). (**New - Top Priority: Address Skipped Tests**)
2. **Run Full Test Suite:** Verify fixes. (**Status: Passes with 25 skipped**)
3. **Comprehensive Cross-Platform Testing.** (**Unblocked**) (High Priority)
4. **Benchmark performance and profile rendering.** (**Benchmark ran, memory tracking failed.** Revisit after tests pass.) (High Priority)
5. **Verify Core Command Plugin Reliability.** (**Unblocked**) (Medium Priority)
6. **Implement Remaining Command Handlers (OSC Colors, DCS Sixel).** (Medium Priority)
7. **Write More Tests (Runtime, Plugins).** (Medium Priority)
8. **Investigate Benchmark Memory Tracking Failure.** (Medium Priority)
9. **Documentation Expansion (Guides, ExDoc, TODOs).** (Medium Priority)
10. **Address remaining medium/low priority TODOs.** (Low Priority)

## Immediate Development Priorities

| Task                                 | Description                                                                                             | Status                           | Blocker? | Priority | Related File(s) / TODO Task                                        |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------- | -------------------------------- | -------- | -------- | ------------------------------------------------------------------ |
| **Fix Test Failures**                | **Address the 25 skipped tests reported by `mix test`.**                                                | **ToDo**                         | No       | **Top**  | `mix test --trace` output (find skipped tests)                     |
| **Run Full Test Suite**              | **Re-run `mix test` after fixing skipped tests to verify.**                                             | **ToDo (Post-Fixes)**            | No       | High     | `mix test`                                                         |
| Comprehensive Cross-Platform Testing | Comprehensive testing (Native Terminal, VS Code Ext), hyperlink testing                                 | ToDo                             | No       | High     | (TODO In Progress, Issues, Testing Needs)                          |
| Performance Analysis & Opt.          | Benchmark, profile, investigate issues, potentially add caching                                         | Done (Mem Failed), Needs Revisit | No       | High     | (TODO In Progress, Issues)                                         |
| Verify Core Command Plugins          | Ensure Clipboard & Notification plugins work reliably (Tests pass, need runtime check)                  | Done (Tests)                     | No       | Medium   | Core Plugins (TODO High Priority)                                  |
| Implement OSC Colors / Sixel         | Implement OSC 4 handler, Sixel DCS handler                                                              | Done (OSC 4), Sixel ToDo         | No       | Medium   | `Executor.ex`, `SixelGraphics.ex`                                  |
| Investigate Benchmark Mem Track      | Investigate failure in memory data collection during benchmark                                          | ToDo                             | No       | Medium   | `run_visualization_benchmark.exs`                                  |
| Documentation Expansion              | Write guides (Plugin, Theming, VSCode), improve ExDoc, address TODOs, add diagrams, align existing docs | In Progress                      | No       | Medium   | `docs/guides/`, ExDoc tasks, `TODO.md` (Goals 2, 4, 5, 6, 1.3/1.4) |
| Functional Examples                  | Ensure all `@examples` are functional (Component showcase runs, others?)                                | In Progress                      | No       | Medium   | (TODO In Progress)                                                 |
| Investigate Other Issues             | Look into `ex_termbox` dep, runtime warnings, image rendering, text wrap, etc.                          | ToDo                             | No       | Low      | `TODO.md` (Issues to Investigate - excluding NIF & `mix run`)      |
| Medium Priority Features             | Table Enhancements, Focus Ring, Animation, AI Stubs, Term Features, etc.                                | ToDo                             | No       | Low      | `TODO.md` (Medium Priority - excluding Modal)                      |

## Technical Implementation Plan

### Timeline for Next ~4 Weeks (Revised)

| Week   | Focus                             | Tasks                                                                                                               |
| ------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Week 1 | **Test Suite Verification**       | - **Run full `mix test` suite.** <br> - Address any remaining or new failures.                                      |
| Week 2 | **Testing & Verification**        | - If tests pass: Re-run benchmarks, investigate memory tracking. <br>- Begin cross-platform testing.                |
| Week 3 | **Documentation / Core Features** | - Continue Documentation expansion (Guides, ExDoc, TODOs). <br> - Implement OSC Colors / DCS Sixel if time permits. |
| Week 4 | **Documentation / Core Features** | - Continue Documentation / Core Features.                                                                           |
| Week 1 | **Fix Skipped Tests**             | - Identify and investigate the 25 skipped tests. <br> - Begin implementing fixes.                                   |
| Week 2 | **Fix Skipped Tests / Verify**    | - Continue fixing skipped tests. <br> - Run full test suite to verify progress.                                     |
| Week 3 | **Testing & Verification**        | - If tests pass: Re-run benchmarks, investigate memory tracking. <br>- Begin cross-platform testing.                |
| Week 4 | **Documentation / Core Features** | - Continue Documentation expansion (Guides, ExDoc, TODOs). <br> - Implement OSC Colors / DCS Sixel if time permits. |

## Additional Visualization Types

After completing the current priorities, we plan to implement additional visualization types:

1. **Line Charts**

   - Time series data representation
   - Multi-line comparison
   - Customizable line styles and markers

2. **Scatter Plots**

   - Data point distribution visualization
   - Correlation analysis
   - Customizable point styles and sizes

3. **Heatmaps**
   - Density visualization
   - Color-coded data representation
   - Configurable color schemes

## Testing Strategy Updates

### Test Categories for Native Terminal

(Aligning with TODO.md)

1. **Comprehensive Functional Testing:** Across different terminal emulators (gnome-terminal, iTerm2, Windows Terminal, etc.) and OSes (Linux, macOS, Windows/WSL).
2. **VS Code Extension Verification:** Rendering, input, resizing, backend communication stability.
3. **Visualization Validation:** Rendering accuracy and behavior with various datasets (small, large, edge cases).
4. **Performance Benchmarks:** Key operations (startup, rendering complex views, data processing) in both environments. Establish baseline and monitor regressions.
5. **Plugin Functionality:** Test core plugins (clipboard, notifications, hyperlinks) across platforms. Test plugin loading, unloading, reloading, and dependency handling robustness.
6. **Accessibility Checks:** Manual testing with screen readers (e.g., VoiceOver, NVDA), keyboard navigation checks, high contrast mode verification.

### Test Automation

- Create automated test scripts for terminal environment
- Implement CI pipeline for terminal-specific tests
- Add performance regression detection

### GitHub Actions Testing

- Using `act` for local testing and debugging GitHub Actions workflows
- Docker images optimized for ARM MacOS developers (via Orbstack)
- Environment parity between local dev and CI environments
- Testing across multiple Erlang/Elixir versions and platforms
- Robust database setup for both Linux (via services) and macOS (local install)

## Contribution Areas

(Aligning with TODO.md Backlog & Needs)

For developers interested in contributing to Raxol, here are key areas where help is needed:

1. **High/Medium Priority Features:** Implementing features listed in the `TODO.md` backlog (e.g., `Table` enhancements, `FocusRing`, Animation framework).
2. **Additional Visualization Types:** Implementing Line Charts, Scatter Plots, Heatmaps.
3. **Performance Optimization:** Profiling, benchmarking, implementing caching, addressing bottlenecks identified in `TODO.md`.
4. **Testing:** Writing more unit/integration tests (especially for Runtime, Plugins), enhancing the testing framework, adding visual/terminal-specific automated tests, fixing remaining failures (`ColumnWidthTest`, ~~`SixelGraphicsTest`~~).
5. **Documentation:** Writing the planned guides (Plugin Dev, Theming, VSCode), improving API documentation (ExDoc), addressing TODOs, creating diagrams.
6. **Accessibility Enhancements:** Improving screen reader compatibility, keyboard navigation, and color contrast based on testing feedback.
7. **Investigating Issues:** Helping diagnose and fix non-NIF issues listed in `TODO.md`.

## Resources and References

- Visualization Plugin: `VisualizationPlugin`
- Dashboard Layout: `Dashboard.ex`, `GridContainer.ex`, `WidgetContainer.ex`

### 3. Resolve Remaining High-Priority Bugs

- Address the `InputHandler` history navigation failure (`next_history_entry`). **(Check if resolved by other fixes)**
- Investigate the root cause of the state leakage/interaction issues observed in several test files (like the autowrap test initially showed). This might involve looking at GenServer state, ETS tables used by Mox, or other application-level state management during test runs. **(Likely resolved, monitor)**
- ~~Tackle the remaining test failures in `test/terminal/` systematically.~~ **(Done)**
