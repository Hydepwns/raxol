---
title: Next Steps
description: Documentation of next steps in Raxol Terminal Emulator development
date: 2024-07-31
author: Raxol Team
section: roadmap
tags: [roadmap, next steps, planning]
---

# Next Steps for Raxol Development

## Current Status Overview

The project has completed its foundational phases and significant parts of the refactoring efforts outlined previously. The documentation overhaul is well underway, with core guides reviewed and updated.
Key recent accomplishments include:

- **Major Codebase Reorganization & Refactoring:** Largely completed.
- **Test Suite Progress:** Significant progress reducing test failures. **~691 failures remain** (down from ~721). Major failures resolved in:
  - `ClipboardPluginTest` (Switched Mox -> :meck -> Mox with Behaviour/DI, **All tests now pass.**)
  - `MultiLineInputTest` (Cursor refactoring)
  - `MultiLineInput.EventHandlerTest` (Event struct usage, return values)
  - `Emulator.InitializationTest` (**Fixed: All tests pass.**)
  - `Commands.ScreenTest` (Setup fixes)
  - `DispatcherTest` (Mox -> :meck, Event struct usage)
  - `Plugins.ManagerTest` (Mox times option)
  - `Style.Colors.ColorTest` (Assertion fixes)
  - `Style.Colors.PersistenceTest` (**Fixed: All tests pass.**)
  - `Components.Display.ProgressTest` (Component API changes)
  - `Terminal.CommandsTest` (Setup/call fixes)
  - `Terminal.DriverTest` (stty handling)
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
  - Emulator Tests: `CursorManagementTest` (Duplicate test), `SgrFormattingTest` (Executor logic), `WritingBufferTest` (**5 failures remain**)
- **Core Terminal Emulation:** Functional parser, command executor for many core CSI sequences, screen mode handling, state management fixes.
- **Core Runtime Implementation:** Functional runtime loop, event dispatch, rendering pipeline. Supervisor startup fixed.
- **Plugin System Enhancements:** Core features functional (dependency sorting, command handling, basic reloading). Clipboard and Notification plugins refactored.
- **VS Code Extension Integration:** Core communication bridge functional.
- **Dashboard & Visualization:** Layout system, core visualizations, and persistence implemented.
- **Testing Framework:** Comprehensive framework and tooling in place. Fixed many test setup/API misalignment issues.
- **Theme System:** Core functionality implemented. Persistence and color struct handling fixed.
- **Documentation Overhaul:** Core guides reviewed; Plugin/Theming/VSCode guides planned.
- **Documentation Alignment:** Updated core `README.md`, `docs/README.md`, and `docs/ARCHITECTURE.md` to better reflect current project state, version, and structure.

**Immediate Focus & Blockers:**

- **Address Remaining Test Failures:**
  - Fix 5 failures in `test/raxol/terminal/emulator/writing_buffer_test.exs`. **<- Current Focus**
  - Investigate remaining ~25 emulator failures (`SixelGraphicsTest`, `CommandsTest`, etc.).
  - Investigate `Performance.MonitorTest` failures.
  - Investigate component-related failures (Button, Checkbox, Form?).
  - Fix remaining `AutoRepeatTest` failure (if any remain).
- **Testing Strategy:** Continue using focused testing (`mix test path/to/file.exs:line_num`) to debug remaining failures.
  - Implement remaining terminal command handling (**OSC, DCS**) in `lib/raxol/terminal/commands/executor.ex`.
  - Verify Core Command Plugin Reliability: Ensure refactored `NotificationPlugin` works reliably across platforms. (**ClipboardPlugin verified via tests**).
- Benchmark performance and profile rendering with complex dashboards/large datasets.
- Complete comprehensive cross-platform testing (Native Terminal & VS Code Extension).
- Expand documentation (finish planned guides, address TODOs, improve ExDoc).
- **Documentation Expansion:**
  - Write Plugin Development, Theming, and VS Code Extension guides.
  - Review and enhance ExDoc (`@moduledoc`, `@doc`, `@spec`).
  - Find and address documentation TODOs in the codebase.
  - Add visual aids (diagrams) where helpful.
  - **Continue aligning existing documentation (guides, READMEs) with current state.**

## Tactical Next Steps

1.  **Address Remaining Test Failures:**
    - **Fix 5 failures in `test/raxol/terminal/emulator/writing_buffer_test.exs`.**
    - Investigate and fix remaining ~25 emulator failures (Sixel, performance, other command handlers).
    - Investigate and fix `Performance.MonitorTest` failures.
    - Investigate component-related failures (Button, Checkbox, Form).
    - Fix `AutoRepeatTest` (if needed).
2.  **Implement Remaining Command Handlers:** Focus on OSC and DCS sequences in `lib/raxol/terminal/commands/executor.ex` (Once tests are clearer).
3.  **Verify Core Plugins:** Ensure Clipboard & Notification plugins work reliably.
4.  **Refine Plugin System:**
    - Enhance command namespacing/arity handling (if needed after verification).
    - Improve robustness of plugin reloading (if needed).
5.  **Write More Tests:**
    - Focus on Runtime interactions (Dispatcher, Renderer).
    - Test `PluginManager` edge cases (discovery, load order, command delegation, reload).
6.  **Verify Examples & Showcase:**
    - Run and verify the component showcase example.
    - Review and ensure all other examples (`@examples`) are functional.
7.  **Performance Analysis & Optimization:**
    - Benchmark performance with complex dashboards.
    - Profile visualization rendering with large datasets.
    - Investigate reported performance/memory issues.
    - Implement caching for visualizations if identified as a bottleneck.
8.  **Cross-Platform Testing:**
    - Continue comprehensive testing in native terminal environments (various emulators/OSes).
    - Verify VS Code Extension functionality thoroughly.
    - Test hyperlink opening across OSes.
9.  **Documentation Expansion:**
    - Write Plugin Development, Theming, and VS Code Extension guides.
    - Review and enhance ExDoc (`@moduledoc`, `@doc`, `@spec`).
    - Find and address documentation TODOs in the codebase.
    - Add visual aids (diagrams) where helpful.
    - **Continue aligning existing documentation (guides, READMEs) with current state.**

## Immediate Development Priorities

| Task                           | Description                                                                                             | Status             | Blocker? | Priority | Related File(s) / TODO Task                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------ | -------- | -------- | ------------------------------------------------------------------------------------------------- |
| Implement Core Term Commands   | Handle most common CSI sequences (see TODO for list)                                                    | Done               | No       | ---      | `lib/raxol/terminal/commands/executor.ex`, `lib/raxol/terminal/ansi/screen_modes.ex`              |
| Fix Emulator Writing Buffer    | Resolve 5 failures in `test/raxol/terminal/emulator/writing_buffer_test.exs`                            | **ToDo**           | No       | **High** | `writing_buffer_test.exs`, `Emulator.ex`, `ScreenBuffer.ex`                                       |
| Handle Remaining Term Commands | Implement OSC, DCS, less common CSI sequences                                                           | In Progress        | No       | Medium   | `lib/raxol/terminal/commands/executor.ex` (Basic OSC/DCS structure implemented)                   |
| Fix Other Test Failures        | Remaining Emulator (~25), Sixel, Performance, Components (Button/Checkbox/Form?), `AutoRepeatTest`      | ToDo               | No       | High     | Various test files                                                                                |
| Fix MultiLineInput Features    | Fix callback invocation, add word movements                                                             | Done               | No       | ---      | `lib/raxol/components/input/multi_line_input.ex`                                                  |
| Implement TextInput Features   | Add visual cursor rendering, Home/End/Delete keys                                                       | Done               | No       | ---      | `lib/raxol/components/input/text_input.ex`                                                        |
| Update ANSI Facade             | Align with new state structure                                                                          | Done (Deprecated)  | No       | ---      | `lib/raxol/terminal/ansi_facade.ex` (Module deprecated)                                           |
| Refine Plugin System           | Improve reloading, command namespacing/arity, add tests                                                 | In Progress        | No       | Medium   | `PluginManager`, `CommandRegistry` (Reloading enhanced, commands standardized, basic tests added) |
| Verify Core Command Plugins    | Ensure Clipboard & Notification plugins work reliably (post-refactor)                                   | **Partially Done** | No       | High     | Core Plugins (TODO High Priority) - **ClipboardPlugin tests pass**                                |
| Write Tests                    | Runtime interactions (Dispatcher, Renderer), PluginManager edge cases                                   | In Progress        | No       | High     | (PluginManager tests partially done)                                                              |
| Verify Component Showcase      | Run and verify showcase example                                                                         | ToDo               | No       | High     | `examples/component_showcase.exs` (TODO 3.2 - unblocked once remaining test failures resolved)    |
| Performance Analysis & Opt.    | Benchmark, profile, investigate issues, potentially add caching                                         | In Progress        | No       | High     | (TODO In Progress, Issues)                                                                        |
| Cross-Platform Testing         | Comprehensive testing (Native Terminal, VS Code Ext), hyperlink testing                                 | In Progress        | No       | High     | (TODO In Progress, Issues, Testing Needs)                                                         |
| Documentation Expansion        | Write guides (Plugin, Theming, VSCode), improve ExDoc, address TODOs, add diagrams, align existing docs | In Progress        | No       | Medium   | `docs/guides/`, ExDoc tasks, `TODO.md` (Goals 2, 4, 5, 6, 1.3/1.4)                                |
| Functional Examples            | Ensure all `@examples` are functional                                                                   | ToDo               | No       | Medium   | (TODO In Progress)                                                                                |
| Investigate Issues             | Look into `ex_termbox` dep, runtime warnings/loop, image rendering                                      | ToDo               | No       | Medium   | `TODO.md` (Issues to Investigate)                                                                 |
| Medium Priority Features       | Modal, Table Enhancements, Focus Ring, Animation, AI Stubs, Term Features, etc.                         | ToDo               | No       | Medium   | `TODO.md` (Medium Priority)                                                                       |

## Technical Implementation Plan

### Timeline for Next ~4 Weeks (Revised)

| Week   | Focus                             | Tasks                                                                                                                                                                                                                     |
| ------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Week 1 | **Fix Remaining Tests**           | - Focus on debugging the remaining high-priority test failures (Sixel, Performance, Components, AutoRepeat). <br>- Analyze failures and apply fixes. <br>- Use focused tests (`mix test ...:line_num`).                   |
| Week 2 | **Plugin Verification & Testing** | - Verify Core Command Plugins (**Notification**) reliability. <br>- Write tests (Runtime, PluginManager). <br>- Verify Component Showcase & other examples.                                                               |
| Week 3 | **Performance & Cross-Platform**  | - Performance Analysis (Benchmarking/Profiling). <br>- Continue Cross-Platform testing. <br>- Refine Plugin System if needed based on verification.                                                                       |
| Week 4 | **Documentation & Cleanup**       | - Start writing new guides (Plugin, Theming). <br>- Review/fix other examples. <br>- Begin addressing ExDoc / Documentation TODOs. <br>- Address any remaining medium priority tasks or issues identified during testing. |

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

1.  **Comprehensive Functional Testing:** Across different terminal emulators (gnome-terminal, iTerm2, Windows Terminal, etc.) and OSes (Linux, macOS, Windows/WSL).
2.  **VS Code Extension Verification:** Rendering, input, resizing, backend communication stability.
3.  **Visualization Validation:** Rendering accuracy and behavior with various datasets (small, large, edge cases).
4.  **Performance Benchmarks:** Key operations (startup, rendering complex views, data processing) in both environments. Establish baseline and monitor regressions.
5.  **Plugin Functionality:** Test core plugins (clipboard, notifications, hyperlinks) across platforms. Test plugin loading, unloading, reloading, and dependency handling robustness.
6.  **Accessibility Checks:** Manual testing with screen readers (e.g., VoiceOver, NVDA), keyboard navigation checks, high contrast mode verification.

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

1.  **High/Medium Priority Features:** Implementing features listed in the `TODO.md` backlog (e.g., `Modal`, `Table` enhancements, `FocusRing`, Animation framework).
2.  **Additional Visualization Types:** Implementing Line Charts, Scatter Plots, Heatmaps.
3.  **Performance Optimization:** Profiling, benchmarking, implementing caching, addressing bottlenecks identified in `TODO.md`.
4.  **Testing:** Writing more unit/integration tests (especially for Runtime, Plugins), enhancing the testing framework, adding visual/terminal-specific automated tests.
5.  **Documentation:** Writing the planned guides (Plugin Dev, Theming, VSCode), improving API documentation (ExDoc), addressing TODOs, creating diagrams.
6.  **Accessibility Enhancements:** Improving screen reader compatibility, keyboard navigation, and color contrast based on testing feedback.
7.  **Investigating Issues:** Helping diagnose and fix issues listed in `TODO.md`.

## Resources and References

- Visualization Plugin: `VisualizationPlugin`
- Dashboard Layout: `Dashboard.ex`, `GridContainer.ex`, `WidgetContainer.ex`
- Testing Framework: `test_plan.md`, `scripts/vs_code_test.sh`, `scripts/native_terminal_test.sh`, `ButtonHelpers.ex`
- Theme System Implementation: `ThemeManager.ts`, `ThemeSelector.ts`, `theme_config.ex`, `ThemeConfigPage.ts`
- Button Component Implementation: `button.ex`, `button_test.exs`
- Project Structure: See updated README.md
- CI/CD: `.github/workflows/`, `docker/`, `scripts/run-local-actions.sh`

## Future Roadmap

After completing the current priorities, we'll focus on:

1. **Advanced Visualization Interactive Features**

   - Data filtering and selection
   - Drill-down capabilities
   - Customizable tooltips and legends

2. **Real-time Collaboration Features**

   - Shared dashboard sessions
   - Collaborative editing
   - User presence indicators

3. **AI-assisted Configuration**
   - Smart layout suggestions
   - Data visualization recommendations
   - Automated dashboard generation
