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
- [x] Task 1.2g: Review Core Guide: `ARCHITECTURE.md`
- [x] Task 1.3: Verify Content (Code examples, links, terminology)
- [x] Task 1.4: Apply Corrections (File edits for errors/inconsistencies)

**Goal 2: Create Comprehensive Guides for Key Subsystems**

- [ ] Task 2.1: Plan Plugin Development Guide (`docs/guides/plugin_development.md` outline)
- [ ] Task 2.2: Write Plugin Development Guide (Content population)
- [ ] Task 2.3: Plan Theming Guide (`docs/guides/theming.md` outline)
- [ ] Task 2.4: Write Theming Guide (Content population)
- [ ] Task 2.5: Plan VS Code Extension Guide (`docs/guides/vscode_extension.md` outline) (If applicable)
- [ ] Task 2.6: Write VS Code Extension Guide (Content population)

**Goal 3: Enhance Practical Examples**

- [ ] Task 3.1: Improve README Example (Add state/event handling)
- [ ] Task 3.2: Develop Component Showcase (Enhance existing or create new example, document, link from `components.md`)
  - [x] Added `MultiLineInput`, `Table`, `SelectList`, `Spinner`, `Modal` demos.
  - [ ] **Blocked:** Resolve compilation error in `lib/raxol/components/input/multi_line_input/event_handler.ex` (line 70 syntax error).
  - [ ] Run and verify showcase example.

**Goal 4: Improve Generated API Documentation (ExDoc)**

- [ ] Task 4.1: Identify Key Public Modules
- [ ] Task 4.2: Review Module Docs (`@moduledoc`)
- [ ] Task 4.3: Review Function Docs (`@doc` & `@spec`)
- [ ] Task 4.4: Test ExDoc Generation (`mix docs`)

**Goal 5: Resolve Documentation TODOs**

- [ ] Task 5.1: Find Documentation TODOs (Search codebase)
- [ ] Task 5.2: Address Found TODOs
  - [ ] Sub-Task: Fill in hosted documentation link (Requires User Input)
  - [ ] Sub-Task: Add demo screenshot/GIF to README (Requires User Input/Creation)
  - [ ] Sub-Task: Complete other found documentation TODOs

**Goal 6: Add Visual Aids**

- [ ] Task 6.1: Identify Diagram Opportunities (`ARCHITECTURE.md`, flows)
- [ ] Task 6.2: Create Diagrams (Mermaid or images)
- [ ] Task 6.3: Integrate Diagrams

## Other In Progress Tasks

## In Progress

- [ ] Ensure 100% functional examples (@examples verification)
- [ ] Write More Tests (Runtime interactions: Dispatcher, Renderer; PluginManager edge cases)
- [ ] Benchmark performance with complex dashboards
- [ ] Profile visualization rendering with large datasets
- [ ] Implement caching for visualization calculations (if identified as bottleneck)
- [ ] Complete comprehensive cross-platform testing (Native Terminal & VS Code Extension)
- [ ] Create comprehensive user documentation and guides (Core concepts, Components, Plugins, Theming, Accessibility)
- [ ] Test native terminal environment functionality thoroughly

## Backlog

### High Priority

- [ ] Implement core terminal command handling (CSI, OSC, DCS) (`lib/raxol/terminal/commands/executor.ex`).
- [ ] Fix `MultiLineInput` callback invocation and add word movements (`lib/raxol/components/input/multi_line_input.ex`).
- [ ] Implement `TextInput` visual cursor rendering and Home/End/Delete key support (`lib/raxol/components/input/text_input.ex`).
- [ ] Fix `Auth` function calls in `UserRegistrationController` (`lib/raxol_web/controllers/user_registration_controller.ex`).
- [ ] Resolve commented-out `CheckRepoStatus` plug in `Endpoint` (`lib/raxol_web/endpoint.ex`).
- [ ] Update `ANSI Facade` to reflect new state structure (`lib/raxol/terminal/ansi_facade.ex`).
- [ ] Refine Plugin System: Robust reloading (source change detection?), command namespacing/arity improvements, more comprehensive tests.
- [ ] Implement Core Command Functionality: Ensure `ClipboardPlugin` and `NotificationPlugin` work reliably across target platforms.

### Medium Priority

- [ ] Implement Modal form rendering/interaction (`lib/raxol/components/modal.ex`).
- [ ] Implement Table features: pagination buttons, filtering, sorting (`lib/raxol/components/table.ex`).
- [ ] Implement Focus Ring styling based on state/effects (`lib/raxol/components/focus_ring.ex`).
- [ ] Implement Animation framework easing functions and interpolation (`lib/raxol/animation/framework.ex`).
- [ ] Implement AI content generation stubs (`lib/raxol/ai/content_generation.ex`).
- [ ] Add missing terminal feature detection checks (`lib/raxol/system/terminal_platform.ex`).
- [ ] Implement terminal input handling: tab completion, mouse events (`lib/raxol/terminal/input.ex`).
- [ ] Implement advanced terminal character set features (GR invocation, Locking/Single Shift) (`lib/raxol/terminal/character_sets.ex`).
- [ ] Enhance TUI rendering in native terminal with advanced styling techniques (beyond basic theme application).
- [ ] **Enhance SelectList:** Consider stateful scroll offset, more robust focus management, search/filtering.

### Low Priority

- [ ] Investigate/Fix potential text wrapping off-by-one error (`lib/raxol/components/input/text_wrapping.ex`).
- [ ] Refactor large files identified in ARCHITECTURE.md (e.g., `terminal/parser.ex`).
- [ ] Deduplicate code / Extract common utilities.

## Issues to Investigate

- [ ] `ex_termbox` dependency: Can it be removed or replaced given direct `stty` usage in `Terminal.Driver`? (Seems likely removed/obsolete based on Changelog fixes, but verify). If kept, investigate dimension reporting inconsistencies.
- [ ] Performance degradation with multiple complex visualizations.
- [ ] Memory usage patterns with large datasets.
- [ ] Cross-platform compatibility edge cases (specific OS/terminal combinations).
- [ ] RUNTIME: Potential infinite loop mentioned in old TODO - **needs verification**.
- [ ] RUNTIME: Status of runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) - **needs visual verification during testing**.
- [ ] IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification if `ImagePlugin` is used/intended.
- [ ] PLUGIN: Hyperlink `open_url` needs cross-OS testing.

## Testing Needs (Consolidated)

- [ ] **Native Terminal:** Comprehensive functional testing across different terminal emulators (gnome-terminal, iTerm2, Windows Terminal, etc.) and OSes (Linux, macOS, Windows/WSL).
- [ ] **VS Code Extension:** Verify rendering, input, resizing, and backend communication stability.
- [ ] **Visualizations:** Validate rendering accuracy and behavior with various datasets (small, large, edge cases).
- [ ] **Performance:** Benchmark key operations (startup, rendering complex views, data processing) in both environments. Establish baseline and monitor regressions.
- [ ] **Plugins:** Test core plugin functionality (clipboard, notifications, hyperlinks) across platforms. Test plugin loading, unloading, reloading, and dependency handling robustness.
- [ ] **Accessibility:** Manual testing with screen readers (e.g., VoiceOver, NVDA), keyboard navigation checks, high contrast mode verification.

## Known Issues (Current Outstanding)

- **PERFORMANCE:** Potential degradation with multiple complex visualizations.
- **PERFORMANCE:** Memory usage patterns with large datasets need analysis.
- **COMPATIBILITY:** Specific cross-platform edge cases may exist.
- **RUNTIME:** Status of warnings like `Unhandled view element type` requires visual verification.
- **PLUGIN:** Hyperlink `open_url` needs cross-OS testing.
- **VISUAL:** Image rendering (if used) needs visual verification.
- **VERIFICATION NEEDED:** Potential infinite loop (old report).

_(Removed historical "Completed" section as CHANGELOG.md is the source of truth)_
