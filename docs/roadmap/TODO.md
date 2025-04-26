---
title: TODO List
description: List of pending tasks and improvements for Raxol Terminal Emulator
date: 2024-06-05
author: Raxol Team
section: roadmap
tags: [roadmap, todo, tasks]
---

# Raxol Project Roadmap

## Completed

- [x] Setup backend Elixir application structure including folder organization
- [x] Setup VS Code extension project structure with TypeScript
- [x] Implement basic process manager for terminal I/O (StdioInterface)
- [x] Set up terminal rendering and window/panel management with ExTermbox
- [x] Create debug logging system with runtime toggling
- [x] Implement environment-based configuration with appropriate defaults
- [x] Fix ExTermbox initialization failure with fallback mode
- [x] Fix database connection issues with robust error handling
- [x] Fix JSON communication issues through StdioInterface
- [x] Fix BEAM hang after clean GenServer termination
- [x] Create comprehensive testing framework with clear success/failure criteria
- [x] Implement user input handling & key events system
- [x] Create generic widget system for dashboard layouts
- [x] Implement bar chart visualization with appropriate scaling
- [x] Create treemap visualization with hierarchical layout
- [x] Implement dynamic data fetching for visualization components
- [x] Create size-adaptive test data for different terminal dimensions
- [x] Implement dashboard layout system with resizable widgets
- [x] Integrate visualization components with dashboard widgets
- [x] Add responsive visualization rendering in different widget sizes
- [x] Implement layout persistence with validation and error handling
- [x] Create automatic layout saving after significant changes
- [x] Create comprehensive test suite for dashboard layout system
- [x] Implement editor bridge to VS Code extension
- [x] Complete visualization testing in both environments
- [x] Implement TUI rendering enhancements for better display quality
- [x] Create layout persistence system with auto-recovery
- [x] Implement custom theme support with configurability (API documentation created)
- [x] Define Communication Protocol (JSON over stdio) (`docs/protocols/ExtensionBackendProtocol.md`)
- [x] Implement Backend Process Management (`extensions/vscode/src/backendManager.ts`)
- [x] Implement Basic Webview Panel (`extensions/vscode/src/raxolPanelManager.ts`)
- [x] Implement Basic Webview Rendering/Input/Resize (`media/main.js`)
- [x] Implement Backend Stdio Communication Handling (`lib/raxol/stdio_interface.ex`, `lib/raxol/runtime.ex`)
- [x] Fixed `Runtime.ex` compilation errors
- [x] Implement Cross-Component Logging
- [x] Verify Initial Connection Flow & Message Handling
- [x] Fix ExTermbox Initialization Issue
- [x] Fix JSON Communication Format
- [x] Implement VS Code Rendering Path
- [x] Implement User Input & Resize Handling
- [x] Set up initial extension project structure
- [x] Plan detailed architecture for Webview <-> Elixir interaction
- [x] Design Testing Framework
- [x] Implement Test Tooling
- [x] Test Data Preparation
- [x] Address major compilation errors
- [x] Fix Theme Selector functionality
- [x] Address specific Dialyzer issues (multiple rounds)
- [x] Complete major codebase reorganization
- [x] Project structure documentation (added to README.md)

## In Progress

- [ ] Address remaining compiler warnings (focus on unused functions - see handoff_prompt.md)
- [ ] Enhance TUI rendering in native terminal with advanced styling
- [ ] Benchmark performance with complex dashboards
- [ ] Profile visualization rendering with large datasets
- [ ] Implement caching for visualization calculations
- [ ] Complete cross-platform testing
- [ ] Create comprehensive user documentation and guides
- [ ] Test native terminal environment functionality
- [ ] Benchmark performance metrics in both environments

## Backlog

- [ ] Implement additional visualization types (line charts, scatter plots)
- [ ] Add data filtering and selection capabilities to visualizations
- [ ] Create drill-down functionality for interactive visualizations
- [ ] Implement customizable tooltips and legends
- [ ] Add asset optimization for improved load times (fonts in `priv/static/fonts`)
- [ ] Enhance accessibility with screen reader support
- [ ] Create user-friendly dashboard customization interface
- [ ] Implement real-time collaborative features
- [ ] Add dashboard sharing and export functionality
- [ ] Implement AI-assisted dashboard configuration
- [ ] Add multi-language support for UI elements
- [ ] Add visual demo (screenshot/GIF) to README.md
- [ ] Resolve stubbed/incomplete Web Authentication & LiveView features in `lib/raxol_web/` (implement or remove)
- [ ] Address numerous code-level TODO comments (Terminal emulation details, component implementations, error handling, etc.)
- [ ] Research frontend technologies (React, Vue, Svelte, etc.) for Webview UI (Decision Deferred)
- [ ] Responsiveness Scoring System: Define metrics, create algorithm, visualize data
- [ ] Performance Regression Alerting: Configure thresholds, notification system, CI integration
- [ ] Animation Performance Analysis: Monitor frame rates, identify bottlenecks
- [ ] ImagePlugin Stability/Visual Testing: Verify image (`assets/static/images/logo.png`) rendering visually (**NEEDS VISUAL VERIFICATION**)
- [ ] Hyperlink OS Interaction Testing: Verify/test `HyperlinkPlugin.open_url/1` across different OSes. (**NEEDS TESTING**)
- [ ] Investigate alternative rendering mechanisms if needed (ImagePlugin)
- [ ] API documentation updates (reflect widget refactoring, new plugin)
- [ ] Performance tuning guidelines
- [ ] Component lifecycle documentation
- [ ] Event system best practices
- [ ] Integration examples and tutorials (Dashboard, Plugins)
- [ ] Accessibility and internationalization integration guides
- [ ] Implement Advanced Animation System (Webview Focused)
- [ ] Implement Developer Experience Enhancements (IDE support, Debug tools, Docs, Codegen)
- [ ] Implement UX Refinement Enhancements (Webview Focused)
- [ ] Implement Event System Enhancements (Core Backend)
- [ ] Implement Developer Tools (Extension & Backend)
- [ ] Implement Integration Features (Core Backend)

## Issues to Investigate

- [ ] `ex_termbox` dimension reporting inconsistencies
- [ ] Performance degradation with multiple complex visualizations
- [ ] Memory usage patterns with large datasets
- [ ] Cross-platform compatibility issues
- [ ] Component: Text wrapping off-by-one issue (`text_wrapping.ex`)
- [ ] RUNTIME: Potential infinite loop **needs verification**
- [ ] RUNTIME: Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) **unknown (Pending Visual Verification)**

## Testing Needs

- [ ] Test native terminal environment functionality
- [ ] Validate visualization rendering in different scenarios
- [ ] Test cross-platform compatibility
- [ ] Benchmark performance metrics

## Known Issues �� (Consolidated View)

- **FIXED:**
  - ~~RUNTIME: BEAM VM hangs on Ctrl+C.~~
  - ~~RUNTIME: Basic `userInput` and `resize_panel` payload processing.~~
  - ~~DATABASE: Postgrex errors after application crash.~~
  - ~~VISUALIZATION: TUI Charts/TreeMaps rendering.~~
  - ~~LAYOUT: Layout loading testing.~~
- **OUTSTANDING:**
  - RUNTIME: `ex_termbox` reporting incorrect terminal dimensions (masked by workaround).
  - RUNTIME: Potential infinite loop needs verification.
  - RUNTIME: Status of other runtime warnings (`Unhandled view element type`, `Skipping invalid cell change`) unknown (Pending Visual Verification).
  - COMPILATION: Numerous compiler warnings remain (unused functions, etc. - currently being addressed).
  - IMAGE: Image rendering (`assets/static/images/logo.png`) needs visual verification.
  - PLUGIN: Hyperlink `open_url` needs cross-OS testing.
  - PERFORMANCE: Degradation with multiple complex visualizations.
  - PERFORMANCE: Memory usage patterns with large datasets.
  - COMPATIBILITY: General cross-platform issues investigation.
  - COMPONENT: Text wrapping off-by-one issue (`text_wrapping.ex`).
